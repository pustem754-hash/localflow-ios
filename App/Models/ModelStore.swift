import CryptoKit
import Foundation
import UIKit

enum ModelStoreError: LocalizedError {
    case noInternet(ModelInfo)
    case downloadFailed(ModelInfo, String)
    case sizeMismatch(ModelInfo, got: Int64)
    case hashMismatch(ModelInfo)
    case notInCatalog(name: String, bytes: Int64)
    case fileFailed(String)

    /// G04: имя файла и оба способа импорта.
    private static func offlineHint(_ model: ModelInfo) -> String {
        "Скачай \(model.fileName) на ноутбуке по ссылке \(model.url.absoluteString) и положи в «Файлы» "
            + "(здесь кнопка «Импорт из Файлов») или через iTunes → Общие файлы → LocalFlow. "
            + "Инструкция — в INSTALL-ru.md, раздел «Модель без интернета на телефоне»."
    }

    var errorDescription: String? {
        switch self {
        case .noInternet(let m):
            return "Нет интернета — нужен один раз, чтобы скачать модель.\n\n" + Self.offlineHint(m)
        case .downloadFailed(let m, let reason):
            return "Не удалось скачать \(m.fileName): \(reason). Недокачанный файл удалён — можно повторить.\n\n"
                + Self.offlineHint(m)
        case .sizeMismatch(let m, let got):
            return "\(m.fileName) скачался не целиком или не тот: \(ModelInfo.formatBytes(got)) байт вместо "
                + "\(ModelInfo.formatBytes(m.bytes)). Файл удалён — можно повторить.\n\n" + Self.offlineHint(m)
        case .hashMismatch(let m):
            return "\(m.fileName) не прошёл проверку: содержимое не совпало с оригиналом на Hugging Face "
                + "(sha256). Файл не принят — скачай его заново.\n\n" + Self.offlineHint(m)
        case .notInCatalog(let name, let bytes):
            return "Это не модель из списка: нужен один из файлов\n\(ModelInfo.catalogListText)\n\n"
                + "У файла «\(name)» — \(ModelInfo.formatBytes(bytes)) байт."
        case .fileFailed(let reason):
            return "Не получилось сохранить файл модели: \(reason)"
        }
    }
}

/// Состояние движка для экрана.
enum EngineState: Equatable {
    case empty                 // модель не выбрана / не загружена
    case loading(String)       // название модели
    case loaded(ModelInfo.ID)
    case failed(String)        // «Модель не загрузилась: …»
}

/// `.bin` в корне Documents (общий доступ iTunes), размер которого не совпал ни с одной моделью.
struct UnrecognizedFile: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let bytes: Int64
}

