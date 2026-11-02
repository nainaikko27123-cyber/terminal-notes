import Testing
@testable import NotesKit

@Suite struct ChompFrameTests {
    @Test func startsWithAFullRow() {
        let frame = ChompFrame(step: 0)
        #expect(frame.position == 0)
        #expect(frame.remainingDots == 1...8)
    }

    @Test func eatsOneDotPerStep() {
        #expect(ChompFrame(step: 3).remainingDots == 4...8)
        #expect(ChompFrame(step: 7).remainingDots == 8...8)
    }

    @Test func waitsOnTheEmptyRowThenRefills() {
        #expect(ChompFrame(step: 8).remainingDots == nil)
        #expect(ChompFrame(step: 9).position == 8)
        #expect(ChompFrame(step: 10).remainingDots == nil)
        #expect(ChompFrame(step: 11).position == 0)
        #expect(ChompFrame(step: 11).remainingDots == 1...8)
    }

    @Test func mouthKeepsChomping() {
        #expect(ChompFrame(step: 0).isMouthOpen)
        #expect(!ChompFrame(step: 1).isMouthOpen)
    }

    @Test func aHugeStepNumberStillWorks() {
        let frame = ChompFrame(step: 3_000_000_001)
        #expect((0...8).contains(frame.position))
    }
}
