import Foundation

/// Reads and writes a note as Markdown with a small front matter block:
///
///     ---
///     createdAt: 2026-11-02T10:00:00.000Z
///     updatedAt: 2026-11-02T10:05:00.000Z
///     pinned: false
///     ---
///     # My note
///
/// The note's ID is its file name. A `.md` file with no front matter still loads,
/// so notes can be dropped in or edited by other Markdown apps.
enum MarkdownNoteFile {
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let opening = "---\n"
    private static let closing = "\n---\n"

    static func encode(_ note: Note) -> String {
        """
        \(opening)createdAt: \(note.createdAt.formatted(dateStyle))
        updatedAt: \(note.updatedAt.formatted(dateStyle))
        pinned: \(note.isPinned)\(closing)\(note.body)
        """
    }

    /// `fallbackDate` is used for any date the file doesn't have.
    static func decode(_ text: String, id: UUID, fallbackDate: Date) -> Note {
        guard text.hasPrefix(opening),
              let end = text.range(of: closing, range: text.index(text.startIndex, offsetBy: opening.count - 1)..<text.endIndex)
        else {
            return Note(id: id, body: text, createdAt: fallbackDate, updatedAt: fallbackDate)
        }

        var fields: [Substring: Substring] = [:]
        for line in text[text.index(text.startIndex, offsetBy: opening.count)..<end.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            fields[line[..<colon]] = line[line.index(after: colon)...].drop(while: \.isWhitespace)
        }

        func date(_ key: Substring) -> Date {
            fields[key].flatMap { try? dateStyle.parse(String($0)) } ?? fallbackDate
        }

        return Note(
            id: id,
            body: String(text[end.upperBound...]),
            createdAt: date("createdAt"),
            updatedAt: date("updatedAt"),
            isPinned: fields["pinned"] == "true"
        )
    }
}
