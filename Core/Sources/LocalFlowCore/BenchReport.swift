import Foundation

public struct BenchRow: Equatable, Sendable {
    public var model: String
    public var audioSeconds: Double
    public var transcribeSeconds: Double
    public var peakMemoryMB: Double?
    public var text: String

    public init(model: String, audioSeconds: Double, transcribeSeconds: Double,
                peakMemoryMB: Double?, text: String) {
        self.model = model
        self.audioSeconds = audioSeconds
        self.transcribeSeconds = transcribeSeconds
        self.peakMemoryMB = peakMemoryMB
        self.text = text
    }
}

public enum BenchReport {
    public static func markdown(_ rows: [BenchRow], device: String) -> String { "" }
}
