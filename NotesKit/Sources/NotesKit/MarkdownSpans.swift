import Foundation

public struct MarkdownSpan: Equatable, Sendable {
    public enum Style: Sendable {
        case heading, bold, italic, code, quote, listMarker, link
    }

    public let style: Style
    public let range: NSRange
}

/// Finds Markdown syntax for live highlighting. Spans keep their markers, so the text being
/// edited never changes. Nothing inside code is treated as Markdown.
public enum MarkdownSpans {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
    }

    private static let fencedCode = regex(#"^```[^\n]*\n[\s\S]*?(?:^```[ \t]*$|\z)"#)
    private static let inlineCode = regex(#"`[^`\n]+`"#)
    private static let others: [(MarkdownSpan.Style, NSRegularExpression)] = [
        (.heading, regex(#"^#{1,6}[ \t].*$"#)),
        (.quote, regex(#"^>.*$"#)),
        (.listMarker, regex(#"^[ \t]*(?:[-*+]|\d+\.)(?=[ \t])"#)),
        (.italic, regex(#"(?<![*\w])\*(?=[^\s*])[^*\n]+?(?<=[^\s*])\*(?![*\w])"#)),
        (.italic, regex(#"(?<![_\w])_(?=[^\s_])[^_\n]+?(?<=[^\s_])_(?![_\w])"#)),
        (.bold, regex(#"\*\*(?=\S)[^\n]+?(?<=\S)\*\*"#)),
        (.bold, regex(#"__(?=\S)[^\n]+?(?<=\S)__"#)),
        (.link, regex(#"\[[^\]\n]+\]\([^)\s]+\)"#)),
    ]

    public static func find(in text: String) -> [MarkdownSpan] {
        let whole = NSRange(location: 0, length: (text as NSString).length)
        func ranges(_ regex: NSRegularExpression) -> [NSRange] {
            regex.matches(in: text, range: whole).map(\.range)
        }

        let fences = ranges(fencedCode)
        let code = fences + ranges(inlineCode).filter { !overlaps($0, fences) }
        var spans = code.map { MarkdownSpan(style: .code, range: $0) }
        for (style, regex) in others {
            spans += ranges(regex)
                .filter { !overlaps($0, code) }
                .map { MarkdownSpan(style: style, range: $0) }
        }
        return spans
    }

    private static func overlaps(_ range: NSRange, _ others: [NSRange]) -> Bool {
        others.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
