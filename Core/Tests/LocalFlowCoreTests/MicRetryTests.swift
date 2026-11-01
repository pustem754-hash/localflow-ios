import XCTest
import LocalFlowCore

/// Микрофон после Siri: повтор каждые 0,3 c до 3 c, ранний повтор по концу прерывания.
final class MicRetryTests: XCTestCase {
    /// Заглушка микрофона и часов: время идёт только в `wait`.
    final class FakeMic: @unchecked Sendable {
        var clock: TimeInterval = 0
        var attempts = 0
        var waits: [TimeInterval] = []
        /// Номер попытки, с которой микрофон свободен; `nil` — занят всегда.
        var freeFromAttempt: Int?
        /// Прерывание кончается через столько секунд паузы — `wait` возвращается раньше.
        var releaseAfter: TimeInterval?
        /// Пауза длится столько — приложение было приостановлено.
        var suspendedFor: TimeInterval?

        func run() async -> Bool {
            await MicRetry.run(
                now: { self.clock },
                attempt: {
                    self.attempts += 1
                    return self.freeFromAttempt.map { self.attempts >= $0 } ?? false
                },
                wait: { seconds in
                    self.waits.append(seconds)
                    self.clock += self.suspendedFor ?? min(seconds, self.releaseAfter ?? seconds)
                }
            )
        }
    }

    func testFreeMicStartsAtOnce() async {
        let mic = FakeMic()
        mic.freeFromAttempt = 1
        let started = await mic.run()
        XCTAssertTrue(started)
        XCTAssertEqual(mic.attempts, 1)
        XCTAssertEqual(mic.waits, [])
    }

    func testBusyMicRetriesEvery300msThenStarts() async {
        let mic = FakeMic()
        mic.freeFromAttempt = 4
        let started = await mic.run()
        XCTAssertTrue(started)
        XCTAssertEqual(mic.attempts, 4)
        XCTAssertEqual(mic.waits.count, 3)
        for wait in mic.waits { XCTAssertEqual(wait, 0.3, accuracy: 1e-9) }
    }

    func testGivesUpAfter3Seconds() async {
        let mic = FakeMic()
        let started = await mic.run()
        XCTAssertFalse(started)
        XCTAssertEqual(mic.clock, 3, accuracy: 1e-9)
        // Первая попытка сразу и по одной после каждой паузы 0,3 c: 3 / 0,3 = 10 пауз.
        XCTAssertEqual(mic.waits.count, 10)
        XCTAssertEqual(mic.attempts, 11)
        XCTAssertEqual(mic.waits.reduce(0, +), 3, accuracy: 1e-9)
    }

    func testInterruptionEndRetriesEarlier() async {
        let mic = FakeMic()
        mic.freeFromAttempt = 2
        mic.releaseAfter = 0.05
        let started = await mic.run()
        XCTAssertTrue(started)
        XCTAssertEqual(mic.clock, 0.05, accuracy: 1e-9)
    }

    func testSuspendedDuringPauseDoesNotStartLater() async {
        let mic = FakeMic()
        mic.freeFromAttempt = 2
        mic.suspendedFor = 60
        let started = await mic.run()
        XCTAssertFalse(started)
        XCTAssertEqual(mic.attempts, 1)
    }

    func testBusyMessage() {
        XCTAssertEqual(MicRetry.busyMessage, "Микрофон занят — нажмите кнопку")
    }
}
