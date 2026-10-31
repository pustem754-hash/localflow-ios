import XCTest
import LocalFlowCore

/// Перед загрузкой модели — проверка свободной памяти (os_proc_available_memory).
/// Размеры и запасы — как в `ModelInfo.catalog` приложения.
final class MemoryCheckTests: XCTestCase {
    private let mb: Int64 = 1_048_576
    private let small: Int64 = 487_601_967   // ggml-small.bin
    private let smallOverhead: Int64 = 400 * 1_048_576
    private let turbo: Int64 = 574_041_195   // ggml-large-v3-turbo-q5_0.bin
    private let turboOverhead: Int64 = 1_024 * 1_048_576

    func testRequiredIsFileSizePlusModelOverhead() {
        XCTAssertEqual(MemoryCheck.requiredBytes(modelBytes: small, overheadBytes: smallOverhead), small + 400 * mb)
        XCTAssertEqual(MemoryCheck.requiredBytes(modelBytes: turbo, overheadBytes: turboOverhead), turbo + 1_024 * mb)
    }

    func testEnoughWhenAvailableCoversRequired() {
        XCTAssertTrue(MemoryCheck.enough(available: 2_000 * mb, modelBytes: small, overheadBytes: smallOverhead))
        XCTAssertTrue(MemoryCheck.enough(available: small + 400 * mb, modelBytes: small, overheadBytes: smallOverhead))
    }

    func testNotEnoughJustBelowRequired() {
        XCTAssertFalse(MemoryCheck.enough(available: small + 400 * mb - 1, modelBytes: small, overheadBytes: smallOverhead))
        XCTAssertFalse(MemoryCheck.enough(available: 600 * mb, modelBytes: small, overheadBytes: smallOverhead))
    }

    func testUnknownAvailableDoesNotBlock() {
        XCTAssertTrue(MemoryCheck.enough(available: 0, modelBytes: turbo, overheadBytes: turboOverhead))
        XCTAssertNil(MemoryCheck.refusal(available: 0, modelBytes: turbo, overheadBytes: turboOverhead))
    }

    /// Памяти между порогами: small (~865 МБ) проходит, turbo (~1571 МБ) — отказ с цифрами.
    func testBetweenThresholdsSmallPassesTurboRefused() {
        let available: Int64 = 1_200 * mb
        XCTAssertNil(MemoryCheck.refusal(available: available, modelBytes: small, overheadBytes: smallOverhead))
        let needMB = (turbo + turboOverhead) / mb
        XCTAssertEqual(MemoryCheck.refusal(available: available, modelBytes: turbo, overheadBytes: turboOverhead),
                       "Не хватает памяти: нужно \(needMB) МБ, свободно 1200 МБ — закрой другие приложения.")
        XCTAssertEqual(needMB, 1571)
    }
}
