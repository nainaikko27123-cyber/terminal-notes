import AppKit

/// Colors Markdown text, for both the terminal window and the widget.
public enum MarkdownStyler {
    public static func apply(_ palette: TerminalPalette, to text: NSMutableAttributedString, size: CGFloat = 13) {
        let regular = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let bold = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        let italic = NSFontManager.shared.convert(regular, toHaveTrait: .italicFontMask)

        text.beginEditing()
        defer { text.endEditing() }
        text.setAttributes([.font: regular, .foregroundColor: palette.text], range: NSRange(location: 0, length: text.length))
        for span in MarkdownSpans.find(in: text.string) {
            let attributes: [NSAttributedString.Key: Any] = switch span.style {
            case .heading: [.font: bold, .foregroundColor: palette.header]
            case .bold: [.font: bold]
            case .italic: [.font: italic]
            case .code: [.foregroundColor: palette.code]
            case .quote: [.foregroundColor: palette.dim]
            case .listMarker: [.foregroundColor: palette.accent]
            case .link: [.foregroundColor: palette.link]
            case .tag: [.foregroundColor: palette.tag]
            case .date: [.foregroundColor: palette.date]
            case .todoDoneLine: [.foregroundColor: palette.dim]
            case .todoOpenBox: [.foregroundColor: palette.accent]
            case .todoDoneBox: [.font: bold, .foregroundColor: palette.done]
            }
            text.addAttributes(attributes, range: span.range)
        }
    }
}
