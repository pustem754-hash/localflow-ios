import Foundation

public enum Fillers {
    // слова-паразиты — только этот список и только отдельными словами;
    // «ну», «вот», «короче» не трогаем: бывают по смыслу
    private static let filler = try! NSRegularExpression(
        pattern: "(?<![\\w-])(?:эээ|ммм|э-э|эм|мм)(?![\\w-])[,…]*\\s*",
        options: [.caseInsensitive])
    /// Метка «здесь начало предложения» после удалённого паразита.
    private static let capMark = "\u{E000}"
    private static let capRun = try! NSRegularExpression(pattern: "\\uE000+(\\w?)")
    private static let spaceBeforePunct = try! NSRegularExpression(pattern: "\\s+([,.!?…])")
    private static let wordChar = try! NSRegularExpression(pattern: "\\w")

    /// Порт remove_fillers из LocalFlow cleanup.py: эээ, ммм, э-э, эм, мм — отдельными словами,
    /// заглавная после удалённого паразита в начале предложения, пустой результат если остался только паразит.
    public static func remove(_ text: String) -> String {
        guard RegexSupport.contains(filler, in: text) else { return text }
        var out = RegexSupport.replaceMatches(filler, in: text) { match, source in
            let before = RegexSupport.trimTrailingWhitespace(source.substring(to: match.range.location))
            // паразит стоял в начале предложения — следующее слово с заглавной
            if let last = before.last, !".!?".contains(last) {
                return ""
            }
            return capMark
        }
        out = RegexSupport.replaceMatches(capRun, in: out) { match, source in
            RegexSupport.group(match, 1, in: source).uppercased()
        }
        out = spaceBeforePunct.stringByReplacingMatches(
            in: out, range: RegexSupport.fullRange(out), withTemplate: "$1")
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if !RegexSupport.contains(wordChar, in: out) {   // был один паразит — вставлять нечего
            out = ""
        }
        return out
    }
}
