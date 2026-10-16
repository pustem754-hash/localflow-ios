import Foundation

/// Параметры распознавания — один в один с `transcribe_final` в LocalFlow asr.py.
public enum ASRSettings {
    public static let language = "ru", beamSize = 5, noContext = true   // condition_on_previous_text=False
    /// Дословно initial_prompt из LocalFlow asr.py.
    public static let initialPrompt = "Пример диктовки на русском языке: привет, "
        + "как дела? Всё хорошо, спасибо. Ещё раз — ясно, "
        + "чётко, с запятыми и точками."
    public static let vadThreshold: Float = 0.3, vadMinSilenceMs = 500
    /// D02: LocalFlow их не задаёт — значения faster-whisper 1.2.1 по умолчанию (`faster_whisper/vad.py:39-43`).
    public static let vadSpeechPadMs = 400, vadMinSpeechMs = 0
    public static let minSamples = 1600        // < 0,1 c — не распознаём, как asr.py
}
