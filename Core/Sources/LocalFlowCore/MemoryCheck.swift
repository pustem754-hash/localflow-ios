import Foundation

/// Хватит ли памяти, чтобы загрузить модель, — до загрузки, а не вылет посреди неё.
public enum MemoryCheck {
    /// Запас сверх размера файла: буферы вычислений whisper.cpp и кэш декодера.
    /// Оценка по таблице «Memory usage» README whisper.cpp b5454: small — 466 MiB на диске, ~852 MB в памяти.
    /// На телефоне сверить с «Пиком памяти» на экране «Замер».
    public static let overheadBytes: Int64 = 400 * 1_048_576

    public static func requiredBytes(modelBytes: Int64) -> Int64 {
        modelBytes + overheadBytes
    }

    /// `available == 0` — система не сообщила (так в симуляторе): загрузку не запрещаем.
    public static func enough(available: Int64, modelBytes: Int64) -> Bool {
        available == 0 || available >= requiredBytes(modelBytes: modelBytes)
    }
}
