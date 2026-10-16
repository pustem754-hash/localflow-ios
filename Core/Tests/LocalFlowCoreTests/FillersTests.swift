import XCTest
import LocalFlowCore

/// Поведение remove_fillers из LocalFlow cleanup.py, разобранное вручную.
final class FillersTests: XCTestCase {
    func testFillerAtTextStartCapitalizesNextWord() {
        XCTAssertEqual(Fillers.remove("эм, перезапусти сервер"), "Перезапусти сервер")
        XCTAssertEqual(Fillers.remove("Ммм, ладно"), "Ладно")
    }

    func testFillerAfterSentenceEndCapitalizesNextWord() {
        XCTAssertEqual(Fillers.remove("Готово. Эээ, давай дальше"), "Готово. Давай дальше")
        XCTAssertEqual(Fillers.remove("Что дальше? э-э проверим"), "Что дальше? Проверим")
    }

    func testFillerInsideSentenceIsRemovedWithoutCapital() {
        XCTAssertEqual(Fillers.remove("Сделай, мм, вот так"), "Сделай, вот так")
    }

    func testNoSpaceLeftBeforePunctuation() {
        XCTAssertEqual(Fillers.remove("Хорошо эм."), "Хорошо.")
    }

    func testNuAndVotAreKept() {
        XCTAssertEqual(Fillers.remove("ну вот эм это"), "ну вот это")
        XCTAssertEqual(Fillers.remove("ну вот так"), "ну вот так")
    }

    func testFillersInsideWordsAreKept() {
        XCTAssertEqual(Fillers.remove("эмоции и мммузыка"), "эмоции и мммузыка")
    }

    func testOnlyFillerGivesEmpty() {
        XCTAssertEqual(Fillers.remove("эээ"), "")
        XCTAssertEqual(Fillers.remove("Эм."), "")
    }

    func testTextWithoutFillersIsUnchanged() {
        XCTAssertEqual(Fillers.remove("Привет, как дела?"), "Привет, как дела?")
    }
}
