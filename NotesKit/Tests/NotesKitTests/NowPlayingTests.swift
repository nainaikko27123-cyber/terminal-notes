import Testing
@testable import NotesKit

@Suite struct NowPlayingTests {
    @Test func readsAPlayingAnnouncement() {
        let song = NowPlaying(announcement: ["Player State": "Playing", "Name": "NORMAL", "Artist": "BTS"])
        #expect(song?.text == "NORMAL — BTS")
    }

    @Test(arguments: ["Paused", "Stopped", ""])
    func anythingElseMeansNoSong(state: String) {
        #expect(NowPlaying(announcement: ["Player State": state, "Name": "NORMAL", "Artist": "BTS"]) == nil)
    }

    @Test func aSongNeedsATitle() {
        #expect(NowPlaying(announcement: ["Player State": "Playing", "Artist": "BTS"]) == nil)
    }

    @Test func missingArtistShowsJustTheTitle() {
        #expect(NowPlaying(announcement: ["Player State": "Playing", "Name": "Podcast"])?.text == "Podcast")
    }

    @Test func readsTheAnswerToTheQuery() {
        #expect(NowPlaying(queryOutput: "playing\nWE GO UP\nBABYMONSTER\n")?.text == "WE GO UP — BABYMONSTER")
        #expect(NowPlaying(queryOutput: "") == nil)
        #expect(NowPlaying(queryOutput: "paused\nWE GO UP\nBABYMONSTER") == nil)
    }
}
