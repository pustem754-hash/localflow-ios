import Foundation

/// Общие помощники для портов регулярных выражений LocalFlow (Python `re` → ICU NSRegularExpression).
enum RegexSupport {
    static func fullRange(_ text: String) -> NSRange {
        NSRange(location: 0, length: (text as NSString).length)
    }

    /// Аналог `re.sub` с функцией: `transform` получает совпадение и исходную строку.
    static func replaceMatches(_ regex: NSRegularExpression, in text: String,
                               _ transform: (NSTextCheckingResult, NSString) -> String) -> String {
        let source = text as NSString
        var out = ""
        var cursor = 0
        for match in regex.matches(in: text, range: fullRange(text)) {
            out += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            out += transform(match, source)
            cursor = NSMaxRange(match.range)
        }
        out += source.substring(from: cursor)
        return out
    }

    static func group(_ match: NSTextCheckingResult, _ index: Int, in source: NSString) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : source.substring(with: range)
    }

    static func contains(_ regex: NSRegularExpression, in text: String) -> Bool {
        regex.firstMatch(in: text, range: fullRange(text)) != nil
    }

    /// Аналог Python `str.rstrip()`.
    static func trimTrailingWhitespace(_ text: String) -> String {
        var rest = Substring(text)
        while let last = rest.last, last.isWhitespace {
            rest = rest.dropLast()
        }
        return String(rest)
    }
}
