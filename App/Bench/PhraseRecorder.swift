import AVFoundation

/// Запись одной фразы для «Замера»: свой `AudioRecorder`, звук только в памяти до `toggle()`
/// (R43) — на диск не пишется. Кнопка работает как на главном экране диктовки.
@MainActor
final class PhraseRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var showMicDenied = false
    @Published var errorText: String?

    private let recorder = AudioRecorder()
    private var timer: Timer?
    private var startedAt: Date?

    /// Первое нажатие начинает запись (запрашивает доступ при необходимости, `nil` в ответ);
    /// второе — останавливает и отдаёт записанный звук.
    func toggle() async -> [Float]? {
        if isRecording { return stop() }
        await start()
        return nil
    }

    private func start() async {
        switch recorder.permission {
        case .granted:
            break
        case .denied:
            showMicDenied = true
            return
        case .undetermined:
            guard await recorder.requestPermission() else {
                showMicDenied = true
                return
            }
        }
        do {
            try recorder.start()
        } catch {
            errorText = error.localizedDescription
            return
        }
        startedAt = Date()
        elapsed = 0
        isRecording = true
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
    }

    private func stop() -> [Float] {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        isRecording = false
        return recorder.stop()
    }
}
