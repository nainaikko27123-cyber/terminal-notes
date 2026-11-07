import Foundation
import Testing
@testable import NotesKit

@Suite struct PromptCommandTests {
    @Test func setsOpacity() {
        #expect(PromptCommand.parse(":opacity 70") == .setOpacity(70))
        #expect(PromptCommand.parse(":OPACITY  70%") == .setOpacity(70))
        #expect(PromptCommand.parse(":opacity 20") == .setOpacity(20))
        #expect(PromptCommand.parse(":opacity 100") == .setOpacity(100))
    }

    @Test func showsCurrentValueWithNoNumber() {
        #expect(PromptCommand.parse(":opacity") == .showOpacity)
    }

    @Test(arguments: [":opacity 19", ":opacity 101", ":opacity abc", ":opacity -5", ":opacity 70 80", ":opacity 7.5"])
    func rejectsBadValues(input: String) {
        #expect(PromptCommand.parse(input) == .invalidOpacity)
    }

    @Test(arguments: ["buy milk", ":)", ":opacityfoo 70", "opacity 70", "my :opacity 70", ""])
    func leavesOrdinaryTextAlone(input: String) {
        #expect(PromptCommand.parse(input) == nil)
    }

    @Test func newNote() {
        #expect(PromptCommand.parse(":new Groceries for Friday") == .newNote(title: "Groceries for Friday"))
        #expect(PromptCommand.parse(":NEW   Shopping  ") == .newNote(title: "Shopping"))
        #expect(PromptCommand.parse(":new") == .newNote(title: nil))
        #expect(PromptCommand.parse(":newer idea") == nil)
    }

    @Test func manageNotes() {
        #expect(PromptCommand.parse(":rename Shopping list") == .rename(title: "Shopping list"))
        #expect(PromptCommand.parse(":rename") == .rename(title: nil))
        #expect(PromptCommand.parse(":delete") == .delete)
        #expect(PromptCommand.parse(":search #home") == .search("#home"))
        #expect(PromptCommand.parse(":search") == .search(nil))
        #expect(PromptCommand.parse(":deleted") == nil)
    }

    @Test func opacityIsRememberedAndBadSavedValuesFallBack() {
        let defaults = UserDefaults(suiteName: "PromptCommandTests-\(UUID().uuidString)")!
        #expect(WindowOpacity.saved(in: defaults) == 60)
        WindowOpacity.save(35, to: defaults)
        #expect(WindowOpacity.saved(in: defaults) == 35)
        WindowOpacity.save(5, to: defaults)
        #expect(WindowOpacity.saved(in: defaults) == 60)
    }
}
