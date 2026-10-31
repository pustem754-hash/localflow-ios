import XCTest
import LocalFlowCore

/// Проверка общих файлов iTunes: второй вызов во время идущей проверки ждёт её, а не получает «ничего».
final class SingleFlightTests: XCTestCase {
    private actor Counter {
        private(set) var value = 0
        func increment() -> Int {
            value += 1
            return value
        }
    }

    func testCallerDuringRunWaitsForSameResult() async {
        let flight = SingleFlight<Int>()
        let counter = Counter()
        let operation: @Sendable () async -> Int = {
            let n = await counter.increment()
            try? await Task.sleep(nanoseconds: 300_000_000)
            return n * 10
        }
        async let first = flight.run(operation)
        try? await Task.sleep(nanoseconds: 50_000_000)   // первая операция уже идёт
        let second = await flight.run(operation)
        let firstValue = await first
        XCTAssertEqual(firstValue, 10)
        XCTAssertEqual(second, 10)
        let runs = await counter.value
        XCTAssertEqual(runs, 1)
    }

    func testNextCallAfterFinishRunsAgain() async {
        let flight = SingleFlight<Int>()
        let counter = Counter()
        let first = await flight.run { await counter.increment() }
        let second = await flight.run { await counter.increment() }
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
    }
}
