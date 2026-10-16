import SwiftUI
import UIKit
import LocalFlowCore

/// Главный экран: большая кнопка «нажал — говоришь — нажал ещё раз».
struct DictationView: View {
    @ObservedObject private var controller = DictationController.shared
    @ObservedObject private var store = ModelStore.shared
    @ObservedObject private var navigation = AppNavigation.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                status
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            }
            if controller.isBenchRunning {
                Text("Идёт замер — диктовка недоступна до его конца")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            recordButton
                .padding(.bottom, 32)
        }
        .padding(.horizontal)
    }

    // MARK: Состояние

    @ViewBuilder
    private var status: some View {
        switch controller.state {
        case .noModel:
            VStack(spacing: 16) {
                Text("Нет загруженной модели").font(.title3.bold())
                Text(noModelDetail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Открыть «Модели»") { navigation.tab = .models }
                    .buttonStyle(.borderedProminent)
            }
        case .micDenied:
            VStack(spacing: 16) {
                Text("Нет доступа к микрофону").font(.title3.bold())
                Text("Разреши LocalFlow микрофон: Настройки → LocalFlow → Микрофон.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
            }
        case .idle:
            VStack(spacing: 8) {
                Text("Нажми и говори").font(.title3)
                if case .loading(let title) = store.engineState {
                    Text("Модель \(title) загружается — говорить уже можно")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        case .recording:
            VStack(spacing: 12) {
                Text("Запись \(Self.clock(controller.elapsed))")
                    .font(.title2.monospacedDigit())
                LevelBar(level: controller.level)
                    .frame(height: 8)
                    .padding(.horizontal, 40)
                Text("Нажми ещё раз, чтобы закончить. Предел — 2:00.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .transcribing:
            VStack(spacing: 12) {
                ProgressView()
                Text("Распознаю…").font(.title3)
            }
        case .copied(let text):
            VStack(spacing: 12) {
                Text(text)
                    .font(.title3)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Скопировано ✓")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let seconds = controller.lastDuration {
                    Text("Распознано за \(Self.seconds(seconds)) c")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        case .rejected(let reason):
            Text(reason.message)
                .font(.title3)
                .multilineTextAlignment(.center)
        case .failed(let message):
            Text(message)
                .font(.title3)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var noModelDetail: String {
        switch store.engineState {
        case .failed(let message): return message
        case .loading(let title): return "Модель \(title) загружается…"
        case .empty, .loaded: return "Скачай и выбери модель на вкладке «Модели»."
        }
    }

    // MARK: Кнопка

    private var isRecording: Bool {
        if case .recording = controller.state { return true }
        return false
    }

    private var isTranscribing: Bool {
        controller.state == .transcribing
    }

    private var recordButton: some View {
        Button {
            controller.toggle()
        } label: {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 160, height: 160)
                .background(Circle().fill(isRecording ? Color.red : Color.accentColor))
        }
        .buttonStyle(.plain)
        .disabled(isTranscribing || controller.isBenchRunning)
        .opacity(isTranscribing || controller.isBenchRunning ? 0.4 : 1)
        .accessibilityLabel(isRecording ? "Закончить запись" : "Начать запись")
    }

    // MARK: Формат

    /// 0:01, 1:59, 2:00
    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 3,8 — десятичная запятая.
    private static func seconds(_ value: TimeInterval) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

private struct LevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.red)
                    .frame(width: geo.size.width * CGFloat(level))
            }
        }
        .animation(.linear(duration: 0.05), value: level)
    }
}
