import Foundation
import LocalFlowCore

/// Файл словаря замен в Documents. Пока файла нет (первый запуск) — `Replacements.defaults`.
/// Единственное место чтения/записи словаря на диске; `DictationReplacements.current()` читает отсюда.
enum ReplacementsFile {
    private static let fileName = "replacements.yaml"

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func load() -> Replacements {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Replacements.defaults
        }
        return Replacements.parse(text)
    }

    static func save(_ replacements: Replacements) throws {
        try replacements.serialize().write(to: url, atomically: true, encoding: .utf8)
    }
}
