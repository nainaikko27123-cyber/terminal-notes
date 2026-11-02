import Foundation

/// Commands typed at the prompt. Anything else is ordinary text for the page.
public enum PromptCommand: Equatable, Sendable {
    /// `:opacity 70`
    case setOpacity(Int)
    /// `:opacity` on its own, to see the current value.
    case showOpacity
    /// `:opacity` with something unusable after it.
    case invalidOpacity

    public static func parse(_ input: String) -> PromptCommand? {
        let parts = input.split(whereSeparator: \.isWhitespace)
        guard parts.first?.lowercased() == ":opacity" else { return nil }
        guard parts.count > 1 else { return .showOpacity }
        let number = parts[1].hasSuffix("%") ? parts[1].dropLast() : parts[1]
        guard parts.count == 2, let value = Int(number), WindowOpacity.range.contains(value) else { return .invalidOpacity }
        return .setOpacity(value)
    }
}

/// How solid the terminal window's background is, as a percentage. Remembered between launches.
public enum WindowOpacity {
    /// Below 20 there's almost nothing behind the text to keep it readable.
    public static let range = 20...100
    public static let `default` = 60
    private static let defaultsKey = "windowOpacity"

    public static func saved(in defaults: UserDefaults = Theme.sharedDefaults) -> Int {
        let value = defaults.integer(forKey: defaultsKey)
        return range.contains(value) ? value : `default`
    }

    public static func save(_ value: Int, to defaults: UserDefaults = Theme.sharedDefaults) {
        defaults.set(value, forKey: defaultsKey)
    }
}
