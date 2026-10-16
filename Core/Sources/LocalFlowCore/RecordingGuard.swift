import Foundation

public enum RejectReason: Equatable, Sendable {
    case tooShort(hold: Double)
    case extraAudio(hold: Double, audio: Double)
    case lostAudio(hold: Double, audio: Double)
    case hallucination(text: String)
    case empty

    public var message: String { "" }
}

public enum RecordingGuard {
    public static let minHold = 0.0, extraAudio = 0.0, lostAudio = 0.0, lostShare = 0.0

    public static func check(hold: Double, audio: Double) -> RejectReason? { nil }
}
