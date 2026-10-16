import Foundation

public enum RejectReason: Equatable, Sendable {
    case tooShort(hold: Double)                    // MIN_HOLD_S
    case extraAudio(hold: Double, audio: Double)   // EXTRA_AUDIO_S
    case lostAudio(hold: Double, audio: Double)    // LOST_AUDIO_S + LOST_AUDIO_SHARE
    case hallucination(text: String)               // HALLUCINATIONS
    case empty                                     // ничего не распознано / после паразитов пусто

    /// Русский текст для экрана: что случилось и что повторить.
    public var message: String {
        switch self {
        case .tooShort: return "Слишком коротко — нажми и говори"
        case .extraAudio: return "Звук не совпал — повтори"
        case .lostAudio: return "Звук потерялся — повтори"
        case .hallucination: return "Похоже на выдумку Whisper на тишине — повтори фразу"
        case .empty: return "Ничего не распознано — повтори"
        }
    }
}

public enum RecordingGuard {
    /// MIN_HOLD_S, EXTRA_AUDIO_S, LOST_AUDIO_S, LOST_AUDIO_SHARE из LocalFlow main.py.
    public static let minHold = 0.3, extraAudio = 0.5, lostAudio = 1.0, lostShare = 0.75

    /// Проверка до распознавания, как в LocalFlow main.py `_finalize`, в том же порядке.
    /// `hold` — сколько шла запись, `audio` — сколько секунд звука реально пришло.
    public static func check(hold: Double, audio: Double) -> RejectReason? {
        if hold < minHold {
            return .tooShort(hold: hold)
        }
        if audio - hold > extraAudio {
            return .extraAudio(hold: hold, audio: audio)
        }
        // потеря — только если оба условия (11.55/10.50 — не потеря)
        if hold - audio > lostAudio && audio < hold * lostShare {
            return .lostAudio(hold: hold, audio: audio)
        }
        return nil
    }
}
