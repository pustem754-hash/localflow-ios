import Foundation
import LocalFlowCore

enum DictationState: Equatable {
    case noModel                 // модель не загружена — ведёт на экран моделей
    case micDenied               // доступа к микрофону нет — кнопка «Открыть настройки»
    case idle
    case recording(since: Date)
    case transcribing
    case copied(text: String)    // текст в буфере + отметка «Скопировано» + вибро
    case rejected(RejectReason)  // причина и что повторить
    case failed(String)          // ошибка движка/памяти, прерванная запись
}
