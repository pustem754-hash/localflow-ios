import Foundation
import LocalFlowCore
import whisper

enum EngineError: LocalizedError {
    case notLoaded
    case fileMissing(String)
    case initFailed(String)
    case transcribeFailed(Int32)
    case wrongModel

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "Модель не загружена — выбери её на вкладке «Модели»."
        case .fileMissing(let name):
            return "Нет файла \(name)."
        case .initFailed(let name):
            return "\(name): файл битый или не хватило памяти."
        case .transcribeFailed(let code):
            return "Whisper не смог распознать запись (код \(code))."
        case .wrongModel:
            return "В движке сейчас другая модель — подожди, пока загрузится выбранная, и повтори."
        }
    }
}

/// Контекст whisper.cpp. Одна модель в памяти; доступ к C-контексту — только через актор.
/// Параметры распознавания — только из `ASRSettings` (как `transcribe_final` в LocalFlow asr.py),
/// остальное — значения whisper.cpp по умолчанию.
actor WhisperEngine {
    static let shared = WhisperEngine()

    /// VAD Silero из ресурсов приложения (кладёт workflow ios-build).
    static var bundledVAD: URL? {
        Bundle.main.url(forResource: "ggml-silero-v6.2.0", withExtension: "bin")
    }

    private var context: OpaquePointer?
    private var vadPath: String?
    /// `ModelInfo.ID` модели, которая сейчас в контексте; `nil` — пусто.
    private(set) var loadedModelID: String?

    var isLoaded: Bool { context != nil }

    /// Выгружает прежнюю модель до загрузки новой — в памяти никогда не две.
    /// `id` — `ModelInfo.ID` загружаемой модели, по нему вызывающие сверяют, что в движке.
    func load(model: URL, vad: URL, id: String) throws {
        unload()
        let fm = FileManager.default
        guard fm.fileExists(atPath: model.path) else { throw EngineError.fileMissing(model.lastPathComponent) }
        guard fm.fileExists(atPath: vad.path) else { throw EngineError.fileMissing(vad.lastPathComponent) }

        var cparams = whisper_context_default_params()
#if targetEnvironment(simulator)
        cparams.use_gpu = false
#endif
        guard let ctx = whisper_init_from_file_with_params(model.path, cparams) else {
            throw EngineError.initFailed(model.lastPathComponent)
        }
        context = ctx
        vadPath = vad.path
        loadedModelID = id
    }

    func unload() {
        if let context { whisper_free(context) }
        context = nil
        vadPath = nil
        loadedModelID = nil
    }

    /// 16 кГц mono Float → текст. Клип короче `ASRSettings.minSamples` — пустая строка без вызова модели.
    /// `expectedModel` задан и в движке другая модель — `EngineError.wrongModel`, распознавания нет.
    func transcribe(_ samples: [Float], expectedModel: String? = nil) async throws -> String {
        if samples.count < ASRSettings.minSamples { return "" }
        guard let context, let vadPath else { throw EngineError.notLoaded }
        if let expectedModel, expectedModel != loadedModelID { throw EngineError.wrongModel }

        var params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        params.beam_search.beam_size = Int32(ASRSettings.beamSize)
        params.no_context = ASRSettings.noContext
        params.translate = false
        params.detect_language = false
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        params.vad = true
        params.vad_params.threshold = ASRSettings.vadThreshold
        params.vad_params.min_silence_duration_ms = Int32(ASRSettings.vadMinSilenceMs)
        params.vad_params.speech_pad_ms = Int32(ASRSettings.vadSpeechPadMs)
        params.vad_params.min_speech_duration_ms = Int32(ASRSettings.vadMinSpeechMs)

        let code: Int32 = ASRSettings.language.withCString { language in
            ASRSettings.initialPrompt.withCString { prompt in
                vadPath.withCString { vad in
                    params.language = language
                    params.initial_prompt = prompt
                    params.vad_model_path = vad
                    return samples.withUnsafeBufferPointer { buf in
                        whisper_full(context, params, buf.baseAddress, Int32(buf.count))
                    }
                }
            }
        }
        if code != 0 { throw EngineError.transcribeFailed(code) }

        // Как asr.py:95 LocalFlow: `" ".join(s.text.strip() for s in segments).strip()`.
        var parts: [String] = []
        for i in 0..<whisper_full_n_segments(context) {
            if let segment = whisper_full_get_segment_text(context, i) {
                parts.append(String(cString: segment).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let context { whisper_free(context) }
    }
}
