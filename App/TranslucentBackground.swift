import AppKit
import SwiftUI

/// Blurs whatever is behind the window, and makes the window itself see-through so the blur shows.
struct TranslucentBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = WindowClearingEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        // Stays see-through when another app is in front.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    private final class WindowClearingEffectView: NSVisualEffectView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }
}
