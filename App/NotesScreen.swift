import AppKit
import NotesKit
import SwiftUI

/// The Notes tab: a list of notes on the left, the selected note on the right,
/// and the prompt and status bar along the bottom.
struct NotesScreen: View {
    @Environment(NotesModel.self) private var model
    let palette: TerminalPalette
    let barOpacity: Double

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                NotesSidebar(palette: palette, backgroundOpacity: barOpacity)
                Rectangle()
                    .fill(Color(nsColor: palette.dim).opacity(0.35))
                    .frame(width: 1)
                writingArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            PromptLine(
                palette: palette,
                focusRequestCount: model.promptFocusRequestCount,
                focusOnAppear: model.editorFocusNoteID == nil,
                onMove: { model.moveSelection(by: $0) }
            ) { input in
                model.submitNotesPrompt(input)
            }
            StatusBar(
                tab: .notes,
                tasksLeft: model.openTaskCount(),
                notesCount: model.sidebarNotes.count,
                message: model.statusMessage,
                palette: palette,
                backgroundOpacity: barOpacity
            )
        }
    }
}

extension NotesScreen {
    /// The selected note, saved as you type. With no note, the welcome logo.
    @ViewBuilder
    fileprivate var writingArea: some View {
        if let note = model.selectedNote {
            AutosavingNoteEditor(note: note) { text in
                TerminalTextEditor(text: text, palette: palette, autofocus: model.editorFocusNoteID == note.id)
                    .padding(.top, 6)
            }
            .id(note.id)
        } else {
            WelcomeScreen(message: "no note selected", tip: "press ⌘N or type :new <title>", palette: palette)
        }
    }
}

/// The list of notes. Click one, or use the up and down arrow keys: clicking hands the keyboard
/// to the prompt, and the arrows move through the list whenever the prompt is empty.
struct NotesSidebar: View {
    @Environment(NotesModel.self) private var model
    /// The note whose title is being typed over in the list.
    @State private var renamingID: Note.ID?
    let palette: TerminalPalette
    /// The same strength as the tab and status bars, so the list sits a shade lighter than the page.
    let backgroundOpacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewNoteButton(palette: palette)
            if let query = model.searchQuery {
                Text(verbatim: "search: \(query)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(nsColor: palette.tag))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }
            if model.filteredNotes.isEmpty {
                Text(verbatim: model.searchQuery == nil ? "no notes yet,\npress ⌘N" : "no matches")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(nsColor: palette.dim))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                noteList
            }
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: palette.surface).opacity(backgroundOpacity))
    }

    private var noteList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.filteredNotes) { note in
                        if renamingID == note.id {
                            RenameField(note: note, palette: palette) { newTitle in
                                if let newTitle { model.rename(note.id, to: newTitle) }
                                renamingID = nil
                            }
                            .id(note.id)
                        } else {
                            NoteRow(note: note, isSelected: note.id == model.selection, palette: palette)
                                .id(note.id)
                                .onTapGesture {
                                    model.select(note.id)
                                    // The Mac counts the clicks, so a double-click renames without
                                    // slowing down a single click. The name box needs the keyboard,
                                    // so a double-click doesn't hand it to the list.
                                    if NSApp.currentEvent?.clickCount == 2 {
                                        renamingID = note.id
                                    } else {
                                        model.focusPrompt()
                                    }
                                }
                                .contextMenu {
                                    Button("Rename") {
                                        model.select(note.id)
                                        renamingID = note.id
                                    }
                                }
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) {
                if let id = model.selection { proxy.scrollTo(id) }
            }
        }
    }
}

/// "+ new note" at the top of the list. Does the same as ⌘N.
private struct NewNoteButton: View {
    @Environment(NotesModel.self) private var model
    @State private var isHovered = false
    let palette: TerminalPalette

    var body: some View {
        Button {
            model.newNote(title: nil)
        } label: {
            HStack {
                Text(verbatim: "+ new note")
                Spacer()
                Text(verbatim: "⌘N")
                    .foregroundStyle(Color(nsColor: palette.dim))
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color(nsColor: palette.done))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: palette.done).opacity(isHovered ? 0.15 : 0), in: .rect(cornerRadius: 3))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("New note (⌘N)")
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }
}

/// Types over a note's title in the list. Enter saves, Esc or clicking away cancels.
/// A blank title goes back to using the note's first line.
private struct RenameField: View {
    let note: Note
    let palette: TerminalPalette
    /// Called once with the new title, or nil to cancel.
    let onFinish: (String?) -> Void
    @State private var title: String
    @State private var isFinished = false
    /// Clicking away only cancels once the box has actually had the keyboard.
    @State private var hasHadFocus = false
    @FocusState private var isFocused: Bool

    init(note: Note, palette: TerminalPalette, onFinish: @escaping (String?) -> Void) {
        self.note = note
        self.palette = palette
        self.onFinish = onFinish
        _title = State(initialValue: note.customTitle ?? note.title)
    }

    var body: some View {
        TextField("title", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(nsColor: palette.text))
            .focused($isFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: palette.accent), lineWidth: 1))
            .onSubmit { finish(title) }
            .onExitCommand { finish(nil) }
            .onChange(of: isFocused) {
                if isFocused {
                    hasHadFocus = true
                } else if hasHadFocus {
                    finish(nil)
                }
            }
            // Just after the click that opened it has finished, so the click can't take the keyboard back.
            .onAppear { DispatchQueue.main.async { isFocused = true } }
    }

    private func finish(_ result: String?) {
        guard !isFinished else { return }
        isFinished = true
        onFinish(result)
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let palette: TerminalPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: note.title)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundStyle(Color(nsColor: isSelected ? palette.background : palette.text))
                .lineLimit(1)
            Text(verbatim: note.updatedAt.timestampBadge(relativeTo: .now))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(nsColor: isSelected ? palette.background : palette.dim).opacity(isSelected ? 0.75 : 1))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: isSelected ? palette.accent : .clear), in: .rect(cornerRadius: 3))
        .contentShape(.rect)
    }
}
