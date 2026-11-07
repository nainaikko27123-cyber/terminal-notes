import AppIntents
import NotesKit
import SwiftUI
import WidgetKit

struct NotesEntry: TimelineEntry {
    let date: Date
    /// Enough for the largest size. Each size shows as many as it has room for.
    let todos: [TodoItem]
    let tasksLeft: Int
    /// Notes in the app's Notes tab sidebar.
    let notesCount: Int
    let theme: Theme
    var errorMessage: String?
}

struct NotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotesEntry {
        let sample = Note(body: "[ ] call mum\n[x] finish quiz\n[ ] buy milk #home")
        return NotesEntry(date: .now, todos: Todos.items(in: sample), tasksLeft: 2, notesCount: 3, theme: Theme.saved())
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        completion(currentEntry())
    }

    /// Nothing here changes by itself, so the app asks for a reload whenever notes change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    /// Reads every note, the same as the terminal, so the counts match its status bar.
    private func currentEntry() -> NotesEntry {
        do {
            let notes = try NoteStore.shared().allNotes()
            return NotesEntry(
                date: .now,
                todos: Todos.recent(from: notes, limit: 5),
                tasksLeft: notes.reduce(0) { $0 + Todos.openCount(in: $1.body) },
                notesCount: notes.count { !NoteTab.pageIDs.contains($0.id) },
                theme: Theme.saved()
            )
        } catch {
            return NotesEntry(date: .now, todos: [], tasksLeft: 0, notesCount: 0, theme: Theme.saved(), errorMessage: error.localizedDescription)
        }
    }
}

struct NotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NotesWidget", provider: NotesProvider()) { entry in
            NotesWidgetView(entry: entry)
                .containerBackground(Color(nsColor: entry.theme.palette.background), for: .widget)
        }
        .configurationDisplayName("Notes Terminal")
        .description("Your latest to-dos in a small terminal.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct NotesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotesEntry

    var body: some View {
        // The small size is short on room, so it shows fewer to-dos.
        TerminalWidgetContent(entry: entry, maxTodos: family == .systemSmall ? 3 : 5)
    }
}

/// A small terminal: the prompt on top, the latest to-dos, then how many are left.
struct TerminalWidgetContent: View {
    let entry: NotesEntry
    let maxTodos: Int

    private var palette: TerminalPalette { entry.theme.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "shinyu@notes ~ $")
                .foregroundStyle(Color(nsColor: palette.done))
                .lineLimit(1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: tasksText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(nsColor: entry.tasksLeft == 0 ? palette.done : palette.date))
        }
        .padding(12)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(Color(nsColor: palette.text))
    }

    private var tasksText: String {
        let tasks = switch entry.tasksLeft {
        case 0: "no tasks left"
        case 1: "1 task left"
        default: "\(entry.tasksLeft) tasks left"
        }
        return "\(tasks) · \(entry.notesCount == 1 ? "1 note" : "\(entry.notesCount) notes")"
    }

    @ViewBuilder
    private var content: some View {
        if let message = entry.errorMessage {
            Text(message).foregroundStyle(Color(nsColor: palette.dim))
        } else if entry.todos.isEmpty {
            Text(verbatim: "no to-dos yet").foregroundStyle(Color(nsColor: palette.dim))
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(entry.todos.prefix(maxTodos)) { item in
                    TodoRow(item: item, palette: palette)
                }
            }
        }
    }
}

/// One to-do, in the same colors as the app. Its box can be clicked right in the widget.
private struct TodoRow: View {
    let item: TodoItem
    let palette: TerminalPalette

    var body: some View {
        let styled = NSMutableAttributedString(string: item.line)
        let _ = MarkdownStyler.apply(palette, to: styled, size: 11)

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Button(intent: ToggleTodoIntent(item: item)) {
                Text(part(of: styled, from: 0, to: 3))
            }
            .buttonStyle(.plain)
            Text(part(of: styled, from: 3, to: styled.length))
        }
        .lineLimit(1)
    }

    /// Copies the colors and fonts over by hand, so SwiftUI is sure to draw them.
    private func part(of styled: NSAttributedString, from start: Int, to end: Int) -> AttributedString {
        var result = AttributedString()
        styled.enumerateAttributes(in: NSRange(location: start, length: end - start)) { attributes, run, _ in
            var piece = AttributedString(styled.attributedSubstring(from: run).string)
            if let color = attributes[.foregroundColor] as? NSColor { piece.foregroundColor = Color(nsColor: color) }
            if let font = attributes[.font] as? NSFont { piece.font = Font(font) }
            result += piece
        }
        return result
    }
}
