import Foundation

public enum RejectReason: Equatable, Sendable {
    case tooShort(hold: Double)                    // MIN_HOLD_S
    case lostAudio(hold: Double, audio: Double)    // LOST_AUDIO_S + LOST_AUDIO_SHARE
    case hallucination(text: String)               // HALLUCINATIONS
    case empty                                     // ничего не распознано / после паразитов пусто

    /// Русский текст для экрана: что случилось и что повторить.
    public var message: String {
        switch self {
        case .tooShort: return "Слишком коротко — нажми и говори"
        case .lostAudio: return "Звук потерялся — повтори"
        case .hallucination: return "Похоже на выдумку Whisper на тишине — повтори фразу"
        case .empty: return "Ничего не распознано — повтори"
        }
    }
}

public enum RecordingDecision: Equatable, Sendable {
    case reject(RejectReason)
    case transcribe(keepLastSeconds: Double?)   // nil — весь клип; число — оставить последние N секунд
}

public enum RecordingGuard {
    public static let minHold = 0.0, extraAudio = 0.0, lostAudio = 0.0, lostShare = 0.0, lostMin = 0.0

    public static func decide(hold: Double, audio: Double) -> RecordingDecision { .reject(.empty) }
}
