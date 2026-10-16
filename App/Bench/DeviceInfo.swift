import Foundation

/// Модель устройства из `utsname.machine`, например `iPhone12,1` — для заголовка таблицы замера.
enum DeviceInfo {
    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result += String(UnicodeScalar(UInt8(value)))
        }
    }
}
