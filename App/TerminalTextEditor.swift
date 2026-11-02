import AppKit
import NotesKit
import SwiftUI

@MainActor
enum TerminalFonts {
    static let regular = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}

/// A text view that draws a ❯ beside each line, bright on the line with the cursor.
final class PromptTextView: NSTextView {
    static let gutterWidth: CGFloat = 34

    var palette = Theme.default.palette

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        // An empty page shows the welcome screen, so a lone prompt would just be clutter.
        guard let layoutManager, let textContainer, !string.isEmpty else { return }

        let origin = textContainerOrigin
        let text = string as NSString
        let cursor = selectedRange().location
        // A trailing newline leaves an empty last line that has no glyphs of its own.
        let cursorOnExtraLine = cursor == text.length && (text.length == 0 || text.hasSuffix("\n"))
        let cursorLine = text.lineRange(for: NSRange(location: min(cursor, text.length), length: 0))

        let visible = layoutManager.glyphRange(forBoundingRect: rect.offsetBy(dx: -origin.x, dy: -origin.y), in: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: visible) { lineRect, _, _, glyphs, _ in
            let start = layoutManager.characterIndexForGlyph(at: glyphs.location)
            // Only the first row of a wrapped line gets a prompt.
            guard start == 0 || text.character(at: start - 1) == 0x0A else { return }
            self.drawPrompt(atY: lineRect.minY + origin.y, active: !cursorOnExtraLine && start == cursorLine.location)
        }

        let extra = layoutManager.extraLineFragmentRect
        if !extra.isEmpty {
            drawPrompt(atY: extra.minY + origin.y, active: cursorOnExtraLine)
        }
    }

    private func drawPrompt(atY y: CGFloat, active: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: TerminalFonts.regular,
            .foregroundColor: active ? palette.accent : palette.dim,
        ]
        ("❯" as NSString).draw(at: NSPoint(x: 14, y: y), withAttributes: attributes)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    /// Clicking a `[ ]` or `[x]` flips it. Undo works, and the cursor stays where it was.
    override func mouseDown(with event: NSEvent) {
        guard let box = checkboxRange(at: convert(event.locationInWindow, from: nil)) else {
            super.mouseDown(with: event)
            return
        }
        let selection = selectedRange()
        insertText(Todos.toggled((string as NSString).substring(with: box)), replacementRange: box)
        setSelectedRange(selection)
    }

    private func checkboxRange(at point: NSPoint) -> NSRange? {
        guard let layoutManager, let textContainer, !string.isEmpty else { return nil }
        let inContainer = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layoutManager.glyphIndex(for: inContainer, in: textContainer)
        let box = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        guard box.contains(inContainer) else { return nil }
        return Todos.checkboxRange(at: layoutManager.characterIndexForGlyph(at: glyph), in: string)
    }
}

/// A plain text editor that styles Markdown live as you type.
struct TerminalTextEditor: NSViewRepresentable {
    @Binding var text: String
    let palette: TerminalPalette

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, palette: palette)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let textView = PromptTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.isRichText = false
        // The window's see-through background shows behind the text.
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = TerminalFonts.regular
        apply(palette, to: textView)
        textView.textContainerInset = NSSize(width: PromptTextView.gutterWidth, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text
        MarkdownStyler.apply(palette, to: storage)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.palette = palette
        guard let textView = scrollView.documentView as? PromptTextView else { return }

        var needsStyling = false
        if textView.palette != palette {
            apply(palette, to: textView)
            needsStyling = true
        }
        var didAppend = false
        if textView.string != text {
            didAppend = text.hasPrefix(textView.string)
            textView.string = text
            needsStyling = true
        }
        if needsStyling, let storage = textView.textStorage {
            MarkdownStyler.apply(palette, to: storage)
        }
        if didAppend {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func apply(_ palette: TerminalPalette, to textView: PromptTextView) {
        textView.palette = palette
        textView.backgroundColor = palette.background
        textView.insertionPointColor = palette.accent
        textView.typingAttributes = [.font: TerminalFonts.regular, .foregroundColor: palette.text]
        textView.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var palette: TerminalPalette

        init(text: Binding<String>, palette: TerminalPalette) {
            self.text = text
            self.palette = palette
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            // Restyling mid-composition would interrupt input methods; the final text triggers another change.
            if !textView.hasMarkedText(), let storage = textView.textStorage {
                MarkdownStyler.apply(palette, to: storage)
            }
        }
    }
}
