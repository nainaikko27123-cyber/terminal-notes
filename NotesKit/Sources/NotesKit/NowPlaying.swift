import Foundation

/// The song Spotify is playing right now.
public struct NowPlaying: Equatable, Sendable {
    public let title: String
    public let artist: String

    public var text: String {
        artist.isEmpty ? title : "\(title) — \(artist)"
    }

    /// Reads Spotify's "playback changed" announcement. Nil unless a song is actually playing.
    public init?(announcement info: [AnyHashable: Any]) {
        self.init(
            state: info["Player State"] as? String ?? "",
            title: info["Name"] as? String ?? "",
            artist: info["Artist"] as? String ?? ""
        )
    }

    /// Reads the answer to `NowPlaying.query`: the state, title and artist, one per line.
    public init?(queryOutput: String) {
        let lines = queryOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 3 else { return nil }
        self.init(state: lines[0], title: lines[1], artist: lines[2])
    }

    private init?(state: String, title: String, artist: String) {
        guard state.lowercased() == "playing", !title.isEmpty else { return nil }
        self.title = title
        self.artist = artist
    }

    /// AppleScript that asks Spotify what's playing. Only run it when Spotify is already open,
    /// because asking would otherwise launch it.
    public static let query = """
    with timeout of 3 seconds
    tell application "Spotify"
    if player state is playing then
    return "playing" & linefeed & (name of current track) & linefeed & (artist of current track)
    end if
    end tell
    end timeout
    """
}
