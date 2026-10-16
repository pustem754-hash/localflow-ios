import Foundation
import LocalFlowCore

/// Одна записанная фраза — звук только в памяти.
struct BenchPhrase: Identifiable {
    let id = UUID()
    var title: String
    var samples: [Float]

    var seconds: Double { Double(samples.count) / AudioRecorder.sampleRate }
}

/// «Замер»: каждая фраза × каждая скачанная модель, модели грузятся по одной в `WhisperEngine.shared`.
/// Пока идёт прогон, `DictationController.shared.isBenchRunning = true`; после — всегда
/// `ModelStore.shared.loadSelected()` (без выбранной модели он выгружает движок) и только затем `false`,
/// в том числе при ошибке и отмене.
@MainActor
final class BenchRunner: ObservableObject {
    @Published private(set) var phrases: [BenchPhrase] = []
    @Published private(set) var rows: [BenchRow] = []
    @Published private(set) var isRunning = false
    @Published private(set) var statusText: String?
    @Published var errorText: String?

    private var runTask: Task<Void, Never>?

    var canRun: Bool {
        !isRunning && !phrases.isEmpty && !ModelStore.shared.downloaded.isEmpty
    }

    func addPhrase(_ samples: [Float]) {
        phrases.append(BenchPhrase(title: "Фраза \(phrases.count + 1)", samples: samples))
    }

    func removePhrases(at offsets: IndexSet) {
        phrases.remove(atOffsets: offsets)
    }

    func run() {
        guard canRun else { return }
        let store = ModelStore.shared
        let models = store.catalog.filter { store.isDownloaded($0) }
        let phrasesSnapshot = phrases

        isRunning = true
        rows = []
        errorText = nil
        statusText = nil
        DictationController.shared.isBenchRunning = true

        runTask = Task { @MainActor [weak self] in
            await self?.runLoop(models: models, phrases: phrasesSnapshot)
            self?.statusText = "Возвращаю выбранную модель…"
            // Диктовка снова доступна, только когда в движке выбранная модель (или он пуст).
            await ModelStore.shared.loadSelected()
            DictationController.shared.isBenchRunning = false
            self?.statusText = nil
            self?.isRunning = false
        }
    }

    /// Отменяет прогон: текущая фраза дораспознаётся, следующий шаг не начинается.
    func cancel() {
        runTask?.cancel()
    }

    private func runLoop(models: [ModelInfo], phrases: [BenchPhrase]) async {
        let store = ModelStore.shared
        guard let vad = WhisperEngine.bundledVAD else {
            errorText = "Нет VAD-модели в приложении."
            return
        }
        for model in models {
            if Task.isCancelled { return }
            statusText = "Загружаю \(model.title)…"
            do {
                try await WhisperEngine.shared.load(model: store.fileURL(for: model), vad: vad, id: model.id)
            } catch {
                rows.append(BenchRow(model: model.title, audioSeconds: 0, transcribeSeconds: 0,
                                      peakMemoryMB: nil,
                                      text: "Модель не загрузилась: \(error.localizedDescription)"))
                continue
            }
            for phrase in phrases {
                if Task.isCancelled { return }
                statusText = "\(model.title): \(phrase.title)…"
                let result = await measure(phrase.samples, model: model)
                rows.append(BenchRow(model: model.title, audioSeconds: phrase.seconds,
                                      transcribeSeconds: result.seconds, peakMemoryMB: result.peakMB,
                                      text: result.text))
            }
        }
    }

    /// Распознаёт фразу текущей моделью; пик памяти — максимум `MemoryProbe.currentMB()` за время распознавания.
    /// Движок сверяет, что в нём именно `model`: чужая модель — строка с ошибкой, а не чужие цифры.
    private func measure(_ samples: [Float], model: ModelInfo) async -> (text: String, seconds: Double, peakMB: Double?) {
        let start = Date()
        let tracker = PeakMemoryTracker()
        tracker.start()
        do {
            let text = try await WhisperEngine.shared.transcribe(samples, expectedModel: model.id)
            return (text, Date().timeIntervalSince(start), tracker.stop())
        } catch {
            return ("Ошибка распознавания: \(error.localizedDescription)", Date().timeIntervalSince(start), tracker.stop())
        }
    }
}

/// Опрашивает `MemoryProbe.currentMB()` по таймеру и держит максимум, пока идёт распознавание.
private final class PeakMemoryTracker {
    private let lock = NSLock()
    private var peak = MemoryProbe.currentMB()
    private var timer: Timer?

    func start() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sample() {
        let value = MemoryProbe.currentMB()
        lock.withLock { peak = max(peak, value) }
    }

    func stop() -> Double {
        timer?.invalidate()
        timer = nil
        sample()
        return lock.withLock { peak }
    }
}
