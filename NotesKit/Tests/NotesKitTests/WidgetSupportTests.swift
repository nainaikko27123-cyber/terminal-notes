import AppKit
import Foundation
import Testing
@testable import NotesKit

@Suite struct WidgetSupportTests {
    @Test func itemsAreNewestFirstAndStartAtTheCheckbox() {
        let note = Note(body: "plain line\n[ ] first\n- [x] second #tag\n```\n[ ] in code\n```\n[ ] third")
        let items = Todos.items(in: note)
        #expect(items.map(\.line) == ["[ ] third", "[x] second #tag", "[ ] first"])
        #expect(items.map(\.isDone) == [false, true, false])
        #expect((note.body as NSString).substring(with: NSRange(location: items[1].location, length: 3)) == "[x]")
    }

    @Test func recentPutsTheLastEditedNoteFirstAndStopsAtTheLimit() {
        let now = Date()
        let older = Note(body: "[ ] old 1\n[ ] old 2", updatedAt: now.addingTimeInterval(-60))
        let newer = Note(body: "[ ] new 1\n[x] new 2", updatedAt: now)
        #expect(Todos.recent(from: [older, newer], limit: 3).map(\.line) == ["[x] new 2", "[ ] new 1", "[ ] old 2"])
        #expect(Todos.recent(from: [], limit: 3).isEmpty)
    }

    @Test func itemIDsAreUniqueAcrossNotes() {
        let items = Todos.recent(from: [Note(body: "[ ] a\n[ ] b"), Note(body: "[ ] a")], limit: 5)
        #expect(Set(items.map(\.id)).count == 3)
    }

    @Test func togglesATodoOnDiskAndIgnoresAStalePosition() throws {
        let store = try NoteStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let id = NoteTab.todo.id
        try store.save(body: "[ ] milk\n[x] eggs", id: id)

        try store.toggleTodo(at: 0, noteID: id)
        #expect(try store.note(id: id).body == "[x] milk\n[x] eggs")
        try store.toggleTodo(at: 9, noteID: id)
        #expect(try store.note(id: id).body == "[x] milk\n[ ] eggs")

        try store.toggleTodo(at: 5, noteID: id)
        #expect(try store.note(id: id).body == "[x] milk\n[ ] eggs")
    }

    @Test func stylerColorsATagAtTheRequestedSize() {
        let text = NSMutableAttributedString(string: "buy #milk")
        MarkdownStyler.apply(Theme.tokyoNight.palette, to: text, size: 10)
        #expect(text.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor == Theme.tokyoNight.palette.tag)
        #expect((text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 10)
    }
}
