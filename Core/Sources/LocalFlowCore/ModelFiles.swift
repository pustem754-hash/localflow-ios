import Foundation

/// Копирование файла модели кусками: память не растёт на 0,5 ГБ, прогресс виден по ходу.
public enum ChunkedCopy {
    /// `progress` — доля 0…1 после каждого куска. Ошибка — недокопированный `destination` удаляется.
    public static func copy(from source: URL, to destination: URL, chunkSize: Int = 4 << 20,
                            progress: (Double) -> Void = { _ in }) throws {
        let fm = FileManager.default
        let total = (try fm.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard fm.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            var copied: Int64 = 0
            while true {
                let more: Bool = try drainingPool {
                    guard let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty else { return false }
                    try output.write(contentsOf: chunk)
                    copied += Int64(chunk.count)
                    return true
                }
                guard more else { break }
                if total > 0 { progress(min(1, Double(copied) / Double(total))) }
            }
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }

    #if canImport(ObjectiveC)
    private static func drainingPool<T>(_ body: () throws -> T) rethrows -> T {
        try autoreleasepool(invoking: body)
    }
    #else
    private static func drainingPool<T>(_ body: () throws -> T) rethrows -> T {
        try body()
    }
    #endif
}

/// Хвосты прерванного импорта и скачивания в папке моделей. При запуске ни один импорт
/// и ни одна загрузка не идут — всё такое можно удалять.
public enum ModelLeftovers {
    public static func isLeftover(_ fileName: String) -> Bool {
        fileName.hasSuffix(".import") || fileName.hasSuffix(".download")
    }

    /// Удаляет хвосты в `directory`; возвращает имена удалённых.
    @discardableResult
    public static func removeAll(in directory: URL) -> [String] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter(isLeftover).filter { name in
            (try? fm.removeItem(at: directory.appendingPathComponent(name))) != nil
        }.sorted()
    }
}
