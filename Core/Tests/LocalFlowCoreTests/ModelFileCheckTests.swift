import XCTest
import LocalFlowCore

/// Ошибка чтения файла — не «хэш не совпал»: файл не удаляется, пользователь повторяет.
final class ModelFileCheckTests: XCTestCase {
    private let expected = "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b"

    func testSameHashIsOk() {
        XCTAssertEqual(ModelFileCheck.verdict(hash: expected, expected: expected), .ok)
        XCTAssertEqual(ModelFileCheck.verdict(hash: expected.uppercased(), expected: expected), .ok)
    }

    func testOtherHashIsMismatch() {
        XCTAssertEqual(ModelFileCheck.verdict(hash: String(repeating: "0", count: 64), expected: expected), .mismatch)
    }

    func testReadErrorIsUnreadableNotMismatch() {
        XCTAssertEqual(ModelFileCheck.verdict(hash: nil, expected: expected), .unreadable)
    }
}
