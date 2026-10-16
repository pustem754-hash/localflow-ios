import Foundation

/// Модель Whisper из каталога. `bytes` — точный размер файла с Hugging Face,
/// по нему проверяется загрузка и опознаётся импортированный файл.
struct ModelInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let fileName: String
    let url: URL
    let bytes: Int64

    private static func hf(_ fileName: String) -> URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    /// Три модели для iPhone 11 (спецификация §6). Размеры — Hugging Face API.
    static let catalog: [ModelInfo] = [
        ModelInfo(id: "small", title: "Whisper small",
                  fileName: "ggml-small.bin", url: hf("ggml-small.bin"), bytes: 487_601_967),
        ModelInfo(id: "medium-q5_0", title: "Whisper medium (q5_0)",
                  fileName: "ggml-medium-q5_0.bin", url: hf("ggml-medium-q5_0.bin"), bytes: 539_212_467),
        ModelInfo(id: "large-v3-turbo-q5_0", title: "Whisper large-v3-turbo (q5_0)",
                  fileName: "ggml-large-v3-turbo-q5_0.bin", url: hf("ggml-large-v3-turbo-q5_0.bin"),
                  bytes: 574_041_195),
    ]

    /// Опознание файла по точному размеру в байтах. `nil` — такого размера в каталоге нет.
    static func identify(bytes: Int64, in catalog: [ModelInfo] = catalog) -> ModelInfo? {
        catalog.first { $0.bytes == bytes }
    }

    /// «487 601 967» — байты с разделителем разрядов.
    static func formatBytes(_ bytes: Int64) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: bytes)) ?? String(bytes)
    }

    /// Список имён и размеров для сообщений об ошибке импорта.
    static var catalogListText: String {
        catalog.map { "• \($0.fileName) — \(formatBytes($0.bytes)) байт" }.joined(separator: "\n")
    }
}
