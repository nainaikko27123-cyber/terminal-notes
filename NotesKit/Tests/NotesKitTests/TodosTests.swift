import Foundation
import Testing
@testable import NotesKit

@Suite struct TodosTests {
    let page = "[ ] milk\n[x] eggs\n  - [ ] nested\n[X] caps\nnot [ ] a todo\n[ ]no space\n```\n[ ] in code\n```"

    func text(_ style: MarkdownSpan.Style, in text: String) -> [String] {
        MarkdownSpans.find(in: text).filter { $0.style == style }.map { (text as NSString).substring(with: $0.range) }
    }

    @Test func countsOnlyRealOpenTodos() {
        #expect(Todos.openCount(in: page) == 2)
        #expect(Todos.openCount(in: "") == 0)
    }

    @Test func doneLinesAreMarkedAsAWholeWithoutTheLineBreak() {
        #expect(text(.todoDoneLine, in: page) == ["[x] eggs", "[X] caps"])
        #expect(text(.todoDoneBox, in: page) == ["[x]", "[X]"])
        #expect(text(.todoOpenBox, in: page) == ["[ ]", "[ ]"])
    }

    @Test func emptyBoxAtTheEndOfALineCounts() {
        #expect(Todos.openCount(in: "[ ]") == 1)
    }

    @Test func findsTheCheckboxUnderAClick() throws {
        let inside = try #require(Todos.checkboxRange(at: 1, in: page))
        #expect(inside == NSRange(location: 0, length: 3))
        #expect(Todos.checkboxRange(at: 5, in: page) == nil)
    }

    @Test func togglesBothWays() {
        #expect(Todos.toggled("[ ]") == "[x]")
        #expect(Todos.toggled("[x]") == "[ ]")
        #expect(Todos.toggled("[X]") == "[ ]")
    }

    @Test func todoTabTurnsInputIntoATodo() {
        #expect(NoteTab.todo.line(from: "buy milk") == "[ ] buy milk")
        #expect(NoteTab.todo.line(from: "[x] already done") == "[x] already done")
        #expect(NoteTab.notes.line(from: "buy milk") == "buy milk")
    }
}
