import Foundation

public struct Replacements: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var from: String
        public var to: String

        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    public static func parse(_ text: String) -> Replacements { Replacements() }

    public func serialize() -> String { "" }

    public func apply(_ text: String) -> String { text }

    public static let defaults = Replacements()
}
