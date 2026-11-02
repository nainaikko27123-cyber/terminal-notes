import Foundation

public struct MarkdownSpan: Equatable, Sendable {
    public enum Style: Sendable {
        case heading, bold, italic, code, quote, listMarker, link, tag, date, todoDoneLine, todoOpenBox, todoDoneBox
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
        (.tag, regex(#"(?<![\w#/])#[A-Za-z][\w-]*"#)),
        (.date, regex(#"\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*(?: \d{4})?\b"#)),
    ]

    private static let todo = regex(#"^[ \t]*(?:[-*+][ \t]+)?\[([ xX])\](?=[ \t]|$)"#)

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
        spans += todoSpans(in: text, range: whole, excluding: code)
        return spans
    }

    /// Comes last, so a done line's dimming and its box's color win over other styles.
    private static func todoSpans(in text: String, range: NSRange, excluding code: [NSRange]) -> [MarkdownSpan] {
        let string = text as NSString
        var lines: [MarkdownSpan] = []
        var boxes: [MarkdownSpan] = []
        for match in todo.matches(in: text, range: range) where !overlaps(match.range, code) {
            let mark = match.range(at: 1)
            let box = NSRange(location: mark.location - 1, length: 3)
            if string.substring(with: mark) == " " {
                boxes.append(MarkdownSpan(style: .todoOpenBox, range: box))
            } else {
                var start = 0, contentsEnd = 0
                string.getLineStart(&start, end: nil, contentsEnd: &contentsEnd, for: box)
                lines.append(MarkdownSpan(style: .todoDoneLine, range: NSRange(location: start, length: contentsEnd - start)))
                boxes.append(MarkdownSpan(style: .todoDoneBox, range: box))
            }
        }
        return lines + boxes
    }

    private static func overlaps(_ range: NSRange, _ others: [NSRange]) -> Bool {
        others.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
