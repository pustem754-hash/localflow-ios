import SwiftUI
import LocalFlowCore
import whisper

@main
struct LocalFlowApp: App {
    init() {
        // Вызовы из обеих зависимостей: сборка доказывает, что whisper.cpp и LocalFlowCore слинкованы.
        print("whisper.cpp:", String(cString: whisper_print_system_info()))
        print("LocalFlowCore: словарь замен —", Replacements.defaults.entries.count, "строк")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @ObservedObject private var navigation = AppNavigation.shared

    var body: some View {
        TabView(selection: $navigation.tab) {
            DictationView()
                .tabItem { Label("Диктовка", systemImage: "mic") }
                .tag(AppTab.dictation)
            ModelsView()
                .tabItem { Label("Модели", systemImage: "square.and.arrow.down") }
                .tag(AppTab.models)
            DictionaryView()
                .tabItem { Label("Словарь", systemImage: "character.book.closed") }
                .tag(AppTab.dictionary)
            BenchView()
                .tabItem { Label("Замер", systemImage: "stopwatch") }
                .tag(AppTab.bench)
        }
    }
}
