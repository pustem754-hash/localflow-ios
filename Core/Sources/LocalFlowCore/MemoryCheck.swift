import Foundation

/// Хватит ли памяти, чтобы загрузить модель, — до загрузки, а не вылет посреди неё.
/// Нужно = размер файла модели + рабочая память whisper.cpp для этой модели (`ModelInfo.memoryOverheadBytes`).
public enum MemoryCheck {
    public static func requiredBytes(modelBytes: Int64, overheadBytes: Int64) -> Int64 {
        modelBytes + overheadBytes
    }

    /// `available == 0` — система не сообщила (так в симуляторе): загрузку не запрещаем.
    public static func enough(available: Int64, modelBytes: Int64, overheadBytes: Int64) -> Bool {
        available == 0 || available >= requiredBytes(modelBytes: modelBytes, overheadBytes: overheadBytes)
    }

    /// `nil` — памяти хватает; иначе текст отказа для пользователя.
    public static func refusal(available: Int64, modelBytes: Int64, overheadBytes: Int64) -> String? {
        if enough(available: available, modelBytes: modelBytes, overheadBytes: overheadBytes) { return nil }
        let needMB = requiredBytes(modelBytes: modelBytes, overheadBytes: overheadBytes) / 1_048_576
        return "Не хватает памяти: нужно \(needMB) МБ, свободно \(available / 1_048_576) МБ — закрой другие приложения."
    }
}
