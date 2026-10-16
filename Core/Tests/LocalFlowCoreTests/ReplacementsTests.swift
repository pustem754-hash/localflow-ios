import XCTest
import LocalFlowCore

/// Формат и правила — replacements.yaml и apply_replacements из LocalFlow cleanup.py.
final class ReplacementsTests: XCTestCase {
    private typealias Entry = Replacements.Entry

    /// Все строки replacements.yaml LocalFlow, в том же порядке.
    private let localFlowPairs: [(String, String)] = [
        ("Алламу", "Ollama"), ("Аллама", "Ollama"), ("Олламу", "Ollama"), ("Оллама", "Ollama"),
        ("Аламу", "Ollama"), ("Алама", "Ollama"), ("Алламе", "Ollama"), ("Олламой", "Ollama"),
        ("Аламой", "Ollama"),
        ("Квор", "Kwork"), ("Кворк", "Kwork"), ("Quark", "Kwork"),
        ("Апворк", "Upwork"), ("Upward", "Upwork"),
        ("Локал флоу", "LocalFlow"), ("Локалфлоу", "LocalFlow"), ("Local Flow", "LocalFlow"),
        ("Local Love", "LocalFlow"),
        ("Клауд код", "Claude Code"), ("Клод код", "Claude Code"), ("Клауд", "Claude"), ("Клод", "Claude"),
        ("Т-банк", "Т-Банк"), ("Т банк", "Т-Банк"),
        ("ЮКаса", "ЮKassa"), ("Юкасса", "ЮKassa"), ("Ю-каста", "ЮKassa"),
    ]

    func testDefaultsAreLocalFlowFile() {
        let expected = localFlowPairs.map { Entry(from: $0.0, to: $0.1) }
        XCTAssertEqual(Replacements.defaults.entries, expected)
    }

    func testParseSkipsCommentsBlankAndBrokenLines() {
        let text = """
        # Словарь замен
        "Клауд": "Claude"

        битая строка без двоеточия
        "Т банк": "Т-Банк"   # хвостовой комментарий
        Кворк: Kwork
        "незакрытая: "x"
        "пустое": ""
        """
        let parsed = Replacements.parse(text)
        XCTAssertEqual(parsed.entries, [
            Entry(from: "Клауд", to: "Claude"),
            Entry(from: "Т банк", to: "Т-Банк"),
            Entry(from: "Кворк", to: "Kwork"),
        ])
    }

    func testSerializeRoundTrips() {
        let original = Replacements(entries: [
            Entry(from: "Клауд код", to: "Claude Code"),
            Entry(from: "с \"кавычками\"", to: "a\\b: #c"),
        ])
        XCTAssertEqual(Replacements.parse(original.serialize()), original)
        XCTAssertEqual(Replacements.parse(Replacements.defaults.serialize()), Replacements.defaults)
    }

    func testLongerPhraseWinsOverShorter() {
        XCTAssertEqual(Replacements.defaults.apply("Запусти Клауд код"), "Запусти Claude Code")
        XCTAssertEqual(Replacements.defaults.apply("спроси Клауд"), "спроси Claude")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(Replacements.defaults.apply("запусти АЛАМУ"), "запусти Ollama")
        XCTAssertEqual(Replacements.defaults.apply("клауд код"), "Claude Code")
    }

    func testCapitalAtStartIsKept() {
        let repl = Replacements(entries: [Entry(from: "привет", to: "здравствуйте")])
        XCTAssertEqual(repl.apply("Привет, мир"), "Здравствуйте, мир")
        XCTAssertEqual(repl.apply("ну привет"), "ну здравствуйте")
    }

    func testAnyWhitespaceInsidePhrase() {
        XCTAssertEqual(Replacements.defaults.apply("Клауд   код"), "Claude Code")
        XCTAssertEqual(Replacements.defaults.apply("это Local\tFlow"), "это LocalFlow")
    }

    func testOnlyWholeWords() {
        XCTAssertEqual(Replacements.defaults.apply("Клаудия пришла"), "Клаудия пришла")
        XCTAssertEqual(Replacements.defaults.apply("Т-банк"), "Т-Банк")
    }

    func testEmptyDictionaryChangesNothing() {
        XCTAssertEqual(Replacements(entries: []).apply("Клауд код"), "Клауд код")
    }
}
