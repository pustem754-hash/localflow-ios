import AVFoundation
import Combine
import LocalFlowCore
import UIKit

/// Диктовка: нажал — запись, нажал ещё раз — фильтры LocalFlow → Whisper → паразиты и замены → буфер.
/// Порядок шагов — как `_finalize` в LocalFlow main.py.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    /// R08.1: на 2:00 запись останавливается сама и распознаётся.
    static let maxRecordingSeconds: TimeInterval = 120
    static let interruptedMessage = "Запись прервана — повтори"

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var lastText: String?
    /// От второго нажатия до текста в буфере (R09.1).
    @Published private(set) var lastDuration: TimeInterval?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0

    /// Таск 04 («Замер»): пока `true`, диктовка не запускается — в `WhisperEngine.shared` может быть чужая модель.
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
    private var pendingIntentStart = false
    private var observers: [NSObjectProtocol] = []
    private var engineSubscription: AnyCancellable?

    init() {
        store = ModelStore.shared
        syncWithEngine(store.engineState)
        engineSubscription = store.$engineState.sink { [weak self] engineState in
            MainActor.assumeIsolated { self?.syncWithEngine(engineState) }
        }

        let center = NotificationCenter.default
        // R39.1: звонок, Siri, другой звук — запись останавливается, ничего не копируется.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began else { return }
            MainActor.assumeIsolated { self?.cancelRecording(to: .failed(Self.interruptedMessage)) }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelRecording(to: .failed(Self.interruptedMessage)) }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.startPendingIntent() }
        })
    }

    /// Модель годится для записи: загружена или ещё грузится (распознавание её дождётся).
    private var modelUsable: Bool {
        switch store.engineState {
        case .loaded, .loading: return true
        case .empty, .failed: return false
        }
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
        switch state {
        case .recording: finish()
        case .transcribing: return
        default: Task { await begin() }
        }
    }

    /// App Intent «Начать диктовку»: открыть вкладку и начать запись, как только приложение на экране.
    func startFromIntent() {
        AppNavigation.shared.tab = .dictation
        switch state {
        case .recording, .transcribing: return
        default: break
        }
        if UIApplication.shared.applicationState == .active {
            Task { await begin() }
        } else {
            pendingIntentStart = true
        }
    }

    private func startPendingIntent() {
        guard pendingIntentStart else { return }
        pendingIntentStart = false
        Task { await begin() }
    }

    // MARK: Запись

    private func begin() async {
        guard !isStarting, !isBenchRunning else { return }
        switch state {
        case .recording, .transcribing: return
        default: break
        }
        guard modelUsable else {
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

        do {
            try recorder.start()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        let since = Date()
        elapsed = 0
        level = 0
        state = .recording(since: since)
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard case .recording(let since) = state else { return }
        elapsed = Date().timeIntervalSince(since)
        level = recorder.level
        if elapsed >= Self.maxRecordingSeconds { finish() }
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
        // Запуск из «Команд» на холодную: запись могла начаться, пока модель ещё грузилась.
        while case .loading = store.engineState {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard case .loaded = store.engineState, !isBenchRunning else {
            state = .noModel
            return
        }

        let raw: String
        do {
            raw = try await WhisperEngine.shared.transcribe(samples)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        switch TextPipeline.process(raw: raw, replacements: DictationReplacements.current()) {
        case .rejected(let reason):
            state = .rejected(reason)
        case .text(let text):
            UIPasteboard.general.string = text
            lastText = text
            lastDuration = Date().timeIntervalSince(releasedAt)
            state = .copied(text: text)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
