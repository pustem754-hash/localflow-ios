import Foundation

/// Числа для русского текста: десятичная запятая. Единственное место такого форматирования.
public enum DecimalComma {
    /// `3.8` → «3,8»; `digits` — знаков после запятой (по умолчанию один).
    public static func string(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", value).replacingOccurrences(of: ".", with: ",")
    }
}
