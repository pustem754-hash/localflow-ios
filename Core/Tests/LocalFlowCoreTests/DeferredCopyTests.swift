import XCTest
import LocalFlowCore

/// Уход в фон во время распознавания: текст ложится в буфер при возврате в приложение.
final class DeferredCopyTests: XCTestCase {
    func testForegroundCopiesNow() {
        var copy = DeferredCopy()
        XCTAssertEqual(copy.deliver("Привет", inForeground: true), "Привет")
        XCTAssertNil(copy.takeOnReturn())
    }

    func testBackgroundDefersUntilReturnOnce() {
        var copy = DeferredCopy()
        XCTAssertNil(copy.deliver("Привет", inForeground: false))
        XCTAssertEqual(copy.pending, "Привет")
        XCTAssertEqual(copy.takeOnReturn(), "Привет")
        XCTAssertNil(copy.takeOnReturn())
    }

    func testNewerTextReplacesPending() {
        var copy = DeferredCopy()
        _ = copy.deliver("первая", inForeground: false)
        _ = copy.deliver("вторая", inForeground: false)
        XCTAssertEqual(copy.takeOnReturn(), "вторая")
    }

    func testForegroundCopyDropsOlderPending() {
        var copy = DeferredCopy()
        _ = copy.deliver("старая", inForeground: false)
        XCTAssertEqual(copy.deliver("новая", inForeground: true), "новая")
        XCTAssertNil(copy.takeOnReturn())
    }
}
