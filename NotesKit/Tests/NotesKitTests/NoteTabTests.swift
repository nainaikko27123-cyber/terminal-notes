import Foundation
import Testing
@testable import NotesKit

@Suite struct NoteTabTests {
    @Test func labelsMatchTheTabBar() {
        #expect(NoteTab.allCases.map(\.label) == ["Notes", "To do", "Ideas"])
    }

    @Test func idsAreStableAndDistinct() {
        #expect(NoteTab.notes.id.uuidString == "00000000-0000-4000-8000-000000000001")
        #expect(Set(NoteTab.allCases.map(\.id)).count == 3)
        #expect(NoteTab(noteID: NoteTab.todo.id) == .todo)
        #expect(NoteTab(noteID: UUID()) == nil)
    }

    @Test func oldNotesPageIsASidebarNoteButOtherPagesAreNot() {
        #expect(!NoteTab.pageIDs.contains(NoteTab.notes.id))
        #expect(NoteTab.pageIDs == [NoteTab.todo.id, NoteTab.ideas.id])
    }

    @Test func currentTabPersists() {
        let defaults = UserDefaults(suiteName: "NoteTabTests-\(UUID().uuidString)")!
        #expect(NoteTab.saved(in: defaults) == .notes)
        NoteTab.ideas.save(to: defaults)
        #expect(NoteTab.saved(in: defaults) == .ideas)
    }

    /// Tests run without the App Group permission, the same as a locally signed app.
    @Test func withoutPermissionTheAppUsesItsLocalFolder() throws {
        #expect(throws: NoteStore.StoreError.self) { try NoteStore.shared() }
        let path = try NoteStore.forApp().directory.path
        #expect(path.hasSuffix("Application Support/NotesApp/Notes"))
        #expect(!path.contains("Group Containers"))
    }

    @Test func tabPageIsCreatedOnSaveAndRemovedWhenEmptied() throws {
        let store = try NoteStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let id = NoteTab.todo.id

        try store.save(body: "", id: id)
        #expect(try store.allNotes().isEmpty)

        try store.save(body: "[ ] milk", id: id)
        #expect(try store.note(id: id).body == "[ ] milk")

        try store.save(body: "[x] milk", id: id)
        #expect(try store.note(id: id).body == "[x] milk")
        #expect(try store.allNotes().count == 1)

        try store.save(body: "", id: id)
        #expect(try store.allNotes().isEmpty)
    }
}
