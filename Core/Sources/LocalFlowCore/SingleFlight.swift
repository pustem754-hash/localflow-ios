import Foundation

/// Одна операция за раз: кто позвал, пока она идёт, дожидается её результата, а не уходит ни с чем.
/// Закончилась — следующий вызов запускает её заново.
public actor SingleFlight<Value: Sendable> {
    private var current: Task<Value, Never>?

    public init() {}

    public func run(_ operation: @escaping @Sendable () async -> Value) async -> Value {
        if let current { return await current.value }
        let task = Task { await operation() }
        current = task
        let value = await task.value
        current = nil
        return value
    }
}
