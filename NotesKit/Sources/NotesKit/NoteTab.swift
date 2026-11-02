import Foundation

/// The terminal's fixed tabs. Each one is a single Markdown note with a fixed ID,
/// so it stays attached to the same file between launches.
public enum NoteTab: Int, CaseIterable, Identifiable, Sendable {
    case notes = 1, todo, ideas

    public var id: UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", rawValue))!
    }

    public var name: String {
        switch self {
        case .notes: "notes"
        case .todo: "todo"
        case .ideas: "ideas"
        }
    }

    /// How the tab is written in the tab bar, status bar and menu.
    public var label: String {
        switch self {
        case .notes: "Notes"
        case .todo: "To do"
        case .ideas: "Ideas"
        }
    }

    public init?(noteID: UUID) {
        guard let tab = Self.allCases.first(where: { $0.id == noteID }) else { return nil }
        self = tab
    }

    private static let defaultsKey = "currentTab"

    public static func saved(in defaults: UserDefaults = Theme.sharedDefaults) -> NoteTab {
        NoteTab(rawValue: defaults.integer(forKey: defaultsKey)) ?? .notes
    }

    public func save(to defaults: UserDefaults = Theme.sharedDefaults) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
