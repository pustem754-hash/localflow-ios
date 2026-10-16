import LocalFlowCore

/// Единственное место, откуда диктовка берёт словарь замен.
enum DictationReplacements {
    static func current() -> Replacements {
        ReplacementsFile.load()
    }
}
