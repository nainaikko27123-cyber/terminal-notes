import AppKit
import NotesKit
import SwiftUI

/// A one-line text view with a blinking block cursor. The system's thin cursor is hidden,
/// so the block is drawn here, behind the text, which keeps the letter under it readable.
final class BlockCursorTextView: NSTextView {
    var palette = Theme.default.palette
    private(set) var cursorIsOn = true
    private var blinkTimer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        blinkTimer?.invalidate()
        blinkTimer = nil
        guard let window else { return }
        // The cursor belongs here as soon as the prompt appears, including after a tab switch.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            window.makeFirstResponder(self)
        }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.cursorIsOn.toggle()
                self.needsDisplay = true
            }
        }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard selectedRange().length == 0, window?.firstResponder === self else { return }
        if cursorIsOn {
            palette.accent.withAlphaComponent(0.75).setFill()
            cursorRect().fill()
        }
    }

    private func cursorRect() -> NSRect {
        let font = TerminalFonts.regular
        let width = ("M" as NSString).size(withAttributes: [.font: font]).width
        let origin = textContainerOrigin
        var x = origin.x + (textContainer?.lineFragmentPadding ?? 0)
        var height = font.boundingRectForFont.height

        let location = selectedRange().location
        if let layoutManager, let textContainer, layoutManager.numberOfGlyphs > 0 {
            layoutManager.ensureLayout(for: textContainer)
            let glyph = layoutManager.glyphIndexForCharacter(at: min(location, max((string as NSString).length - 1, 0)))
            let box = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
            x = origin.x + (location >= (string as NSString).length ? box.maxX : box.minX)
            height = box.height
        }
        return NSRect(x: x, y: origin.y, width: width, height: height)
    }

    /// Keeps the cursor solid while typing, then blinking starts again.
    private func showCursor() {
        cursorIsOn = true
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        showCursor()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        showCursor()
    }

    override func becomeFirstResponder() -> Bool {
        showCursor()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }
}

/// The text box after the prompt. Enter hands the text over and clears the box.
struct PromptField: NSViewRepresentable {
    let palette: TerminalPalette
    /// Goes up when something asks for the cursor to come back here.
    let focusRequestCount: Int
    let onSubmit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let textView = BlockCursorTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = TerminalFonts.regular
        textView.insertionPointColor = .clear
        // Lines the typed text up with the prompt beside it.
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = false
        textView.autoresizingMask = .height
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        apply(palette, to: textView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false

        context.coordinator.focusRequestCount = focusRequestCount
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        guard let textView = scrollView.documentView as? BlockCursorTextView else { return }
        if textView.palette != palette {
            apply(palette, to: textView)
        }
        if context.coordinator.focusRequestCount != focusRequestCount {
            context.coordinator.focusRequestCount = focusRequestCount
            textView.window?.makeFirstResponder(textView)
        }
    }

    private func apply(_ palette: TerminalPalette, to textView: BlockCursorTextView) {
        textView.palette = palette
        textView.backgroundColor = palette.background
        textView.textColor = palette.text
        textView.typingAttributes = [.font: TerminalFonts.regular, .foregroundColor: palette.text]
        textView.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onSubmit: (String) -> Void
        var focusRequestCount = 0

        init(onSubmit: @escaping (String) -> Void) {
            self.onSubmit = onSubmit
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let input = textView.string.trimmingCharacters(in: .whitespaces)
            guard !input.isEmpty else { return true }
            textView.string = ""
            onSubmit(input)
            return true
        }

        /// This box is one line, so pasted line breaks become spaces.
        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            guard let replacementString, replacementString.contains(where: \.isNewline) else { return true }
            let flattened = replacementString.split(whereSeparator: \.isNewline).joined(separator: " ")
            textView.insertText(flattened, replacementRange: range)
            return false
        }
    }
}

/// `shinyu@notes ~ $` followed by the text box.
struct PromptLine: View {
    let palette: TerminalPalette
    let focusRequestCount: Int
    let onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Group {
                Text("shinyu@notes").foregroundStyle(Color(nsColor: palette.done))
                Text(" ~ ").foregroundStyle(Color(nsColor: palette.tag))
                Text("$ ").foregroundStyle(Color(nsColor: palette.accent))
            }
            .font(.system(size: 13, design: .monospaced))
            .fixedSize()
            PromptField(palette: palette, focusRequestCount: focusRequestCount, onSubmit: onSubmit)
        }
        .frame(height: 20)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
