import Foundation

/// One moment of the tab bar's little chomping animation. Worked out from a step number
/// alone, so nothing has to be stored or updated between frames.
public struct ChompFrame: Equatable, Sendable {
    public static let dotCount = 8
    /// Steps to wait on the empty row before it refills.
    private static let pauseSteps = 2

    /// Which cell Pac-Man is in: 0 is the start, and dots sit in cells 1 up to `dotCount`.
    public let position: Int
    public let isMouthOpen: Bool

    public init(step: Int) {
        let cycle = Self.dotCount + 1 + Self.pauseSteps
        let wrapped = ((step % cycle) + cycle) % cycle
        position = min(wrapped, Self.dotCount)
        isMouthOpen = step.isMultiple(of: 2)
    }

    /// The cells that still have a dot.
    public var remainingDots: ClosedRange<Int>? {
        position < Self.dotCount ? (position + 1)...Self.dotCount : nil
    }
}
