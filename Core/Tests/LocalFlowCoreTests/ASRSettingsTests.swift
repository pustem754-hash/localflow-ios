import XCTest
import LocalFlowCore

/// Значения — из LocalFlow asr.py `transcribe_final`.
final class ASRSettingsTests: XCTestCase {
    func testDecodingParameters() {
        XCTAssertEqual(ASRSettings.language, "ru")
        XCTAssertEqual(ASRSettings.beamSize, 5)
        XCTAssertTrue(ASRSettings.noContext)
        XCTAssertEqual(ASRSettings.minSamples, 1600)
    }

    func testInitialPromptIsVerbatim() {
        XCTAssertEqual(ASRSettings.initialPrompt,
                       "Пример диктовки на русском языке: привет, как дела? Всё хорошо, спасибо. "
                       + "Ещё раз — ясно, чётко, с запятыми и точками.")
    }

    func testVADParameters() {
        XCTAssertEqual(ASRSettings.vadThreshold, 0.3)
        XCTAssertEqual(ASRSettings.vadMinSilenceMs, 500)
    }
}
