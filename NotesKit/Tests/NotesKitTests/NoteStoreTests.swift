import Foundation
import Testing
@testable import NotesKit

@Suite struct NoteStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    func makeStore() throws -> NoteStore {
        try NoteStore(directory: directory)
    }

    @Test func createdNoteRoundTripsThroughDisk() throws {
        let store = try makeStore()
        let created = try store.create(body: "# Title\n\n---\nnot front matter\n---\n\ntrailing\n")
        let loaded = try store.note(id: created.id)

        #expect(loaded.body == created.body)
        #expect(abs(loaded.createdAt.timeIntervalSince(created.createdAt)) < 0.01)
        #expect(!loaded.isPinned)
    }

    @Test func customTitleIsSavedAndUsedOverTheFirstLine() throws {
        let store = try makeStore()
        let note = try store.create(body: "first line", customTitle: "My: title")
        let loaded = try store.note(id: note.id)
        #expect(loaded.customTitle == "My: title")
        #expect(loaded.title == "My: title")
        #expect(loaded.body == "first line")
        #expect(try store.note(id: store.create(body: "first line").id).title == "first line")
    }

    @Test func customTitleStaysOnOneLine() throws {
        let store = try makeStore()
        let note = try store.create(body: "x", customTitle: "two\nlines")
        #expect(try store.note(id: note.id).customTitle == "two lines")
    }

    @Test func editingTheTextKeepsTheCustomTitle() throws {
        let store = try makeStore()
        let note = try store.create(body: "a", customTitle: "Keep me")
        try store.update(id: note.id) { $0.body = "b" }
        #expect(try store.note(id: note.id).customTitle == "Keep me")
    }

    @Test func emptyNoteRoundTrips() throws {
        let store = try makeStore()
        let created = try store.create()
        #expect(try store.note(id: created.id).body == "")
    }

    @Test func titleSkipsBlankLinesAndHeadingMarkers() {
        #expect(Note(body: "\n\n## Groceries\nmilk").title == "Groceries")
        #expect(Note(body: "  \n").title == "New Note")
    }

    @Test func pinnedNotesSortFirstThenNewest() throws {
        let store = try makeStore()
        let pinned = try store.create(body: "pinned")
        try store.update(id: pinned.id) { $0.isPinned = true }
        let older = try store.create(body: "older")
        Thread.sleep(forTimeInterval: 0.01)
        let newer = try store.create(body: "newer")

        #expect(try store.allNotes().map(\.id) == [pinned.id, newer.id, older.id])
    }

    @Test func pinningDoesNotChangeUpdatedAtButEditingDoes() throws {
        let store = try makeStore()
        let note = try store.note(id: store.create(body: "a").id)

        let pinned = try store.update(id: note.id) { $0.isPinned = true }
        #expect(pinned.updatedAt == note.updatedAt)

        Thread.sleep(forTimeInterval: 0.01)
        let edited = try store.update(id: note.id) { $0.body = "b" }
        #expect(edited.updatedAt > note.updatedAt)
        #expect(edited.isPinned)
    }

    @Test func concurrentUpdatesFromTwoStoresLoseNothing() async throws {
        let first = try makeStore()
        let second = try makeStore()
        let note = try first.create(body: "")

        await withTaskGroup(of: Void.self) { group in
            for store in [first, second] {
                for _ in 0..<50 {
                    group.addTask { _ = try? store.update(id: note.id) { $0.body += "x" } }
                }
            }
        }

        #expect(try first.note(id: note.id).body.count == 100)
    }

    @Test func plainMarkdownFileLoadsWithFileDate() throws {
        let store = try makeStore()
        let id = UUID()
        try "# Dropped in\n".write(to: directory.appending(path: "\(id.uuidString).md"), atomically: true, encoding: .utf8)

        let note = try store.note(id: id)
        #expect(note.title == "Dropped in")
        #expect(note.body == "# Dropped in\n")
        #expect(abs(note.updatedAt.timeIntervalSinceNow) < 60)
    }

    @Test func otherFilesAreIgnored() throws {
        let store = try makeStore()
        try "x".write(to: directory.appending(path: "readme.md"), atomically: true, encoding: .utf8)
        try "x".write(to: directory.appending(path: "\(UUID().uuidString).txt"), atomically: true, encoding: .utf8)
        #expect(try store.allNotes().isEmpty)
    }

    @Test func invalidUTF8FileIsSkippedWithoutHidingOtherNotes() throws {
        let store = try makeStore()
        let good = try store.create(body: "good")
        try Data([0xFF, 0xFE, 0xFF]).write(to: directory.appending(path: "\(UUID().uuidString).md"))
        #expect(try store.allNotes().map(\.id) == [good.id])
    }

    @Test func missingNotesThrowNoteNotFound() throws {
        let store = try makeStore()
        let id = UUID()
        func isNotFound(_ error: any Error) -> Bool {
            if case NoteStore.StoreError.noteNotFound(id) = error { true } else { false }
        }
        #expect(performing: { try store.note(id: id) }, throws: isNotFound)
        #expect(performing: { try store.update(id: id) { $0.body = "x" } }, throws: isNotFound)
        #expect(performing: { try store.delete(id: id) }, throws: isNotFound)
    }

    @Test func deleteRemovesTheNote() throws {
        let store = try makeStore()
        let note = try store.create(body: "bye")
        try store.delete(id: note.id)
        #expect(try store.allNotes().isEmpty)
    }

    @Test func changesFiresWhenAnotherStoreWrites() async throws {
        let watcher = try makeStore()
        let writer = try makeStore()
        let changes = watcher.changes()

        try writer.create(body: "hello")

        let fired = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in changes { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        #expect(fired)
    }
}
