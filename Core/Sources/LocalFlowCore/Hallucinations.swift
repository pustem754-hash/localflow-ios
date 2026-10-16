import Foundation

public enum Hallucinations {
    /// Типовые выдумки Whisper на тишине — ровно HALLUCINATIONS из LocalFlow main.py.
    public static let phrases: [String] = [
        "продолжение следует", "субтитры создавал",
        "субтитры сделал", "редактор субтитров",
        "спасибо за просмотр", "подписывайтесь на канал",
        "dimatorzok",
    ]

    /// Без учёта регистра, вхождение подстроки.
    public static func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        return phrases.contains { lower.contains($0) }
    }
}
