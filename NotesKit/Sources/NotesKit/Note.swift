import Foundation

public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var body: String
    public let createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    /// A title set with `:new` or `:rename`. Without one, the first line is the title.
    public var customTitle: String?

    public init(
        id: UUID = UUID(),
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        customTitle: String? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.customTitle = customTitle
    }

    /// The custom title if there is one, otherwise the first non-empty line without heading markers.
    public var title: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        let line = body.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces)) }
            .first { !$0.isEmpty }
        return line ?? "New Note"
    }
}
