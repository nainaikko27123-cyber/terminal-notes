import NotesKit
import SwiftUI

struct ContentView: View {
    @Environment(NotesModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(model.notes, selection: $model.selection) { note in
                NoteRow(note: note)
                    .contextMenu {
                        Button(note.isPinned ? "Unpin" : "Pin") { model.togglePin(note.id) }
                        Button("Delete", role: .destructive) { model.delete(note.id) }
                    }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                Button("Open Terminal", systemImage: "terminal") { openWindow(id: NotesApp.terminalWindowID) }
                Button("New Note", systemImage: "square.and.pencil") { model.createNote() }
            }
        } detail: {
            if let note = model.notes.first(where: { $0.id == model.selection }) {
                NoteEditor(note: note)
                    .id(note.id)
            } else {
                ContentUnavailableView("No Note Selected", systemImage: "note.text")
            }
        }
        .task { await model.watchForChanges() }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(note.title)
                    .lineLimit(1)
            }
            Text(note.updatedAt, format: .dateTime.day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NoteEditor: View {
    let note: Note

    var body: some View {
        AutosavingNoteEditor(note: note) { text in
            TextEditor(text: text)
                .font(.body.monospaced())
                .contentMargins(12, for: .scrollContent)
        }
    }
}
