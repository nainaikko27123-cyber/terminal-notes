import Foundation
import NotesKit
import Observation
import WidgetKit

@MainActor
@Observable
final class NotesModel {
    private(set) var notes: [Note] = []
    /// The note open in the Notes tab. Remembered between launches.
    var selection: Note.ID? {
        didSet { settings.set(selection?.uuidString, forKey: Self.selectionKey) }
    }
    var errorMessage: String?
    /// Goes up each time the user asks to save, so every open editor can save its text.
    private(set) var saveRequestCount = 0
    /// A line from the prompt for the open note's editor to add. The editor holds the latest text,
    /// so it adds the line itself rather than the store, and nothing typed is lost.
    private(set) var appendRequest: AppendRequest?

    struct AppendRequest: Equatable {
        let serial: Int
        let noteID: Note.ID
        let line: String
    }

    /// A new note whose editor should take the cursor when it opens.
    private(set) var editorFocusNoteID: Note.ID?
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

    private static let selectionKey = "selectedNote"
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
        let saved = settings.string(forKey: Self.selectionKey).flatMap(UUID.init(uuidString:))
        selection = sidebarNotes.first { $0.id == saved }?.id ?? sidebarNotes.first?.id
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

    /// The notes in the Notes tab's sidebar, newest first.
    var sidebarNotes: [Note] {
        notes.filter { !NoteTab.pageIDs.contains($0.id) }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// What `:search` is filtering the sidebar by, if anything.
    private(set) var searchQuery: String?
    /// A note waiting for a "y" at the prompt before it's deleted.
    private(set) var pendingDeleteID: Note.ID?

    /// The sidebar after any search.
    var filteredNotes: [Note] {
        guard let searchQuery else { return sidebarNotes }
        return sidebarNotes.filter { $0.matches(searchQuery) }
    }

    var selectedNote: Note? {
        notes.first { $0.id == selection && !NoteTab.pageIDs.contains($0.id) }
    }

    func select(_ id: Note.ID) {
        selection = id
        editorFocusNoteID = nil
    }

    /// Moves the selection up (-1) or down (+1) the sidebar, stopping at either end.
    func moveSelection(by offset: Int) {
        let list = filteredNotes
        guard !list.isEmpty else { return }
        guard let index = list.firstIndex(where: { $0.id == selection }) else {
            select(list[0].id)
            return
        }
        select(list[min(max(index + offset, 0), list.count - 1)].id)
    }

    /// The saved page for a tab, or a blank one if nothing has been written there yet.
    func page(for tab: NoteTab) -> Note {
        notes.first { $0.id == tab.id } ?? Note(id: tab.id)
    }

    /// Open to-dos across every note and page. An open editor counts its live text instead,
    /// by leaving its own note out here.
    func openTaskCount(excludingNoteID id: Note.ID? = nil) -> Int {
        notes.filter { $0.id != id }.reduce(0) { $0 + Todos.openCount(in: $1.body) }
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
        case .newNote(let title):
            newNote(title: title)
        case .rename(let title):
            rename(to: title)
        case .delete:
            askToDelete()
        case .search(let query):
            search(query)
        }
    }

    /// A sticky message stays until it's replaced, for questions that wait for an answer.
    private func showStatusMessage(_ message: String, sticky: Bool = false) {
        statusMessage = message
        statusMessageTask?.cancel()
        guard !sticky else { return }
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

    /// Makes a note, opens it in the Notes tab and puts the cursor in it.
    func newNote(title: String?, body: String = "") {
        guard let store else { return }
        perform {
            let note = try store.create(body: body, customTitle: title)
            currentTab = .notes
            searchQuery = nil
            didChangeNotes()
            select(note.id)
            editorFocusNoteID = note.id
            showStatusMessage("new note: \(note.title)")
        }
    }

    /// Handles a line typed at the Notes tab's prompt.
    func submitNotesPrompt(_ input: String) {
        if let id = pendingDeleteID {
            pendingDeleteID = nil
            if ["y", "yes"].contains(input.lowercased()) {
                deleteFromSidebar(id)
            } else {
                showStatusMessage("kept it")
            }
        } else if let command = PromptCommand.parse(input) {
            run(command)
        } else if let note = selectedNote {
            appendRequest = AppendRequest(serial: (appendRequest?.serial ?? 0) + 1, noteID: note.id, line: input)
        } else {
            newNote(title: nil, body: input)
        }
    }

    /// The open note, or a message saying why there isn't one to work on.
    private func noteToManage() -> Note? {
        guard currentTab == .notes else {
            showStatusMessage("switch to the Notes tab first")
            return nil
        }
        guard let note = selectedNote else {
            showStatusMessage("no note selected")
            return nil
        }
        return note
    }

    private func rename(to title: String?) {
        guard let note = noteToManage() else { return }
        rename(note.id, to: title)
    }

    /// Sets a note's title. A blank title goes back to using the first line.
    func rename(_ id: Note.ID, to title: String?) {
        guard let store else { return }
        let title = title?.trimmingCharacters(in: .whitespaces)
        let customTitle = title?.isEmpty == false ? title : nil
        perform {
            let renamed = try store.update(id: id) { $0.customTitle = customTitle }
            didChangeNotes()
            showStatusMessage(customTitle == nil ? "title now comes from the first line" : "renamed to \(renamed.title)")
        }
    }

    private func askToDelete() {
        guard let note = noteToManage() else { return }
        pendingDeleteID = note.id
        showStatusMessage("delete \"\(note.title)\"? type y to confirm", sticky: true)
    }

    /// Deletes a note and opens the one next to it in the list.
    private func deleteFromSidebar(_ id: Note.ID) {
        guard let store else { return }
        let list = filteredNotes
        let index = list.firstIndex { $0.id == id }
        perform {
            try store.delete(id: id)
            didChangeNotes()
            let remaining = filteredNotes
            if let index, !remaining.isEmpty {
                select(remaining[min(index, remaining.count - 1)].id)
            } else {
                selection = remaining.first?.id
            }
            showStatusMessage("deleted")
        }
    }

    private func search(_ query: String?) {
        currentTab = .notes
        searchQuery = query
        let found = filteredNotes
        if let query {
            if !found.contains(where: { $0.id == selection }), let first = found.first { select(first.id) }
            showStatusMessage(found.isEmpty ? "nothing matches \(query)" : "\(found.count) found for \(query)")
        } else {
            showStatusMessage("showing all notes")
        }
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
            // To do and Ideas pages are removed when emptied. Sidebar notes, including the old
            // Notes tab page, only go away with :delete.
            if NoteTab.pageIDs.contains(id) {
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
