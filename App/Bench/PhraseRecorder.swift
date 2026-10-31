import AVFoundation
import LocalFlowCore
import UIKit

/// Запись одной фразы для «Замера»: свой `AudioRecorder`, звук только в памяти — на диск не пишется.
/// Кнопка и прерывания — как в основной диктовке: второе нажатие или 2:00 отдают фразу в `onPhrase`,
/// звонок или уход в фон её выбрасывают («Запись прервана — повтори»).
@MainActor
final class PhraseRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var showMicDenied = false
    @Published var errorText: String?

    /// Записанная фраза — после второго нажатия или на пределе 2:00.
    var onPhrase: (@MainActor ([Float]) -> Void)?

    private let recorder = AudioRecorder()
    private var timer: Timer?
    private var startedAt: Date?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        // Звонок, Siri, другой звук — запись выбрасывается, как в диктовке.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began else { return }
            MainActor.assumeIsolated { self?.cancel() }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        })
    }

    /// Первое нажатие начинает запись (запрашивает доступ при необходимости), второе — отдаёт фразу.
    func toggle() async {
        if isRecording {
            finish()
        } else {
            await start()
        }
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
        if RecordingGuard.reachedLimit(elapsed: elapsed) { finish() }
    }

    private func finish() {
        guard isRecording else { return }
        let samples = stop()
        if !samples.isEmpty { onPhrase?(samples) }
    }

    /// Прерывание: фраза выбрасывается.
    private func cancel() {
        guard isRecording else { return }
        _ = stop()
        errorText = DictationController.interruptedMessage
    }

    private func stop() -> [Float] {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        isRecording = false
        return recorder.stop()
    }
}
