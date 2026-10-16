import AppIntents

/// Действие «Начать диктовку» в «Командах» (R26): открывает LocalFlow и сразу начинает запись.
/// Запись идёт только с приложением на экране — фоновую запись (`AudioRecordingIntent`) в эту сборку не берём.
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Начать диктовку"
    static let description = IntentDescription("Открывает LocalFlow и сразу начинает запись.")

    /// iOS 17–25. На iOS 26+ система берёт `supportedModes`.
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DictationController.shared.startFromIntent()
        return .result()
    }
}

@available(iOS 26.0, *)
extension StartDictationIntent {
    static var supportedModes: IntentModes { .foreground }
}
