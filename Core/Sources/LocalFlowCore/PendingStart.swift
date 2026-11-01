import Foundation

/// «Начать диктовку» из «Команд»: `perform()` только ставит просьбу и сразу возвращается.
/// Запись начинается, когда приложение на экране, модели проверены и модель не грузится.
public struct PendingStart: Equatable, Sendable {
    public private(set) var isPending = false
    /// Проверка моделей для этой просьбы закончилась — без неё модель после холодного запуска
    /// ещё не выбрана, и запись отказала бы «нет модели».
    public private(set) var modelsChecked = false

    public init() {}

    /// Новая просьба: модели проверяются заново — файл мог только что прийти через iTunes.
    public mutating func request() {
        isPending = true
        modelsChecked = false
    }

    public mutating func modelsCheckFinished() {
        modelsChecked = true
    }

    /// Нажатие кнопки снимает ожидающую просьбу.
    public mutating func cancel() {
        isPending = false
    }

    /// `true` — начинать запись сейчас, один раз на просьбу; иначе просьба ждёт следующего события.
    public mutating func take(sceneActive: Bool, modelLoading: Bool) -> Bool {
        guard isPending, modelsChecked, sceneActive, !modelLoading else { return false }
        isPending = false
        return true
    }
}
