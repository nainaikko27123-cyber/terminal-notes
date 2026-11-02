import NotesKit
import SwiftUI

/// A little Pac-Man eating a row of dots. It draws 4 times a second, and stops completely
/// when another app is in front or Reduce Motion is on, so it costs next to nothing.
struct ChompingDots: View {
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: TerminalPalette

    private static let stepsPerSecond = 4.0

    var body: some View {
        Group {
            if activeState == .inactive || reduceMotion {
                ChompRow(frame: ChompFrame(step: 0), palette: palette)
            } else {
                TimelineView(.periodic(from: .now, by: 1 / Self.stepsPerSecond)) { context in
                    let step = Int(context.date.timeIntervalSinceReferenceDate * Self.stepsPerSecond)
                    ChompRow(frame: ChompFrame(step: step), palette: palette)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ChompRow: View {
    let frame: ChompFrame
    let palette: TerminalPalette

    private nonisolated static let cellWidth: CGFloat = 10
    private nonisolated static let height: CGFloat = 12
    private nonisolated static let yellow = Color(red: 0.98, green: 0.84, blue: 0.3)

    var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            func center(_ cell: Int) -> CGPoint {
                CGPoint(x: (CGFloat(cell) + 0.5) * Self.cellWidth, y: middle)
            }

            if let dots = frame.remainingDots {
                for cell in dots {
                    let c = center(cell)
                    let dot = CGRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3)
                    context.fill(Path(ellipseIn: dot), with: .color(Color(nsColor: palette.dim)))
                }
            }

            let c = center(frame.position)
            var body = Path()
            if frame.isMouthOpen {
                body.move(to: c)
                body.addArc(center: c, radius: 5.5, startAngle: .degrees(35), endAngle: .degrees(325), clockwise: false)
                body.closeSubpath()
            } else {
                body.addEllipse(in: CGRect(x: c.x - 5.5, y: c.y - 5.5, width: 11, height: 11))
            }
            context.fill(body, with: .color(Self.yellow))
        }
        .frame(width: Self.cellWidth * CGFloat(ChompFrame.dotCount + 1), height: Self.height)
    }
}
