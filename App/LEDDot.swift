import AppKit
import SwiftUI

/// A tiny glowing light that slowly cycles through the rainbow and softly pulses. The system runs
/// the animation, so the app itself does no drawing. It freezes when another app is in front,
/// and with Reduce Motion on it's a still dot.
struct LEDDot: View {
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LEDDotRepresentable(mode: reduceMotion ? .still : activeState == .inactive ? .paused : .animating)
            .frame(width: 12, height: 12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct LEDDotRepresentable: NSViewRepresentable {
    let mode: LEDDotView.Mode

    func makeNSView(context: Context) -> LEDDotView {
        LEDDotView(mode: mode)
    }

    func updateNSView(_ view: LEDDotView, context: Context) {
        view.mode = mode
    }
}

final class LEDDotView: NSView {
    enum Mode {
        case animating, paused, still
    }

    private static let dotSize: CGFloat = 7
    private static let secondsPerColor = 2.0
    private static let pulseSeconds = 1.2
    private static let stillColor = NSColor(srgbRed: 0.31, green: 0.86, blue: 0.47, alpha: 1)
    /// Red, orange, yellow, green, blue, purple, pink, then back to red.
    private static let rainbow: [CGColor] = [
        (1.00, 0.27, 0.27), (1.00, 0.60, 0.20), (1.00, 0.87, 0.25), (0.31, 0.86, 0.47),
        (0.30, 0.60, 1.00), (0.67, 0.42, 1.00), (1.00, 0.42, 0.75), (1.00, 0.27, 0.27),
    ].map { NSColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1).cgColor }

    /// The dot and its glow. The glow is the layer's shadow, so it changes color with the dot.
    let dot = CALayer()

    var mode: Mode {
        didSet {
            if mode != oldValue { applyMode() }
        }
    }

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
        clipsToBounds = false
        layer?.masksToBounds = false
        dot.cornerRadius = Self.dotSize / 2
        dot.shadowOffset = .zero
        dot.shadowRadius = 3
        dot.shadowOpacity = 0.9
        dot.masksToBounds = false
        layer?.addSublayer(dot)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.frame = CGRect(
            x: (bounds.width - Self.dotSize) / 2,
            y: (bounds.height - Self.dotSize) / 2,
            width: Self.dotSize,
            height: Self.dotSize
        )
        dot.shadowPath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize), transform: nil)
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { applyMode() }
    }

    private func applyMode() {
        switch mode {
        case .animating:
            addAnimationsIfNeeded()
            resume()
        case .paused:
            addAnimationsIfNeeded()
            pause()
        case .still:
            dot.removeAllAnimations()
            resume()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.backgroundColor = Self.stillColor.cgColor
            dot.shadowColor = Self.stillColor.cgColor
            dot.opacity = 1
            CATransaction.commit()
        }
    }

    private func addAnimationsIfNeeded() {
        guard dot.animation(forKey: "pulse") == nil else { return }
        let cycle = Double(Self.rainbow.count - 1) * Self.secondsPerColor
        for keyPath in ["backgroundColor", "shadowColor"] {
            let colors = CAKeyframeAnimation(keyPath: keyPath)
            colors.values = Self.rainbow
            colors.duration = cycle
            colors.repeatCount = .infinity
            colors.isRemovedOnCompletion = false
            dot.add(colors, forKey: keyPath)
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.45
        pulse.duration = Self.pulseSeconds
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.isRemovedOnCompletion = false
        dot.add(pulse, forKey: "pulse")
    }

    /// Freezes the animation where it is, so it picks up on the same color later.
    private func pause() {
        guard dot.speed != 0 else { return }
        let now = dot.convertTime(CACurrentMediaTime(), from: nil)
        dot.speed = 0
        dot.timeOffset = now
    }

    private func resume() {
        guard dot.speed == 0 else { return }
        let pausedAt = dot.timeOffset
        dot.speed = 1
        dot.timeOffset = 0
        dot.beginTime = 0
        dot.beginTime = dot.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
    }
}
