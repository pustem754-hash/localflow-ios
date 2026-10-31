import Foundation

/// Текст, распознанный, пока приложение в фоне: из фона в буфер не пишем — кладём при возврате.
public struct DeferredCopy: Equatable, Sendable {
    public private(set) var pending: String?

    public init() {}

    /// Текст, который надо положить в буфер сейчас; `nil` — отложен до `takeOnReturn()`.
    /// Новый отложенный текст заменяет прежний — в буфере всё равно лежал бы последний.
    public mutating func deliver(_ text: String, inForeground: Bool) -> String? {
        if inForeground {
            pending = nil
            return text
        }
        pending = text
        return nil
    }

    /// Приложение снова на экране: отложенный текст — один раз.
    public mutating func takeOnReturn() -> String? {
        defer { pending = nil }
        return pending
    }
}
