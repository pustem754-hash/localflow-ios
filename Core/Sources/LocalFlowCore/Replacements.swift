import Foundation

public struct Replacements: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var from: String
        public var to: String

        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// Формат строки как в replacements.yaml: `"как пишет Whisper": "как надо"`, комментарии `#`, пустые строки.
    /// Битые строки пропускаются.
    public static func parse(_ text: String) -> Replacements {
        var entries: [Entry] = []
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            var parser = LineParser(trimmed)
            if let entry = parser.entry() {
                entries.append(entry)
            }
        }
        return Replacements(entries: entries)
    }

    public func serialize() -> String {
        entries.map { "\(Self.quote($0.from)): \(Self.quote($0.to))\n" }.joined()
    }

    /// Порт apply_replacements: целые слова/фразы, без учёта регистра, длинные варианты первыми,
    /// пробелы внутри фразы — любые пробельные, заглавная в начале сохраняется.
    public func apply(_ text: String) -> String {
        if text.isEmpty { return text }
        // вариант в нижнем регистре → замена; дубль — побеждает последний, как в словаре Python
        var table: [String: String] = [:]
        var keys: [String] = []
        for entry in entries {
            let key = entry.from.lowercased()
            if table[key] == nil { keys.append(key) }
            table[key] = entry.to
        }
        if keys.isEmpty { return text }
        // длинные варианты первыми: «Клауд код» раньше «Клауд»; при равной длине — порядок словаря
        let ordered = keys.enumerated().sorted { a, b in
            let la = a.element.unicodeScalars.count, lb = b.element.unicodeScalars.count
            return la != lb ? la > lb : a.offset < b.offset
        }.map(\.element)
        let alternatives = ordered.map { key in
            key.components(separatedBy: " ")
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "\\s+")
        }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![\\w-])(?:\(alternatives))(?![\\w-])", options: [.caseInsensitive])
        else { return text }

        return RegexSupport.replaceMatches(regex, in: text) { match, source in
            let was = source.substring(with: match.range)
            let key = Self.whitespaceRun.stringByReplacingMatches(
                in: was.lowercased(), range: RegexSupport.fullRange(was.lowercased()), withTemplate: " ")
            guard var replacement = table[key], let first = replacement.first else { return was }
            // заглавная в начале предложения сохраняется
            if let wasFirst = was.first, wasFirst.isUppercase, first.isLowercase {
                replacement = first.uppercased() + String(replacement.dropFirst())
            }
            return replacement
        }
    }

    /// Содержимое replacements.yaml LocalFlow — словарь при первом запуске.
    public static let defaults: Replacements = parse(localFlowYAML)

    private static let whitespaceRun = try! NSRegularExpression(pattern: "\\s+")

    private static func quote(_ text: String) -> String {
        var out = "\""
        for char in text {
            switch char {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default: out.append(char)
            }
        }
        return out + "\""
    }

    /// Разбор одной строки `ключ: значение`; ключ и значение — в двойных, одинарных кавычках или без.
    private struct LineParser {
        private let chars: [Character]
        private var index = 0

        init(_ line: String) {
            chars = Array(line)
        }

        mutating func entry() -> Entry? {
            guard let from = scalar(isKey: true), !from.isEmpty else { return nil }
            skipSpaces()
            guard index < chars.count, chars[index] == ":" else { return nil }
            index += 1
            guard let to = scalar(isKey: false), !to.isEmpty else { return nil }
            skipSpaces()
            // после значения допустим только комментарий
            guard index == chars.count || chars[index] == "#" else { return nil }
            return Entry(from: from, to: to)
        }

        private mutating func skipSpaces() {
            while index < chars.count, chars[index] == " " || chars[index] == "\t" { index += 1 }
        }

        private mutating func scalar(isKey: Bool) -> String? {
            skipSpaces()
            guard index < chars.count else { return nil }
            let quote = chars[index]
            if quote == "\"" || quote == "'" {
                return quoted(by: quote)
            }
            var out = ""
            while index < chars.count {
                let char = chars[index]
                let next: Character? = index + 1 < chars.count ? chars[index + 1] : nil
                if isKey, char == ":", next == nil || next == " " || next == "\t" { break }
                if char == "#", let last = out.last, last == " " || last == "\t" { break }
                out.append(char)
                index += 1
            }
            return out.trimmingCharacters(in: .whitespaces)
        }

        private mutating func quoted(by quote: Character) -> String? {
            index += 1
            var out = ""
            while index < chars.count {
                let char = chars[index]
                if quote == "\"", char == "\\" {
                    guard index + 1 < chars.count else { return nil }
                    switch chars[index + 1] {
                    case "n": out.append("\n")
                    case "t": out.append("\t")
                    default: out.append(chars[index + 1])
                    }
                    index += 2
                    continue
                }
                if char == quote {
                    if quote == "'", index + 1 < chars.count, chars[index + 1] == "'" {
                        out.append("'")
                        index += 2
                        continue
                    }
                    index += 1
                    return out
                }
                out.append(char)
                index += 1
            }
            return nil   // кавычка не закрыта — строка битая
        }
    }

    // Дословная копия replacements.yaml десктопной версии LocalFlow.
    private static let localFlowYAML = """
    # Словарь замен LocalFlow: применяется к тексту Whisper до LLM-очистки.
    # Формат: одна строка — одна замена.  "как пишет Whisper": "как надо"
    # Ищутся только целые слова/фразы, регистр не важен.
    # Новое слово — добавить строку и перезапустить LocalFlow.
    # Кавычки нужны, если в строке есть двоеточие или решётка.

    "Алламу": "Ollama"
    "Аллама": "Ollama"
    "Олламу": "Ollama"
    "Оллама": "Ollama"
    "Аламу": "Ollama"
    "Алама": "Ollama"
    "Алламе": "Ollama"
    "Олламой": "Ollama"
    "Аламой": "Ollama"

    "Квор": "Kwork"
    "Кворк": "Kwork"
    "Quark": "Kwork"

    "Апворк": "Upwork"
    "Upward": "Upwork"

    "Локал флоу": "LocalFlow"
    "Локалфлоу": "LocalFlow"
    "Local Flow": "LocalFlow"
    "Local Love": "LocalFlow"

    "Клауд код": "Claude Code"
    "Клод код": "Claude Code"
    "Клауд": "Claude"
    "Клод": "Claude"

    "Т-банк": "Т-Банк"
    "Т банк": "Т-Банк"

    "ЮКаса": "ЮKassa"
    "Юкасса": "ЮKassa"
    "Ю-каста": "ЮKassa"
    """
}
