import Foundation
import Testing
@testable import NotesKit

@Suite struct MarkdownSpansTests {
    /// The matched text for each span with this style.
    func matches(_ style: MarkdownSpan.Style, in text: String) -> [String] {
        MarkdownSpans.find(in: text)
            .filter { $0.style == style }
            .map { (text as NSString).substring(with: $0.range) }
    }

    @Test func headings() {
        #expect(matches(.heading, in: "# One\ntext\n### Three") == ["# One", "### Three"])
        #expect(matches(.heading, in: "#nospace").isEmpty)
    }

    @Test func boldAndItalic() {
        let text = "**bold** and *italic* and _under_"
        #expect(matches(.bold, in: text) == ["**bold**"])
        #expect(matches(.italic, in: text) == ["*italic*", "_under_"])
    }

    @Test func wordsWithUnderscoresAreNotItalic() {
        #expect(matches(.italic, in: "snake_case_name").isEmpty)
    }

    @Test func starListItemIsAListMarkerNotItalic() {
        let text = "* item one *\n- two\n12. three"
        #expect(matches(.listMarker, in: text) == ["*", "- ".trimmingCharacters(in: .whitespaces), "12."])
        #expect(matches(.italic, in: text).isEmpty)
    }

    @Test func nothingInsideCodeIsStyled() {
        let text = "`**not bold**`\n```swift\n# not heading\n*x*\n```\n# real"
        #expect(matches(.code, in: text).count == 2)
        #expect(matches(.bold, in: text).isEmpty)
        #expect(matches(.italic, in: text).isEmpty)
        #expect(matches(.heading, in: text) == ["# real"])
    }

    @Test func unclosedFenceRunsToTheEnd() {
        #expect(matches(.code, in: "a\n```\n# code") == ["```\n# code"])
        #expect(matches(.heading, in: "a\n```\n# code").isEmpty)
    }

    @Test func quotesAndLinks() {
        let text = "> said\n[site](https://example.com)"
        #expect(matches(.quote, in: text) == ["> said"])
        #expect(matches(.link, in: text) == ["[site](https://example.com)"])
    }

    @Test func tags() {
        #expect(matches(.tag, in: "buy #milk and #2-day #to-do") == ["#milk", "#to-do"])
        #expect(matches(.tag, in: "# Heading\nsite.com/#top c#sharp `#code`").isEmpty)
    }

    @Test func dates() {
        #expect(matches(.date, in: "due 2026-11-02 or 28 Oct 2026 or 3 November") == ["2026-11-02", "28 Oct 2026", "3 November"])
        #expect(matches(.date, in: "ping 192.168.100.1 for 10 octopus").isEmpty)
    }

    @Test func rangesCountEmojiAsUTF16() {
        #expect(matches(.bold, in: "🎧🎧 **loud**") == ["**loud**"])
    }
}
