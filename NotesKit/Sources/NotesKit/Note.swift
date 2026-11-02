import Foundation

public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var body: String
    public let createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    /// The first non-empty line, without Markdown heading markers.
    public var title: String {
        let line = body.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces)) }
            .first { !$0.isEmpty }
        return line ?? "New Note"
    }
}
