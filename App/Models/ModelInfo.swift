import Foundation

/// Модель Whisper из каталога. `bytes` — точный размер файла с Hugging Face,
/// по нему опознаётся импортированный файл; `sha256` — проверка содержимого после загрузки и импорта.
struct ModelInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let fileName: String
    let url: URL
    let bytes: Int64
    let sha256: String

    /// Закреплённый коммит репозитория ggerganov/whisper.cpp на Hugging Face — файл по ссылке не меняется.
    private static let hfCommit = "5359861c739e955e79d9a303bcbc70fb988958b1"

    private static func hf(_ fileName: String) -> URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/\(hfCommit)/\(fileName)")!
    }

    /// Три модели для iPhone 11 (спецификация §6). Размеры и sha256 (lfs oid) — Hugging Face API.
    static let catalog: [ModelInfo] = [
        ModelInfo(id: "small", title: "Whisper small",
                  fileName: "ggml-small.bin", url: hf("ggml-small.bin"), bytes: 487_601_967,
                  sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b"),
        ModelInfo(id: "medium-q5_0", title: "Whisper medium (q5_0)",
                  fileName: "ggml-medium-q5_0.bin", url: hf("ggml-medium-q5_0.bin"), bytes: 539_212_467,
                  sha256: "19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f"),
        ModelInfo(id: "large-v3-turbo-q5_0", title: "Whisper large-v3-turbo (q5_0)",
                  fileName: "ggml-large-v3-turbo-q5_0.bin", url: hf("ggml-large-v3-turbo-q5_0.bin"),
                  bytes: 574_041_195,
                  sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2"),
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
