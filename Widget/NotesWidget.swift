import AppIntents
import NotesKit
import SwiftUI
import WidgetKit

struct NotesEntry: TimelineEntry {
    let date: Date
    let notes: [Note]
    let theme: Theme
    var errorMessage: String?
}

struct NotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotesEntry {
        NotesEntry(date: .now, notes: [Note(body: "Groceries"), Note(body: "Study plan"), Note(body: "Ideas")], theme: Theme.saved())
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        completion(currentEntry())
    }

    /// The app reloads this timeline after each change. The refresh at midnight is only
    /// so that today's time badges turn into dates.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        let entry = currentEntry()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date)) ?? entry.date.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func currentEntry() -> NotesEntry {
        do {
            return NotesEntry(date: .now, notes: try NoteStore.shared().allNotes(), theme: Theme.saved())
        } catch {
            return NotesEntry(date: .now, notes: [], theme: Theme.saved(), errorMessage: error.localizedDescription)
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
        .description("Your pinned and most recent notes in a mini terminal.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct NotesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotesEntry

    var body: some View {
        TerminalWidgetContent(entry: entry, isSmall: family == .systemSmall)
    }
}

struct TerminalWidgetContent: View {
    let entry: NotesEntry
    let isSmall: Bool

    private var palette: TerminalPalette { entry.theme.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TerminalHeader(palette: palette)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(nsColor: palette.text))
    }

    @ViewBuilder
    private var content: some View {
        if let message = entry.errorMessage {
            PromptMessage(text: message, palette: palette)
        } else if entry.notes.isEmpty {
            PromptMessage(text: "no notes yet", palette: palette)
        } else {
            VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
                // allNotes() already puts pinned notes first, then the most recently edited.
                ForEach(entry.notes.prefix(3)) { note in
                    NoteLine(note: note, now: entry.date, stacked: isSmall, palette: palette)
                }
            }
        }
    }
}

private struct TerminalHeader: View {
    let palette: TerminalPalette

    var body: some View {
        ZStack {
            HStack(spacing: 5) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                Spacer()
            }
            .frame(height: 8)
            Text("~/notes")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(nsColor: palette.dim))
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(nsColor: palette.surface))
    }
}

private struct PromptMessage: View {
    let text: String
    let palette: TerminalPalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("❯").foregroundStyle(Color(nsColor: palette.accent))
            Text(text).foregroundStyle(Color(nsColor: palette.dim))
        }
    }
}

private struct NoteLine: View {
    let note: Note
    let now: Date
    /// The small widget is too narrow for the title and badge to share a row.
    let stacked: Bool
    let palette: TerminalPalette

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 2) {
                title
                HStack(spacing: 6) {
                    badge
                    Spacer(minLength: 0)
                    pinButton
                }
                .padding(.leading, 16)
            }
        } else {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 0)
                badge
                pinButton
            }
        }
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("❯")
                .foregroundStyle(Color(nsColor: note.isPinned ? palette.accent : palette.dim))
            Text(note.title)
                .lineLimit(1)
        }
    }

    private var badge: some View {
        Text(note.updatedAt.timestampBadge(relativeTo: now))
            .font(.system(size: 9, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Color(nsColor: palette.code))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color(nsColor: palette.surface), in: .capsule)
    }

    private var pinButton: some View {
        Button(intent: TogglePinIntent(noteID: note.id)) {
            Image(systemName: note.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: note.isPinned ? palette.accent : palette.dim))
        }
        .buttonStyle(.plain)
    }
}
