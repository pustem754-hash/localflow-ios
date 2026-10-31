import XCTest
import LocalFlowCore

/// Перед загрузкой модели — проверка свободной памяти (os_proc_available_memory).
final class MemoryCheckTests: XCTestCase {
    private let mb: Int64 = 1_048_576
    private let small: Int64 = 487_601_967   // ggml-small.bin

    func testRequiredIsFileSizePlusOverhead() {
        XCTAssertEqual(MemoryCheck.requiredBytes(modelBytes: small), small + 400 * mb)
    }

    func testEnoughWhenAvailableCoversRequired() {
        XCTAssertTrue(MemoryCheck.enough(available: 2_000 * mb, modelBytes: small))
        XCTAssertTrue(MemoryCheck.enough(available: small + 400 * mb, modelBytes: small))
    }

    func testNotEnoughJustBelowRequired() {
        XCTAssertFalse(MemoryCheck.enough(available: small + 400 * mb - 1, modelBytes: small))
        XCTAssertFalse(MemoryCheck.enough(available: 600 * mb, modelBytes: small))
    }

    func testUnknownAvailableDoesNotBlock() {
        XCTAssertTrue(MemoryCheck.enough(available: 0, modelBytes: small))
    }
}
