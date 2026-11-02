import NotesKit
import SwiftUI

/// A terminal-styled window for the note selected in the main window.
struct TerminalView: View {
    @Environment(NotesModel.self) private var model

    private var palette: TerminalPalette { model.theme.palette }

    var body: some View {
        Group {
            if let note = model.notes.first(where: { $0.id == model.selection }) {
                AutosavingNoteEditor(note: note) { text in
                    TerminalTextEditor(text: text, palette: palette)
                }
                .id(note.id)
            } else {
                Text("❯ No notes yet. Press ⌘N to start one.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(nsColor: palette.dim))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.top, 8)
        .background(Color(nsColor: palette.background))
        .preferredColorScheme(.dark)
        .onAppear {
            if model.selection == nil { model.selection = model.notes.first?.id }
        }
    }
}
