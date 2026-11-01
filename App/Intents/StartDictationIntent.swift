import AppIntents

/// Действие «Начать диктовку» в «Командах», Spotlight и Siri: открывает LocalFlow и сразу начинает запись.
/// Запись идёт только с приложением на экране — фоновую запись (`AudioRecordingIntent`) в эту сборку не берём.
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Начать диктовку"
    static let description = IntentDescription("Открывает LocalFlow и сразу начинает запись.")
    /// Приложение выходит на экран сразу после разбора параметров — до `perform()`.
    static let supportedModes: IntentModes = .foreground(.immediate)

    /// Ничего не ждёт: ставит просьбу о записи и возвращается. Запись начинает `DictationController`,
    /// когда сцена активна и модель готова.
    @MainActor
    func perform() async throws -> some IntentResult {
        DictationController.shared.startFromIntent()
        return .result()
    }
}

/// Готовая команда — видна в «Командах», Spotlight и Siri без ручной сборки.
/// Каждая фраза обязана содержать название приложения, иначе сборка не проходит.
struct LocalFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: [
                "Начать диктовку в \(.applicationName)",
                "Диктовка в \(.applicationName)",
            ],
            shortTitle: "Начать диктовку",
            systemImageName: "mic"
        )
    }
}
