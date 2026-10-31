import UIKit
import UniformTypeIdentifiers

/// Единственное место записи текста в буфер обмена. Только на этом устройстве (`localOnly`):
/// текст не уходит через Universal Clipboard на другие устройства Apple.
enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true])
    }
}
