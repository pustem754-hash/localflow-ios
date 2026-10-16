import XCTest
import LocalFlowCore

final class BenchReportTests: XCTestCase {
    func testMarkdownTable() {
        let rows = [
            BenchRow(model: "small", audioSeconds: 10.24, transcribeSeconds: 3.8,
                     peakMemoryMB: 512.4, text: "Привет, мир."),
            BenchRow(model: "large-v3-turbo-q5_0", audioSeconds: 30.0, transcribeSeconds: 12.06,
                     peakMemoryMB: nil, text: "a | b\nc"),
        ]
        let md = BenchReport.markdown(rows, device: "iPhone 11")
        XCTAssertTrue(md.contains("iPhone 11"), md)
        XCTAssertTrue(md.contains("замерено на этом телефоне"), md)
        XCTAssertTrue(md.contains("| Модель | Фраза, c | Распознавание, c | Пик памяти, МБ | Текст |"), md)
        XCTAssertTrue(md.contains("| small | 10,2 | 3,8 | 512 | Привет, мир. |"), md)
        XCTAssertTrue(md.contains("| large-v3-turbo-q5_0 | 30,0 | 12,1 | не замерено | a \\| b c |"), md)
    }
}
