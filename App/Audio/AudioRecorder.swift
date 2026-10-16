import AVFoundation

enum MicPermission: Equatable {
    case undetermined
    case denied
    case granted
}

enum RecorderError: LocalizedError {
    case noInput
    case formatFailed
    case sessionFailed(String)
    case engineFailed(String)

    var errorDescription: String? {
        switch self {
        case .noInput: return "Микрофон не найден."
        case .formatFailed: return "Не удалось настроить перевод звука в 16 кГц."
        case .sessionFailed(let reason): return "Аудиосессия не включилась: \(reason)"
        case .engineFailed(let reason): return "Запись не запустилась: \(reason)"
        }
    }
}

/// Микрофон через AVAudioEngine → 16 кГц mono Float в памяти.
/// Звук не пишется на диск и никуда не отправляется (R43): живёт в `samples` до `stop()`.
final class AudioRecorder {
    static let sampleRate: Double = 16000

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var currentLevel: Float = 0
    private(set) var isRunning = false

    var permission: MicPermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        default: return .undetermined
        }
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Уровень последнего куска звука, 0…1 (−50 дБ … 0 дБ).
    var level: Float { lock.withLock { currentLevel } }

    func start() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            throw RecorderError.sessionFailed(error.localizedDescription)
        }

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else {
            deactivateSession()
            throw RecorderError.noInput
        }
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate,
                                            channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            deactivateSession()
            throw RecorderError.formatFailed
        }

        lock.withLock {
            samples = []
            samples.reserveCapacity(Int(Self.sampleRate) * 125)   // предел записи 2:00 + запас
            currentLevel = 0
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            self?.consume(buffer, converter: converter, outFormat: outFormat)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            deactivateSession()
            throw RecorderError.engineFailed(error.localizedDescription)
        }
        isRunning = true
    }

    /// Останавливает запись и отдаёт весь записанный звук; буфер очищается.
    func stop() -> [Float] {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
        deactivateSession()
        return lock.withLock {
            let result = samples
            samples = []
            currentLevel = 0
            return result
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Поток звука: перевод куска в 16 кГц mono и добавление в буфер.
    private func consume(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outFormat: AVAudioFormat) {
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }

        let feed = FeedOnce()
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if feed.done {
                status.pointee = .noDataNow
                return nil
            }
            feed.done = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData?[0] else { return }
        let count = Int(out.frameLength)
        guard count > 0 else { return }
        let chunk = UnsafeBufferPointer(start: channel, count: count)

        var sum: Float = 0
        for value in chunk { sum += value * value }
        let rms = (sum / Float(count)).squareRoot()
        let db = 20 * log10(max(rms, 1e-7))
        let normalized = min(1, max(0, (db + 50) / 50))

        lock.withLock {
            samples.append(contentsOf: chunk)
            currentLevel = normalized
        }
    }
}

/// Конвертеру кусок отдаётся один раз за вызов `convert`.
private final class FeedOnce {
    var done = false
}
