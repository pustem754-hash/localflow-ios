import XCTest
import LocalFlowCore

/// Импорт `.bin`: копирование кусками с прогрессом и уборка `*.import` после закрытия посреди импорта.
final class ModelFilesTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testCopyKeepsContentAndReportsProgressUpToOne() throws {
        let source = dir.appendingPathComponent("ggml-small.bin")
        let bytes = Data((0..<10_000).map { UInt8($0 % 251) })
        try bytes.write(to: source)
        let dest = dir.appendingPathComponent("x.import")
        var reported: [Double] = []
        try ChunkedCopy.copy(from: source, to: dest, chunkSize: 3_000) { reported.append($0) }
        XCTAssertEqual(try Data(contentsOf: dest), bytes)
        XCTAssertEqual(reported.count, 4)                  // 3000, 6000, 9000, 10000
        XCTAssertEqual(reported, reported.sorted())
        XCTAssertEqual(reported.last, 1)
    }

    func testCopyOfMissingFileThrowsAndLeavesNothing() {
        let dest = dir.appendingPathComponent("y.import")
        XCTAssertThrowsError(try ChunkedCopy.copy(from: dir.appendingPathComponent("нет.bin"), to: dest))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.path))
    }

    func testLeftoversAreImportAndDownloadOnly() {
        XCTAssertTrue(ModelLeftovers.isLeftover("6F1C-4A.import"))
        XCTAssertTrue(ModelLeftovers.isLeftover("ggml-small.bin.download"))
        XCTAssertFalse(ModelLeftovers.isLeftover("ggml-small.bin"))
        XCTAssertFalse(ModelLeftovers.isLeftover("import.bin"))
    }

    func testRemoveAllDeletesLeftoversAndKeepsModels() throws {
        for name in ["6F1C-4A.import", "ggml-small.bin.download", "ggml-small.bin"] {
            try Data([1, 2, 3]).write(to: dir.appendingPathComponent(name))
        }
        XCTAssertEqual(ModelLeftovers.removeAll(in: dir), ["6F1C-4A.import", "ggml-small.bin.download"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["ggml-small.bin"])
    }
}
