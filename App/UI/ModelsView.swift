import SwiftUI
import UniformTypeIdentifiers

/// Вкладка «Модели»: три модели Whisper — скачать, импортировать, выбрать, удалить.
struct ModelsView: View {
    // Значение по умолчанию вычисляется при создании вкладки в TabView — то есть при запуске
    // приложения: так `ModelStore` сразу проверяет общие файлы iTunes и грузит выбранную модель.
    @ObservedObject private var store = ModelStore.shared
    @State private var downloading: [ModelInfo.ID: Double] = [:]
    @State private var importing = false
    @State private var pendingDelete: ModelInfo?
    @State private var errorText: String?
    @State private var infoText: String?

    var body: some View {
        NavigationStack {
            List {
                engineSection
                Section("Модели") {
                    ForEach(store.catalog) { model in row(model) }
                }
                Section {
                    Button {
                        importing = true
                    } label: {
                        Label("Импорт из Файлов", systemImage: "folder")
                    }
                } header: {
                    Text("Без интернета")
                } footer: {
                    Text("Файл .bin можно положить и через iTunes → Общие файлы → LocalFlow: "
                         + "при открытии приложения он опознаётся по размеру и переносится сюда. "
                         + "Подробно — INSTALL-ru.md, «Модель без интернета на телефоне».")
                }
                if !store.unrecognizedSharedFiles.isEmpty {
                    Section {
                        ForEach(store.unrecognizedSharedFiles) { file in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                Text("\(ModelInfo.formatBytes(file.bytes)) байт — не модель из списка, оставлен на месте")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } header: {
                        Text("Не опознаны в общих файлах")
                    } footer: {
                        Text("Нужен один из файлов:\n\(ModelInfo.catalogListText)")
                    }
                }
            }
            .navigationTitle("Модели")
            .onAppear { store.adoptSharedFiles() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Удалить \(pendingDelete?.fileName ?? "")?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let model = pendingDelete { delete(model) }
                }
            }
            .alert("Не получилось",
                   isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .alert("Готово",
                   isPresented: Binding(get: { infoText != nil }, set: { if !$0 { infoText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(infoText ?? "")
            }
        }
    }

    @ViewBuilder private var engineSection: some View {
        Section("В движке") {
            switch store.engineState {
            case .empty:
                Text("Модель не выбрана — скачай или импортируй и нажми «Выбрать».")
                    .foregroundStyle(.secondary)
            case .loading(let title):
                HStack {
                    ProgressView()
                    Text("Загружаю \(title)…")
                }
            case .loaded(let id):
                Label(store.catalog.first { $0.id == id }?.title ?? id, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private func row(_ model: ModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.title).font(.headline)
                Spacer()
                if store.selected == model.id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            Text("\(model.fileName) · \(ByteCountFormatter.string(fromByteCount: model.bytes, countStyle: .file))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let fraction = downloading[model.id] {
                ProgressView(value: fraction) {
                    Text("Скачиваю… \(Int(fraction * 100)) %").font(.caption)
                }
            } else if store.isDownloaded(model) {
                HStack(spacing: 16) {
                    if store.selected != model.id {
                        Button("Выбрать") { Task { await store.select(model) } }
                    } else {
                        Text("Выбрана").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Удалить", role: .destructive) { pendingDelete = model }
                }
                .buttonStyle(.borderless)
            } else {
                Button("Скачать") { download(model) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func download(_ model: ModelInfo) {
        downloading[model.id] = 0
        Task {
            do {
                try await store.download(model) { fraction in
                    if downloading[model.id] != nil { downloading[model.id] = fraction }
                }
                infoText = "\(model.title) скачана."
            } catch {
                errorText = error.localizedDescription
            }
            downloading[model.id] = nil
        }
    }

    private func delete(_ model: ModelInfo) {
        Task {
            do { try await store.delete(model) } catch { errorText = error.localizedDescription }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let model = try store.importFile(at: url)
                infoText = "\(model.title) импортирована."
            } catch {
                errorText = error.localizedDescription
            }
        case .failure(let error):
            errorText = error.localizedDescription
        }
    }
}
