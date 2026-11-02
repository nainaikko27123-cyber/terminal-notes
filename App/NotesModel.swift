import Foundation
import NotesKit
import Observation
import WidgetKit

@MainActor
@Observable
final class NotesModel {
    private(set) var notes: [Note] = []
    var selection: Note.ID?
    var errorMessage: String?
    /// Goes up each time the user asks to save, so every open editor can save its text.
    private(set) var saveRequestCount = 0

    var theme = Theme.saved() {
        didSet {
            theme.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private let store: NoteStore?

    init() {
        do {
            store = try NoteStore.shared()
        } catch {
            store = nil
            errorMessage = error.localizedDescription
        }
        reload()
    }

    /// Keeps the list current when the widget changes a note. Runs until the task is cancelled.
    func watchForChanges() async {
        guard let store else { return }
        for await _ in store.changes() {
            reload()
        }
    }

    func reload() {
        guard let store else { return }
        perform { notes = try store.allNotes() }
    }

    func requestSave() {
        saveRequestCount += 1
    }

    func nextTheme() {
        theme = theme.next
    }

    func createNote() {
        guard let store else { return }
        perform {
            let note = try store.create()
            selection = note.id
            didChangeNotes()
        }
    }

    func save(body: String, for id: Note.ID) {
        guard let store else { return }
        do {
            try store.update(id: id) { $0.body = body }
            didChangeNotes()
        } catch NoteStore.StoreError.noteNotFound {
            // Deleted while an edit was pending, so there's nothing left to save.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ id: Note.ID) {
        guard let store else { return }
        perform {
            try store.update(id: id) { $0.isPinned.toggle() }
            didChangeNotes()
        }
    }

    func delete(_ id: Note.ID) {
        guard let store else { return }
        perform {
            try store.delete(id: id)
            if selection == id { selection = nil }
            didChangeNotes()
        }
    }

    private func didChangeNotes() {
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
