import SwiftUI

enum AppTab: Hashable {
    case dictation, models, dictionary, bench
}

/// Выбранная вкладка: диктовка переводит на «Модели», команда «Начать диктовку» — на «Диктовку».
@MainActor
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()
    @Published var tab: AppTab = .dictation
}
