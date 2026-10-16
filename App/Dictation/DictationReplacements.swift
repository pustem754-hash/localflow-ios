import LocalFlowCore

/// Единственное место, откуда диктовка берёт словарь замен.
/// Таск 04 заменяет тело на `ReplacementsFile.load()` — тогда правки словаря применяются к следующей фразе.
enum DictationReplacements {
    static func current() -> Replacements {
        Replacements.defaults
    }
}
