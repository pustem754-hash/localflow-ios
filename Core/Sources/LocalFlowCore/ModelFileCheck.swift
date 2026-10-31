import Foundation

/// Итог проверки файла модели по sha256.
public enum ModelFileCheck: Equatable, Sendable {
    case ok
    case mismatch     // содержимое не то — файл не принимается
    case unreadable   // файл не прочитался — это не «не тот файл»: не удалять, предложить повторить

    /// `hash == nil` — посчитать хэш не удалось (ошибка чтения).
    public static func verdict(hash: String?, expected: String) -> ModelFileCheck {
        guard let hash else { return .unreadable }
        return hash.lowercased() == expected.lowercased() ? .ok : .mismatch
    }
}
