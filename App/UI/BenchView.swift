import SwiftUI
import UIKit
import LocalFlowCore

/// Вкладка «Замер»: записать свои фразы, прогнать каждую через каждую скачанную модель и
/// показать таблицу время/память/текст (истории 26–29, 29a).
struct BenchView: View {
    @StateObject private var runner = BenchRunner()
    @StateObject private var phraseRecorder = PhraseRecorder()
    @ObservedObject private var store = ModelStore.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                phrasesSection
                runSection
                if !runner.rows.isEmpty { resultsSection }
            }
            .navigationTitle("Замер")
            .alert("Не получилось",
                   isPresented: Binding(get: { runner.errorText != nil || phraseRecorder.errorText != nil },
                                        set: { if !$0 { runner.errorText = nil; phraseRecorder.errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(runner.errorText ?? phraseRecorder.errorText ?? "")
            }
            .alert("Нет доступа к микрофону", isPresented: $phraseRecorder.showMicDenied) {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Разреши LocalFlow микрофон: Настройки → LocalFlow → Микрофон.")
            }
        }
    }

    // MARK: Фразы

    private var phrasesSection: some View {
        Section {
            ForEach(runner.phrases) { phrase in
                HStack {
                    Text(phrase.title)
                    Spacer()
                    Text("\(Self.formatted(phrase.seconds)) c").foregroundStyle(.secondary)
                }
            }
            .onDelete { runner.removePhrases(at: $0) }
            recordButton
        } header: {
            Text("Фразы для замера")
        } footer: {
            Text("Надиктуй свои фразы — короткую и длинную, как в обычной диктовке.")
        }
    }

    private var recordButton: some View {
        Button {
            Task {
                if let samples = await phraseRecorder.toggle(), !samples.isEmpty {
                    runner.addPhrase(samples)
                }
            }
        } label: {
            if phraseRecorder.isRecording {
                Label("Стоп — \(Self.formatted(phraseRecorder.elapsed)) c", systemImage: "stop.fill")
                    .foregroundStyle(.red)
            } else {
                Label("Записать фразу", systemImage: "mic.fill")
            }
        }
        .disabled(runner.isRunning)
    }

    // MARK: Прогон

    private var runSection: some View {
        Section {
            if runner.isRunning {
                HStack {
                    ProgressView()
                    Text(runner.statusText ?? "Прогоняю…")
                }
                Button("Отменить", role: .destructive) { runner.cancel() }
            } else {
                Button("Прогнать") { runner.run() }
                    .disabled(!runner.canRun)
            }
        } footer: {
            if store.downloaded.isEmpty {
                Text("Нет ни одной скачанной модели — скачай на вкладке «Модели».")
            } else if runner.phrases.isEmpty {
                Text("Запиши хотя бы одну фразу.")
            }
        }
    }

    // MARK: Результат

    private var resultsSection: some View {
        Section {
            ForEach(Array(runner.rows.enumerated()), id: \.offset) { _, row in
                BenchRowView(row: row)
            }
            Button("Скопировать таблицу") {
                UIPasteboard.general.string = BenchReport.markdown(runner.rows, device: DeviceInfo.machineIdentifier)
            }
        } header: {
            Text("Замерено на этом телефоне")
        }
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

/// Одна строка таблицы: модель, длина фразы, время распознавания (выделено, если больше 5 c),
/// пик памяти, текст.
private struct BenchRowView: View {
    let row: BenchRow
    private var isSlow: Bool { row.transcribeSeconds > 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.model).font(.headline)
            HStack {
                Text("Фраза \(Self.formatted(row.audioSeconds)) c")
                Spacer()
                Text("Распознано за \(Self.formatted(row.transcribeSeconds)) c")
                    .fontWeight(isSlow ? .bold : .regular)
                    .foregroundStyle(isSlow ? .red : .primary)
            }
            .font(.footnote)
            Text(row.peakMemoryMB.map { "Пик памяти: \(Int($0)) МБ" } ?? "Пик памяти: не замерено")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(row.text)
                .font(.callout)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}
