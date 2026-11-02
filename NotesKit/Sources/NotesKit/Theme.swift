import AppKit

public struct TerminalPalette: Equatable, Sendable {
    public let background: NSColor
    public let surface: NSColor
    public let text: NSColor
    public let dim: NSColor
    /// Prompts, list markers and the cursor.
    public let accent: NSColor
    public let header: NSColor
    public let tag: NSColor
    public let date: NSColor
    public let link: NSColor
    public let code: NSColor
    public let done: NSColor

    fileprivate init(background: Int, surface: Int, text: Int, dim: Int, accent: Int, header: Int, tag: Int, date: Int, link: Int, code: Int, done: Int) {
        func color(_ hex: Int) -> NSColor {
            NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
        self.background = color(background)
        self.surface = color(surface)
        self.text = color(text)
        self.dim = color(dim)
        self.accent = color(accent)
        self.header = color(header)
        self.tag = color(tag)
        self.date = color(date)
        self.link = color(link)
        self.code = color(code)
        self.done = color(done)
    }
}

/// The theme is kept in the App Group's defaults so the widget matches the app.
public enum Theme: String, CaseIterable, Identifiable, Sendable {
    case tokyoNight, matrixGreen, nordBlue, draculaDark

    public static let `default` = Theme.tokyoNight
    private static let defaultsKey = "theme"

    public var id: Self { self }

    public var name: String {
        switch self {
        case .tokyoNight: "Tokyo Night"
        case .matrixGreen: "Matrix Green"
        case .nordBlue: "Nord Blue"
        case .draculaDark: "Dracula Dark"
        }
    }

    public var palette: TerminalPalette {
        switch self {
        case .tokyoNight:
            TerminalPalette(background: 0x1A1B26, surface: 0x24283B, text: 0xC0CAF5, dim: 0x737AA2, accent: 0x7AA2F7, header: 0xBB9AF7, tag: 0x7DCFFF, date: 0xE0AF68, link: 0x2AC3DE, code: 0xFF9E64, done: 0x9ECE6A)
        case .matrixGreen:
            TerminalPalette(background: 0x1E1E1E, surface: 0x2D2D2D, text: 0x9CFFB0, dim: 0x4F8A5F, accent: 0x00FF41, header: 0x00FF41, tag: 0x5CE1E6, date: 0xD7FF7A, link: 0x5CE1E6, code: 0xD7FF7A, done: 0x00FF41)
        case .nordBlue:
            TerminalPalette(background: 0x2E3440, surface: 0x3B4252, text: 0xD8DEE9, dim: 0x7B88A1, accent: 0x88C0D0, header: 0xA3BE8C, tag: 0x8FBCBB, date: 0xE5B9A5, link: 0x81A1C1, code: 0xEBCB8B, done: 0xA3BE8C)
        case .draculaDark:
            TerminalPalette(background: 0x282A36, surface: 0x44475A, text: 0xF8F8F2, dim: 0x7A88BC, accent: 0xFF79C6, header: 0xBD93F9, tag: 0x8BE9FD, date: 0xF1FA8C, link: 0x8BE9FD, code: 0xFFB86C, done: 0x50FA7B)
        }
    }

    /// The next theme, wrapping around to the first.
    public var next: Theme {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    public static func saved(in defaults: UserDefaults = sharedDefaults) -> Theme {
        defaults.string(forKey: defaultsKey).flatMap(Theme.init(rawValue:)) ?? .default
    }

    public func save(to defaults: UserDefaults = Self.sharedDefaults) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: NoteStore.appGroupID) ?? .standard
    }
}
