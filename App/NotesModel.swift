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
    /// Goes up each time the cursor should jump back to the prompt.
    private(set) var promptFocusRequestCount = 0

    var currentTab = NoteTab.saved() {
        didSet { currentTab.save() }
    }

    var theme = Theme.saved() {
        didSet {
            theme.save()
            reloadWidgets()
        }
    }

    /// How solid the terminal's background is, from 20 to 100.
    private(set) var windowOpacity: Int
    /// A short reply to a prompt command, shown for a moment in the status bar.
    private(set) var statusMessage: String?
    private var statusMessageTask: Task<Void, Never>?

    private let settings: UserDefaults
    private let store: NoteStore?
    /// Tells the desktop widget to redraw from the saved notes.
    private let reloadWidgets: () -> Void

    init(
        store: NoteStore? = nil,
        settings: UserDefaults = Theme.sharedDefaults,
        reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.settings = settings
        self.reloadWidgets = reloadWidgets
        windowOpacity = WindowOpacity.saved(in: settings)
        do {
            self.store = try store ?? NoteStore.forApp()
        } catch {
            self.store = nil
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

    /// The saved page for a tab, or a blank one if nothing has been written there yet.
    func page(for tab: NoteTab) -> Note {
        notes.first { $0.id == tab.id } ?? Note(id: tab.id)
    }

    /// Open to-dos on the tabs other than this one. The current tab counts its live text instead.
    func openTaskCount(excluding tab: NoteTab) -> Int {
        NoteTab.allCases
            .filter { $0 != tab }
            .reduce(0) { $0 + Todos.openCount(in: page(for: $1).body) }
    }

    func run(_ command: PromptCommand) {
        switch command {
        case .setOpacity(let value):
            windowOpacity = value
            WindowOpacity.save(value, to: settings)
            showStatusMessage("opacity \(value)%")
        case .showOpacity:
            showStatusMessage("opacity \(windowOpacity)%")
        case .invalidOpacity:
            showStatusMessage("use :opacity \(WindowOpacity.range.lowerBound)-\(WindowOpacity.range.upperBound)")
        }
    }

    private func showStatusMessage(_ message: String) {
        statusMessage = message
        statusMessageTask?.cancel()
        statusMessageTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { statusMessage = nil }
        }
    }

    func focusPrompt() {
        promptFocusRequestCount += 1
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
            if NoteTab(noteID: id) != nil {
                try store.save(body: body, id: id)
            } else {
                try store.update(id: id) { $0.body = body }
            }
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
        reloadWidgets()
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
