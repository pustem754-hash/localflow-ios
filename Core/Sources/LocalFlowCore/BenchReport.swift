import Foundation

public struct BenchRow: Equatable, Sendable {
    public var model: String
    public var audioSeconds: Double
    public var transcribeSeconds: Double
    public var peakMemoryMB: Double?
    public var text: String

    public init(model: String, audioSeconds: Double, transcribeSeconds: Double,
                peakMemoryMB: Double?, text: String) {
        self.model = model
        self.audioSeconds = audioSeconds
        self.transcribeSeconds = transcribeSeconds
        self.peakMemoryMB = peakMemoryMB
        self.text = text
    }
}

public enum BenchReport {
    /// Таблица замера в markdown — чтобы скопировать и прислать в чат.
    public static func markdown(_ rows: [BenchRow], device: String) -> String {
        var lines = [
            "## Замер LocalFlow — \(cell(device))",
            "",
            "Все цифры — замерено на этом телефоне.",
            "",
            "| Модель | Фраза, c | Распознавание, c | Пик памяти, МБ | Текст |",
            "|---|---|---|---|---|",
        ]
        for row in rows {
            let memory = row.peakMemoryMB.map { number($0, digits: 0) } ?? "не замерено"
            let audio = number(row.audioSeconds, digits: 1)
            let transcribe = number(row.transcribeSeconds, digits: 1)
            lines.append("| \(cell(row.model)) | \(audio) | \(transcribe) | \(memory) | \(cell(row.text)) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Десятичная запятая, как принято в русском тексте.
    private static func number(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static func cell(_ text: String) -> String {
        let oneLine = text.components(separatedBy: .newlines).joined(separator: " ")
        let escaped = oneLine.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
