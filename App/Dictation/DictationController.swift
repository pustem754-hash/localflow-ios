import AVFoundation
import Combine
import LocalFlowCore
import UIKit

/// Диктовка: нажал — запись, нажал ещё раз — фильтры LocalFlow → Whisper → паразиты и замены → буфер.
/// Порядок шагов — как `_finalize` в LocalFlow main.py.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    static let interruptedMessage = "Запись прервана — повтори"

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var lastText: String?
    /// От второго нажатия до текста в буфере.
    @Published private(set) var lastDuration: TimeInterval?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    /// Пояснение под «Скопировано», например что текст лёг в буфер только при возврате в приложение.
    @Published private(set) var copyNote: String?

    static let copiedOnReturnNote = "Распознано, пока LocalFlow был в фоне, — скопировано при возврате в приложение."

    /// «Замер»: пока `true`, диктовка не запускается — в `WhisperEngine.shared` может быть чужая модель.
    /// Идущая запись при включении флага отменяется без распознавания.
    @Published var isBenchRunning = false {
        didSet {
            if isBenchRunning, case .recording = state { cancelRecording(to: .idle) }
        }
    }

    private let recorder = AudioRecorder()
    private let store: ModelStore
    private var timer: Timer?
    private var isStarting = false
    /// Просьба «Начать диктовку» из «Команд» ждёт активной сцены и готовой модели.
    private var pendingStart = PendingStart()
    /// `scenePhase == .active` — ставит `RootView`.
    private var isSceneActive = false
    /// Прерывание аудиосессии кончилось (Siri отпустила микрофон) — пауза между попытками кончается раньше.
    private var micReleased = false
    /// Последняя ошибка микрофона при повторах из «Команд» — показывается под «Микрофон занят».
    private var lastMicError: String?
    /// Распознано в фоне — из фона в буфер не пишем, кладём при возврате.
    private var deferredCopy = DeferredCopy()
    private var observers: [NSObjectProtocol] = []
    private var engineSubscription: AnyCancellable?

    init() {
        store = ModelStore.shared
        syncWithEngine(store.engineState)
        engineSubscription = store.$engineState.sink { [weak self] engineState in
            MainActor.assumeIsolated { self?.syncWithEngine(engineState) }
            // @Published шлёт значение до записи в свойство — модель проверяем следующим шагом.
            Task { @MainActor in self?.startPendingIfReady() }
        }

        let center = NotificationCenter.default
        // Звонок, Siri, другой звук — запись останавливается, ничего не копируется.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                switch type {
                case .began: self?.cancelRecording(to: .failed(Self.interruptedMessage))
                case .ended: self?.micReleased = true
                default: break
                }
            }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelRecording(to: .failed(Self.interruptedMessage)) }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.deliverDeferredCopy() }
        })
    }

    /// Модель грузится — запись не начинается (кнопка неактивна, «Модель загружается…»).
    var isModelLoading: Bool {
        if case .loading = store.engineState { return true }
        return false
    }

    private func syncWithEngine(_ engineState: EngineState) {
        switch state {
        case .idle, .noModel:
            switch engineState {
            case .loaded, .loading: state = .idle
            case .empty, .failed: state = .noModel
            }
        default:
            break
        }
    }

    // MARK: Кнопка

    func toggle() {
        pendingStart.cancel()   // нажатие кнопки отменяет ожидающий запуск из «Команд»
        switch state {
        case .recording: finish()
        case .transcribing: return
        default: Task { await begin() }
        }
    }

    /// App Intent «Начать диктовку»: открыть вкладку и поставить просьбу о записи — без ожидания,
    /// `perform()` возвращается сразу. Запись начнёт `startPendingIfReady()`.
    func startFromIntent() {
        AppNavigation.shared.tab = .dictation
        switch state {
        case .recording, .transcribing: return
        default: break
        }
        pendingStart.request()
        Task {
            // Модель могла только что прийти через iTunes или ещё не выбраться после холодного запуска.
            await store.refresh()
            pendingStart.modelsCheckFinished()
            startPendingIfReady()
        }
    }

    /// `scenePhase` из `RootView`: запись из «Команд» начинается только с активной сценой.
    func sceneActivityChanged(_ active: Bool) {
        isSceneActive = active
        startPendingIfReady()
    }

    /// Сцена активна, модели проверены, модель не грузится — начать запись по просьбе из «Команд».
    /// Зовут: просьба, конец проверки моделей, смена `scenePhase`, смена состояния движка.
    private func startPendingIfReady() {
        guard pendingStart.take(sceneActive: isSceneActive, modelLoading: isModelLoading) else { return }
        Task { await begin(fromIntent: true) }
    }

    // MARK: Запись

    /// `fromIntent` — запуск из «Команд»: после Siri микрофон может быть ещё занят, запуск повторяется.
    private func begin(fromIntent: Bool = false) async {
        guard !isStarting, !isBenchRunning else { return }
        switch state {
        case .recording, .transcribing: return
        default: break
        }
        switch store.engineState {
        case .loaded: break
        case .loading: return
        case .empty, .failed:
            state = .noModel
            return
        }

        isStarting = true
        defer { isStarting = false }
        switch recorder.permission {
        case .granted:
            break
        case .denied:
            state = .micDenied
            return
        case .undetermined:
            guard await recorder.requestPermission() else {
                state = .micDenied
                return
            }
        }
        guard !isBenchRunning else { return }

        if fromIntent {
            lastMicError = nil
            // Siri ещё держит микрофон: «Микрофон не найден» или сессия не включается — повторяем до 3 c.
            let started = await MicRetry.run(now: { ProcessInfo.processInfo.systemUptime },
                                             attempt: { await self.tryStartRecorder() },
                                             wait: { await self.waitForMic($0) })
            guard started else {
                if !isBenchRunning {
                    state = .failed([MicRetry.busyMessage, lastMicError].compactMap { $0 }.joined(separator: "\n"))
                }
                return
            }
            // Между запуском микрофона и этой строкой могли уйти в фон или начать «Замер».
            guard !isBenchRunning, isSceneActive else {
                _ = recorder.stop()
                return
            }
        } else {
            do {
                try recorder.start()
            } catch {
                state = .failed(error.localizedDescription)
                return
            }
        }
        let since = Date()
        elapsed = 0
        level = 0
        copyNote = nil
        state = .recording(since: since)
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Одна попытка для `MicRetry`: `false` — микрофон занят, начался «Замер» или приложение ушло с экрана.
    private func tryStartRecorder() -> Bool {
        guard !isBenchRunning, isSceneActive else { return false }
        do {
            try recorder.start()
            return true
        } catch {
            lastMicError = error.localizedDescription
            return false
        }
    }

    /// Пауза между попытками до `seconds`; конец прерывания аудиосессии будит раньше.
    private func waitForMic(_ seconds: TimeInterval) async {
        micReleased = false
        let deadline = Date().addingTimeInterval(seconds)
        while !micReleased, Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func tick() {
        guard case .recording(let since) = state else { return }
        elapsed = Date().timeIntervalSince(since)
        level = recorder.level
        // На 2:00 запись останавливается сама и распознаётся.
        if RecordingGuard.reachedLimit(elapsed: elapsed) { finish() }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        level = 0
    }

    /// Прерывание: запись выброшена, ничего не распознаётся и не копируется.
    private func cancelRecording(to newState: DictationState) {
        guard case .recording = state else { return }
        stopTimer()
        _ = recorder.stop()
        state = newState
    }

    /// Второе нажатие (или 2:00): фильтры длительности из LocalFlow, затем распознавание.
    private func finish() {
        guard case .recording(let since) = state else { return }
        let releasedAt = Date()
        stopTimer()
        var samples = recorder.stop()
        let hold = releasedAt.timeIntervalSince(since)
        let audio = Double(samples.count) / AudioRecorder.sampleRate

        switch RecordingGuard.decide(hold: hold, audio: audio) {
        case .reject(let reason):
            state = .rejected(reason)
            return
        case .transcribe(let keepLastSeconds):
            if let keepLastSeconds {
                let keep = Int(keepLastSeconds * AudioRecorder.sampleRate)   // последние N отсчётов
                if keep < samples.count { samples = Array(samples.suffix(keep)) }
            }
        }
        state = .transcribing
        Task { await transcribe(samples, releasedAt: releasedAt) }
    }

    private func transcribe(_ samples: [Float], releasedAt: Date) async {
        // Во время записи могли выбрать другую модель — ждём её; ожидание не входит в «Распознано за».
        let waitStart = Date()
        while case .loading = store.engineState {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let waited = Date().timeIntervalSince(waitStart)
        guard case .loaded(let modelID) = store.engineState, modelID == store.selected, !isBenchRunning else {
            state = .noModel
            return
        }

        let raw: String
        do {
            // Движок сам сверяет, что в нём именно выбранная модель, иначе — EngineError.wrongModel.
            raw = try await WhisperEngine.shared.transcribe(samples, expectedModel: modelID)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        switch TextPipeline.process(raw: raw, replacements: DictationReplacements.current()) {
        case .rejected(let reason):
            state = .rejected(reason)
        case .text(let text):
            lastText = text
            lastDuration = Date().timeIntervalSince(releasedAt) - waited
            let inForeground = UIApplication.shared.applicationState != .background
            if let now = deferredCopy.deliver(text, inForeground: inForeground) {
                copied(now, note: nil)
            }
            // Иначе до возврата в приложение на экране «Распознаю…», в буфер — в `deliverDeferredCopy()`.
        }
    }

    private func copied(_ text: String, note: String?) {
        Clipboard.copy(text)
        copyNote = note
        state = .copied(text: text)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func deliverDeferredCopy() {
        guard let text = deferredCopy.takeOnReturn() else { return }
        copied(text, note: Self.copiedOnReturnNote)
    }
}
