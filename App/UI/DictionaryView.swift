import SwiftUI
import LocalFlowCore

/// Вкладка «Словарь»: список «как пишет Whisper → как надо» — добавить, изменить, удалить,
/// вернуть словарь LocalFlow. Хранится файлом через `ReplacementsFile`; правки читает следующая
/// диктовка без перезапуска приложения (R28).
struct DictionaryView: View {
    @State private var replacements = ReplacementsFile.load()
    @State private var editingEntry: EditingEntry?
    @State private var showResetConfirm = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(replacements.entries.enumerated()), id: \.offset) { index, entry in
                        Button {
                            editingEntry = EditingEntry(index: index, from: entry.from, to: entry.to)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.from)
                                    .foregroundStyle(.primary)
                                Text("→ \(entry.to)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("Замены")
                } footer: {
                    if replacements.entries.isEmpty {
                        Text("Список пуст — добавь первую замену кнопкой «+».")
                    }
                }
                Section {
                    Button("Вернуть словарь LocalFlow", role: .destructive) {
                        showResetConfirm = true
                    }
                } footer: {
                    Text("Список замен вернётся к исходному из LocalFlow — твои правки исчезнут.")
                }
            }
            .navigationTitle("Словарь")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingEntry = EditingEntry(index: nil, from: "", to: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить замену")
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditor(initial: entry, existing: replacements.entries, onSave: save)
            }
            .confirmationDialog("Вернуть словарь LocalFlow?", isPresented: $showResetConfirm,
                                 titleVisibility: .visible) {
                Button("Вернуть", role: .destructive) { reset() }
            }
            .alert("Не получилось",
                   isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save(index: Int?, from: String, to: String) {
        var entries = replacements.entries
        if let index {
            entries[index] = Replacements.Entry(from: from, to: to)
        } else {
            entries.append(Replacements.Entry(from: from, to: to))
        }
        update(entries)
    }

    private func delete(at offsets: IndexSet) {
        var entries = replacements.entries
        entries.remove(atOffsets: offsets)
        update(entries)
    }

    private func reset() {
        update(Replacements.defaults.entries)
    }

    private func update(_ entries: [Replacements.Entry]) {
        let new = Replacements(entries: entries)
        do {
            try ReplacementsFile.save(new)
            replacements = new
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// `index == nil` — новая запись; иначе изменение существующей по месту в списке.
private struct EditingEntry: Identifiable {
    let id = UUID()
    let index: Int?
    var from: String
    var to: String
}

private struct EntryEditor: View {
    let initial: EditingEntry
    let existing: [Replacements.Entry]
    let onSave: (Int?, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var from: String
    @State private var to: String

    init(initial: EditingEntry, existing: [Replacements.Entry], onSave: @escaping (Int?, String, String) -> Void) {
        self.initial = initial
        self.existing = existing
        self.onSave = onSave
        _from = State(initialValue: initial.from)
        _to = State(initialValue: initial.to)
    }

    private var trimmedFrom: String { from.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedTo: String { to.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isDuplicate: Bool {
        existing.enumerated().contains { offset, entry in
            offset != initial.index && entry.from.caseInsensitiveCompare(trimmedFrom) == .orderedSame
        }
    }

    private var canSave: Bool {
        !trimmedFrom.isEmpty && !trimmedTo.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Как пишет Whisper", text: $from)
                    TextField("Как надо", text: $to)
                } footer: {
                    if trimmedFrom.isEmpty || trimmedTo.isEmpty {
                        Text("Оба поля обязательны.")
                    } else if isDuplicate {
                        Text("Такая запись «как пишет Whisper» уже есть в словаре.")
                    }
                }
            }
            .navigationTitle(initial.index == nil ? "Новая замена" : "Изменить замену")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(initial.index, trimmedFrom, trimmedTo)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
