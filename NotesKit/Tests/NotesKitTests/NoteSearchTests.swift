import Testing
@testable import NotesKit

@Suite struct NoteSearchTests {
    let groceries = Note(body: "milk and eggs #Home #shopping", customTitle: "Groceries")
    let study = Note(body: "# OSI model\\nsee #homework")

    @Test func wordsMatchTitleOrTextIgnoringCapitals() {
        #expect(groceries.matches("grocer"))
        #expect(groceries.matches("EGGS"))
        #expect(study.matches("osi"))
        #expect(!study.matches("milk"))
    }

    @Test func tagsMustMatchExactly() {
        #expect(groceries.matches("#home"))
        #expect(!study.matches("#home"))
        #expect(study.matches("#homework"))
        #expect(!groceries.matches("#shop"))
    }

    @Test func emptySearchMatchesEverything() {
        #expect(groceries.matches(""))
        #expect(groceries.matches("   "))
    }

    @Test func aLoneHashIsAPlainSearch() {
        #expect(study.matches("#"))
        #expect(!Note(body: "no hashes").matches("#"))
    }
}