/// Каталог моделей, загрузка, импорт, удаление, выбор. Файлы — `Application Support/Models/`.
@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()

    let catalog = ModelInfo.catalog
    @Published private(set) var downloaded: Set<ModelInfo.ID> = []
    @Published private(set) var selected: ModelInfo.ID?
    @Published private(set) var engineState: EngineState = .empty
    @Published private(set) var unrecognizedSharedFiles: [UnrecognizedFile] = []
    /// Файл из общих файлов iTunes не прошёл проверку sha256 — текст для экрана «Модели».
    @Published var sharedFileError: String?

    private let fm = FileManager.default
    private let selectedKey = "selectedModelID"
    private var activeObserver: NSObjectProtocol?
    private var isAdopting = false

    let modelsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Models", isDirectory: true)
    }()

    private var documentsDirectory: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        try? fm.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        var dir = modelsDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true   // ~0,5 ГБ на модель — не в резервную копию iCloud
        try? dir.setResourceValues(values)

        refreshDownloaded()
        // При каждом возвращении в приложение — снова проверить общие файлы iTunes.
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.adoptSharedFiles() }
        }
        // Сначала общие файлы (хэш считается вне главного потока), потом выбранная модель — в движок.
        Task {
            await adoptSharedFiles()
            if selected == nil, let id = UserDefaults.standard.string(forKey: selectedKey), downloaded.contains(id) {
                selected = id
                await loadSelected()
            }
        }
    }

    func fileURL(for model: ModelInfo) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    func isDownloaded(_ model: ModelInfo) -> Bool {
        downloaded.contains(model.id)
    }

    private func fileSize(_ url: URL) -> Int64? {
        (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    private func refreshDownloaded() {
        downloaded = Set(catalog.filter { fileSize(fileURL(for: $0)) == $0.bytes }.map(\.id))
    }

    /// Переносит проверенный файл на место модели: прежний файл с тем же именем заменяется.
    private func place(_ source: URL, as model: ModelInfo) throws {
        let dest = fileURL(for: model)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.moveItem(at: source, to: dest)
        } catch {
            throw ModelStoreError.fileFailed(error.localizedDescription)
        }
        refreshDownloaded()
    }

    /// sha256 файла против каталога; считается вне главного потока. Не совпало — файл удаляется.
    private func verify(_ file: URL, as model: ModelInfo) async throws {
        let hash = try? await Task.detached(priority: .userInitiated) { try ModelStore.sha256Hex(of: file) }.value
        guard hash == model.sha256 else {
            try? fm.removeItem(at: file)
            throw ModelStoreError.hashMismatch(model)
        }
    }

    /// Читает файл кусками по 4 МБ — модель целиком в память не попадает.
    nonisolated private static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try autoreleasepool { try handle.read(upToCount: 4 << 20) }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Скачивание — единственный сетевой вызов приложения (R42, R43)

    func download(_ model: ModelInfo, progress: @escaping @MainActor (Double) -> Void) async throws {
        let partial = modelsDirectory.appendingPathComponent(model.fileName + ".download")
        try? fm.removeItem(at: partial)
        let delegate = DownloadDelegate(expectedBytes: model.bytes, destination: partial, progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                delegate.continuation = cont
                session.downloadTask(with: model.url).resume()
            }
        } catch {
            try? fm.removeItem(at: partial)
            throw Self.describe(error, model: model)
        }

        let got = fileSize(partial) ?? 0
        guard got == model.bytes else {
            try? fm.removeItem(at: partial)
            throw ModelStoreError.sizeMismatch(model, got: got)
        }
        try await verify(partial, as: model)
        try place(partial, as: model)
    }

    private static func describe(_ error: Error, model: ModelInfo) -> Error {
        if let e = error as? ModelStoreError { return e }
        guard let urlError = error as? URLError else {
            return ModelStoreError.downloadFailed(model, error.localizedDescription)
        }
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return ModelStoreError.noInternet(model)
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return ModelStoreError.downloadFailed(model, "Hugging Face не отвечает")
        case .networkConnectionLost:
            return ModelStoreError.downloadFailed(model, "загрузка оборвалась")
        default:
            return ModelStoreError.downloadFailed(model, urlError.localizedDescription)
        }
    }

    // MARK: Импорт

    /// Файл из «Файлов»: опознаётся по точному размеру, копируется к себе и проверяется по sha256.
    /// Хэш не совпал — удаляется копия, оригинал в «Файлах» не трогается.
    @discardableResult
    func importFile(at url: URL) async throws -> ModelInfo {
        let copy = modelsDirectory.appendingPathComponent(UUID().uuidString + ".import")
        let model = try copyForImport(url, to: copy)
        try await verify(copy, as: model)
        try place(copy, as: model)
        return model
    }

    private func copyForImport(_ url: URL, to copy: URL) throws -> ModelInfo {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bytes = fileSize(url) else {
            throw ModelStoreError.fileFailed("не удалось прочитать \(url.lastPathComponent)")
        }
        guard let model = ModelInfo.identify(bytes: bytes, in: catalog) else {
            throw ModelStoreError.notInCatalog(name: url.lastPathComponent, bytes: bytes)
        }
        do {
            try fm.copyItem(at: url, to: copy)
        } catch {
            try? fm.removeItem(at: copy)
            throw ModelStoreError.fileFailed(error.localizedDescription)
        }
        return model
    }

    /// `.bin` в корне Documents (туда кладёт общий доступ iTunes): опознанные по размеру проверяются
    /// по sha256 и переносятся в модели; не прошедшие проверку удаляются, причина — в `sharedFileError`;
    /// неопознанные остаются на месте и попадают в `unrecognizedSharedFiles`.
    @discardableResult
    func adoptSharedFiles() async -> [ModelInfo] {
        guard !isAdopting else { return [] }
        isAdopting = true
        defer { isAdopting = false }
        let files = (try? fm.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey]))
            ?? []
        var adopted: [ModelInfo] = []
        var unknown: [UnrecognizedFile] = []
        for file in files where file.pathExtension.lowercased() == "bin" {
            guard let bytes = fileSize(file) else { continue }
            guard let model = ModelInfo.identify(bytes: bytes, in: catalog) else {
                unknown.append(UnrecognizedFile(name: file.lastPathComponent, bytes: bytes))
                continue
            }
            do {
                try await verify(file, as: model)
                try place(file, as: model)
                adopted.append(model)
            } catch ModelStoreError.hashMismatch(let m) {
                sharedFileError = ModelStoreError.hashMismatch(m).localizedDescription
            } catch {
                unknown.append(UnrecognizedFile(name: file.lastPathComponent, bytes: bytes))
            }
        }
        unrecognizedSharedFiles = unknown.sorted { $0.name < $1.name }
        return adopted
    }

    // MARK: Удаление и выбор

    func delete(_ model: ModelInfo) async throws {
        if selected == model.id {
            selected = nil
            UserDefaults.standard.removeObject(forKey: selectedKey)
            engineState = .empty
            await WhisperEngine.shared.unload()
        }
        let url = fileURL(for: model)
        if fm.fileExists(atPath: url.path) {
            do { try fm.removeItem(at: url) } catch { throw ModelStoreError.fileFailed(error.localizedDescription) }
        }
        refreshDownloaded()
    }

    /// Выбор модели: запоминается и загружается в движок (прежняя выгружается).
    func select(_ model: ModelInfo) async {
        guard isDownloaded(model) else { return }
        selected = model.id
        UserDefaults.standard.set(model.id, forKey: selectedKey)
        await loadSelected()
    }

    /// Загружает выбранную модель в `WhisperEngine.shared`. Ошибка — в `engineState`, без падения.
    /// Модель не выбрана — движок выгружается (так и после «Замера»).
    /// `.loaded` ставится, только если в движке правда эта модель (`WhisperEngine.loadedModelID`).
    func loadSelected() async {
        guard let id = selected, let model = catalog.first(where: { $0.id == id }), isDownloaded(model) else {
            engineState = .empty
            await WhisperEngine.shared.unload()
            return
        }
        guard let vad = WhisperEngine.bundledVAD else {
            engineState = .failed("Модель не загрузилась: в приложении нет VAD-модели ggml-silero-v6.2.0.bin")
            return
        }
        engineState = .loading(model.title)
        do {
            try await WhisperEngine.shared.load(model: fileURL(for: model), vad: vad, id: id)
            // Другая модель в движке — значит, следом идёт ещё одна загрузка, она и поставит состояние.
            let inEngine = await WhisperEngine.shared.loadedModelID
            if selected == id, inEngine == id { engineState = .loaded(id) }
        } catch {
            if selected == id { engineState = .failed("Модель не загрузилась: \(error.localizedDescription)") }
        }
    }
}

/// Делегат одной загрузки: прогресс и перенос готового файла из временного места.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var continuation: CheckedContinuation<Void, Error>?
    private let expectedBytes: Int64
    private let destination: URL
    private let progress: @MainActor (Double) -> Void
    private var lastReported = -1.0
    private var finishError: Error?

    init(expectedBytes: Int64, destination: URL, progress: @escaping @MainActor (Double) -> Void) {
        self.expectedBytes = expectedBytes
        self.destination = destination
        self.progress = progress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedBytes
        let fraction = min(1, Double(totalBytesWritten) / Double(total))
        guard fraction - lastReported >= 0.005 || fraction >= 1 else { return }
        lastReported = fraction
        let progress = self.progress
        Task { @MainActor in progress(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Временный файл живёт только до выхода из этого метода — переносим сразу.
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finishError = URLError(.badServerResponse,
                                   userInfo: [NSLocalizedDescriptionKey: "сервер ответил \(http.statusCode)"])
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            finishError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result = error ?? finishError
        if let result { continuation?.resume(throwing: result) } else { continuation?.resume() }
        continuation = nil
    }
}
