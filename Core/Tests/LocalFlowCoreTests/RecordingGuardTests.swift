import XCTest
import LocalFlowCore

/// Пороги и случаи — из текущего LocalFlow main.py (`_finalize` после 16.10 01:08) и историй 10–12 spec.md.
final class RecordingGuardTests: XCTestCase {
    func testConstantsMatchLocalFlow() {
        XCTAssertEqual(RecordingGuard.minHold, 0.3)
        XCTAssertEqual(RecordingGuard.extraAudio, 0.5)
        XCTAssertEqual(RecordingGuard.lostAudio, 1.0)
        XCTAssertEqual(RecordingGuard.lostShare, 0.75)
        XCTAssertEqual(RecordingGuard.lostMin, 1.5)
    }

    func testTouchShorterThanMinHoldIsRejected() {
        XCTAssertEqual(RecordingGuard.decide(hold: 0.2, audio: 0.2), .reject(.tooShort(hold: 0.2)))
    }

    func testTouchIsCheckedBeforeExtraAudio() {
        // 15.10 01:25: держали 0.03 c, пришло 2.30 c — это касание
        XCTAssertEqual(RecordingGuard.decide(hold: 0.03, audio: 2.30), .reject(.tooShort(hold: 0.03)))
    }

    func testExtraAudioKeepsLastHoldPlusHalfSecond() {
        XCTAssertEqual(RecordingGuard.decide(hold: 2.0, audio: 2.6), .transcribe(keepLastSeconds: 2.5))
    }

    func testLostAudioIsRejected() {
        // 14.10 03:15: держали 8.13 c, записалось 0.20 c
        XCTAssertEqual(RecordingGuard.decide(hold: 8.13, audio: 0.20),
                       .reject(.lostAudio(hold: 8.13, audio: 0.20)))
    }

    func testPartlyLostButAtLeastLostMinIsTranscribed() {
        // разница > 1 c и < 75 %, но записано не меньше 1,5 c — распознаём что есть
        XCTAssertEqual(RecordingGuard.decide(hold: 5.0, audio: 3.0), .transcribe(keepLastSeconds: nil))
    }

    func testNormalRecordingIsTranscribed() {
        XCTAssertEqual(RecordingGuard.decide(hold: 5.0, audio: 4.9), .transcribe(keepLastSeconds: nil))
    }

    func testBoundaryFromMainPyCommentIsNotLoss() {
        // «11.55/10.50 — не потеря»
        XCTAssertEqual(RecordingGuard.decide(hold: 11.55, audio: 10.50), .transcribe(keepLastSeconds: nil))
    }

    func testMessagesFromSpec() {
        XCTAssertEqual(RejectReason.tooShort(hold: 0.2).message, "Слишком коротко — нажми и говори")
        XCTAssertEqual(RejectReason.lostAudio(hold: 8.13, audio: 0.2).message, "Звук потерялся — повтори")
        XCTAssertEqual(RejectReason.hallucination(text: "x").message,
                       "Похоже на выдумку Whisper на тишине — повтори фразу")
        XCTAssertEqual(RejectReason.empty.message, "Ничего не распознано — повтори")
    }
}
