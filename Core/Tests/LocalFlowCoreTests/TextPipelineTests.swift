import XCTest
import LocalFlowCore

/// Порядок как в LocalFlow main.py `_finalize`: выдумка? → паразиты → замены (R22, R23).
final class TextPipelineTests: XCTestCase {
    func testFillersThenReplacements() {
        XCTAssertEqual(TextPipeline.process(raw: "эм, перезапусти Аламу", replacements: .defaults),
                       .text("Перезапусти Ollama"))
    }

    func testHallucinationIsRejected() {
        XCTAssertEqual(TextPipeline.process(raw: "Продолжение следует.", replacements: .defaults),
                       .rejected(.hallucination(text: "Продолжение следует.")))
    }

    func testHallucinationIsCheckedBeforeFillers() {
        XCTAssertEqual(TextPipeline.process(raw: "Эм, спасибо за просмотр", replacements: .defaults),
                       .rejected(.hallucination(text: "Эм, спасибо за просмотр")))
    }

    func testOnlyFillerIsEmpty() {
        XCTAssertEqual(TextPipeline.process(raw: "эээ", replacements: .defaults), .rejected(.empty))
    }

    func testEmptyRecognitionIsEmpty() {
        XCTAssertEqual(TextPipeline.process(raw: "", replacements: .defaults), .rejected(.empty))
    }
}
