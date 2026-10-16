import Foundation

public enum PipelineResult: Equatable, Sendable {
    case text(String)
    case rejected(RejectReason)
}

public enum TextPipeline {
    public static func process(raw: String, replacements: Replacements) -> PipelineResult { .text(raw) }
}
