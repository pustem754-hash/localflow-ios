import XCTest
import LocalFlowCore

/// Пороги и случаи — из LocalFlow main.py (`_finalize` и комментарии к константам).
final class RecordingGuardTests: XCTestCase {
    func testConstantsMatchLocalFlow() {
        XCTAssertEqual(RecordingGuard.minHold, 0.3)
        XCTAssertEqual(RecordingGuard.extraAudio, 0.5)
        XCTAssertEqual(RecordingGuard.lostAudio, 1.0)
        XCTAssertEqual(RecordingGuard.lostShare, 0.75)
    }

    func testTouchShorterThanMinHoldIsRejected() {
        XCTAssertEqual(RecordingGuard.check(hold: 0.2, audio: 0.2), .tooShort(hold: 0.2))
    }

    func testTouchIsCheckedBeforeExtraAudio() {
        // 15.10 01:25: держали 0.03 c, пришло 2.30 c — это касание, а не «лишний звук»
        XCTAssertEqual(RecordingGuard.check(hold: 0.03, audio: 2.30), .tooShort(hold: 0.03))
    }

    func testExtraAudioIsRejected() {
        XCTAssertEqual(RecordingGuard.check(hold: 2.0, audio: 2.6), .extraAudio(hold: 2.0, audio: 2.6))
    }

    func testLostAudioIsRejected() {
        // 14.10 03:15: держали 8.13 c, записалось 0.20 c
        XCTAssertEqual(RecordingGuard.check(hold: 8.13, audio: 0.20), .lostAudio(hold: 8.13, audio: 0.20))
    }

    func testNormalRecordingPasses() {
        XCTAssertNil(RecordingGuard.check(hold: 5.0, audio: 4.9))
    }

    func testBoundaryFromMainPyCommentIsNotLoss() {
        // «11.55/10.50 — не потеря»: разница > 1 c, но записано больше 75 %
        XCTAssertNil(RecordingGuard.check(hold: 11.55, audio: 10.50))
    }

    func testMessagesFromSpec() {
        XCTAssertEqual(RejectReason.tooShort(hold: 0.2).message, "Слишком коротко — нажми и говори")
        XCTAssertEqual(RejectReason.extraAudio(hold: 2.0, audio: 2.6).message, "Звук не совпал — повтори")
        XCTAssertEqual(RejectReason.lostAudio(hold: 8.13, audio: 0.2).message, "Звук потерялся — повтори")
        XCTAssertEqual(RejectReason.hallucination(text: "x").message,
                       "Похоже на выдумку Whisper на тишине — повтори фразу")
        XCTAssertEqual(RejectReason.empty.message, "Ничего не распознано — повтори")
    }
}
