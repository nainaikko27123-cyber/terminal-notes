import AppKit
import NotesKit
import SwiftUI

/// Gives an editor view a text binding that saves shortly after typing stops, and again when the
/// note closes or the app quits. Picks up changes saved elsewhere unless there are unsaved edits here.
struct AutosavingNoteEditor<Editor: View>: View {
    @Environment(NotesModel.self) private var model
    @State private var text: String
    @State private var savedText: String
    @State private var pendingSave: Task<Void, Never>?

    private let note: Note
    private let editor: (Binding<String>) -> Editor

    init(note: Note, @ViewBuilder editor: @escaping (Binding<String>) -> Editor) {
        self.note = note
        self.editor = editor
        _text = State(initialValue: note.body)
        _savedText = State(initialValue: note.body)
    }

    var body: some View {
        editor($text)
            .onChange(of: text) {
                pendingSave?.cancel()
                pendingSave = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if !Task.isCancelled { saveIfNeeded() }
                }
            }
            .onChange(of: note.body) {
                guard note.body != savedText else { return }
                if text == savedText { text = note.body }
                savedText = note.body
            }
            .onChange(of: model.saveRequestCount) {
                pendingSave?.cancel()
                saveIfNeeded()
            }
            .onDisappear {
                pendingSave?.cancel()
                saveIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                saveIfNeeded()
            }
    }

    private func saveIfNeeded() {
        guard text != savedText else { return }
        savedText = text
        model.save(body: text, for: note.id)
    }
}
