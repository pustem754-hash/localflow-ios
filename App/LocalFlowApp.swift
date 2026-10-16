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
    var body: some View {
        TabView {
            DictationView()
                .tabItem { Label("Диктовка", systemImage: "mic") }
            ModelsView()
                .tabItem { Label("Модели", systemImage: "square.and.arrow.down") }
            DictionaryView()
                .tabItem { Label("Словарь", systemImage: "character.book.closed") }
            BenchView()
                .tabItem { Label("Замер", systemImage: "stopwatch") }
        }
    }
}
