import AppIntents
import NotesKit
import WidgetKit

/// Runs in the widget's process when its pin button is clicked, and writes straight to the shared store.
struct TogglePinIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Pin"

    @Parameter(title: "Note ID")
    var noteID: String

    init() {}

    init(noteID: Note.ID) {
        self.noteID = noteID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: noteID) else {
            throw NoteStore.StoreError.noteNotFound(UUID())
        }
        try NoteStore.shared().update(id: id) { $0.isPinned.toggle() }
        return .result()
    }
}
