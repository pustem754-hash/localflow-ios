import XCTest
import LocalFlowCore

/// Список — дословно HALLUCINATIONS из LocalFlow main.py.
final class HallucinationsTests: XCTestCase {
    private let expected = [
        "продолжение следует", "субтитры создавал",
        "субтитры сделал", "редактор субтитров",
        "спасибо за просмотр", "подписывайтесь на канал",
        "dimatorzok",
    ]

    func testPhrasesAreExactlyLocalFlowList() {
        XCTAssertEqual(Hallucinations.phrases, expected)
    }

    func testEveryPhraseMatchesInAnyCase() {
        for phrase in expected {
            XCTAssertTrue(Hallucinations.matches(phrase), phrase)
            XCTAssertTrue(Hallucinations.matches(phrase.uppercased()), phrase)
            let capitalized: String = phrase.prefix(1).uppercased() + String(phrase.dropFirst()) + "."
            XCTAssertTrue(Hallucinations.matches(capitalized), capitalized)
        }
    }

    func testEveryPhraseMatchesInsideLongText() {
        for phrase in expected {
            let text = "Ну вот, сегодня поговорили. \(phrase.uppercased()) И до встречи!"
            XCTAssertTrue(Hallucinations.matches(text), text)
        }
    }

    func testOrdinaryTextDoesNotMatch() {
        XCTAssertFalse(Hallucinations.matches("Перезапусти Ollama и продолжи тест"))
        XCTAssertFalse(Hallucinations.matches(""))
    }
}
