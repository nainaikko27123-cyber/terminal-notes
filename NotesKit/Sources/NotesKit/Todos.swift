import Foundation

/// To-dos are plain lines in a note: `[ ] open` and `[x] done`.
public enum Todos {
    /// How many to-dos are still open. Boxes inside code don't count.
    public static func openCount(in text: String) -> Int {
        MarkdownSpans.find(in: text).count { $0.style == .todoOpenBox }
    }

    /// The range of the checkbox at this character position, if there is one.
    public static func checkboxRange(at index: Int, in text: String) -> NSRange? {
        MarkdownSpans.find(in: text).first { span in
            (span.style == .todoOpenBox || span.style == .todoDoneBox) && NSLocationInRange(index, span.range)
        }?.range
    }

    /// What a checkbox should become when clicked.
    public static func toggled(_ box: String) -> String {
        box == "[ ]" ? "[x]" : "[ ]"
    }

    public static func isTodo(_ line: String) -> Bool {
        MarkdownSpans.find(in: line).contains { $0.style == .todoOpenBox || $0.style == .todoDoneBox }
    }
}

/// One to-do line, ready to show in the widget.
public struct TodoItem: Identifiable, Hashable, Sendable {
    public let noteID: UUID
    /// The whole line, from its checkbox to the end.
    public let line: String
    /// Where the checkbox is in the whole note, for flipping it.
    public let location: Int
    public let isDone: Bool

    public var id: String { "\(noteID.uuidString)-\(location)" }
}

public extension Todos {
    /// A note's to-dos with the newest first. New lines go at the bottom of a page, so that's bottom-up.
    static func items(in note: Note) -> [TodoItem] {
        let body = note.body as NSString
        return MarkdownSpans.find(in: note.body)
            .filter { $0.style == .todoOpenBox || $0.style == .todoDoneBox }
            .sorted { $0.range.location > $1.range.location }
            .map { span in
                var contentsEnd = 0
                body.getLineStart(nil, end: nil, contentsEnd: &contentsEnd, for: span.range)
                return TodoItem(
                    noteID: note.id,
                    line: body.substring(with: NSRange(location: span.range.location, length: contentsEnd - span.range.location)),
                    location: span.range.location,
                    isDone: span.style == .todoDoneBox
                )
            }
    }

    /// The newest to-dos across these notes: the most recently edited note first.
    static func recent(from notes: [Note], limit: Int) -> [TodoItem] {
        Array(notes.sorted { $0.updatedAt > $1.updatedAt }.flatMap(items(in:)).prefix(limit))
    }
}

public extension NoteTab {
    /// Turns text typed at the prompt into a line for this tab's page.
    func line(from input: String) -> String {
        self == .todo && !Todos.isTodo(input) ? "[ ] \(input)" : input
    }
}
