import Foundation

public enum PipelineResult: Equatable, Sendable {
    case text(String)
    case rejected(RejectReason)
}

public enum TextPipeline {
    /// Порядок как в LocalFlow: выдумка? → паразиты → замены (R22). Пусто → .rejected(.empty).
    public static func process(raw: String, replacements: Replacements) -> PipelineResult {
        if isBlank(raw) {
            return .rejected(.empty)
        }
        if Hallucinations.matches(raw) {
            return .rejected(.hallucination(text: raw))
        }
        let text = replacements.apply(Fillers.remove(raw))
        return isBlank(text) ? .rejected(.empty) : .text(text)
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
