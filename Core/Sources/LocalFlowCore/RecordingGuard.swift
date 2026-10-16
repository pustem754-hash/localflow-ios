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
    /// MIN_HOLD_S, EXTRA_AUDIO_S, LOST_AUDIO_S, LOST_AUDIO_SHARE, LOST_AUDIO_MIN_S из LocalFlow main.py.
    public static let minHold = 0.3, extraAudio = 0.5, lostAudio = 1.0, lostShare = 0.75, lostMin = 1.5

    /// Как текущий LocalFlow main.py `_finalize` (после 16.10 01:08), в том же порядке.
    /// `hold` — сколько шла запись, `audio` — сколько секунд звука реально пришло.
    public static func decide(hold: Double, audio: Double) -> RecordingDecision {
        if hold < minHold {
            return .reject(.tooShort(hold: hold))
        }
        var audio = audio
        var keepLast: Double?
        if audio - hold > extraAudio {
            // лишнее — старый звук в начале клипа: оставляем последние «запись + 0,5 c»
            keepLast = hold + extraAudio
            audio = hold + extraAudio
        }
        // потеря — только если все три условия (11.55/10.50 и 5.0/3.0 — не потеря)
        if hold - audio > lostAudio && audio < hold * lostShare && audio < lostMin {
            return .reject(.lostAudio(hold: hold, audio: audio))
        }
        return .transcribe(keepLastSeconds: keepLast)
    }
}
