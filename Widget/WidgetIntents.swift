import AppIntents
import NotesKit
import WidgetKit

/// Runs when a checkbox is clicked in the widget, and writes straight to the shared store.
struct ToggleTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle To-Do"

    @Parameter(title: "Note ID")
    var noteID: String

    @Parameter(title: "Position")
    var location: Int

    init() {}

    init(item: TodoItem) {
        noteID = item.noteID.uuidString
        location = item.location
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: noteID) else { return .result() }
        try NoteStore.shared().toggleTodo(at: location, noteID: id)
        return .result()
    }
}
