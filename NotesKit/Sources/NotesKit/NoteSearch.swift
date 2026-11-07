import Foundation

public extension Note {
    /// Whether this note fits a `:search`. A `#tag` must match one of the note's tags exactly,
    /// and anything else can appear anywhere in the title or text. Capitals don't matter.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if query.hasPrefix("#"), query.count > 1 {
            let text = body as NSString
            return MarkdownSpans.find(in: body).contains { span in
                span.style == .tag && text.substring(with: span.range).caseInsensitiveCompare(query) == .orderedSame
            }
        }
        return title.localizedCaseInsensitiveContains(query) || body.localizedCaseInsensitiveContains(query)
    }
}
