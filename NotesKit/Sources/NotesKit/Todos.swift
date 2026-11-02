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

public extension NoteTab {
    /// Turns text typed at the prompt into a line for this tab's page.
    func line(from input: String) -> String {
        self == .todo && !Todos.isTodo(input) ? "[ ] \(input)" : input
    }
}
