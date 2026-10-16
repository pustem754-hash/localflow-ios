import XCTest
import LocalFlowCore

/// «Распознано за 3,8 c» — спецификация, история 6.
final class DecimalCommaTests: XCTestCase {
    func testOneDigitByDefault() {
        XCTAssertEqual(DecimalComma.string(3.8), "3,8")
        XCTAssertEqual(DecimalComma.string(10.24), "10,2")
        XCTAssertEqual(DecimalComma.string(12.06), "12,1")
        XCTAssertEqual(DecimalComma.string(30), "30,0")
        XCTAssertEqual(DecimalComma.string(0), "0,0")
    }

    func testDigits() {
        XCTAssertEqual(DecimalComma.string(512.4, digits: 0), "512")
        XCTAssertEqual(DecimalComma.string(2.5, digits: 2), "2,50")
    }
}
