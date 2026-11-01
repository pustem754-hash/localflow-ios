import Foundation

/// Запуск записи из «Команд» через Siri: микрофон ещё у Siri, вход недоступен. Запуск повторяется
/// каждые 0,3 c (раньше — когда кончилось прерывание аудиосессии), но не дольше 3 c; потом — `busyMessage`.
public enum MicRetry {
    public static let interval: TimeInterval = 0.3
    public static let limit: TimeInterval = 3
    public static let busyMessage = "Микрофон занят — нажмите кнопку"

    /// `now` — монотонные часы в секундах; `attempt` — `true`, если запись пошла;
    /// `wait(s)` — пауза не дольше `s` секунд, может кончиться раньше.
    /// Возвращает `true`, если удалась хоть одна попытка за `limit` секунд от первой.
    public static func run(now: @Sendable () -> TimeInterval,
                           attempt: @Sendable () async -> Bool,
                           wait: @Sendable (TimeInterval) async -> Void) async -> Bool {
        let start = now()
        while true {
            if await attempt() { return true }
            let left = limit - (now() - start)
            // Остаток меньше миллисекунды — погрешность сложения 0,3, не повод для ещё одной паузы.
            guard left > 0.001 else { return false }
            await wait(min(interval, left))
            // Пауза затянулась (приложение было приостановлено) — просьба устарела, запись сама не начнётся.
            guard now() - start < limit + interval else { return false }
        }
    }
}
