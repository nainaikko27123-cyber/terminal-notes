import AppKit
import NotesKit
import Observation

/// Keeps track of Spotify's current song. Spotify announces every change itself, so nothing
/// here runs between songs. Spotify is only asked directly once, at launch.
@MainActor
@Observable
final class NowPlayingMonitor: NSObject {
    private(set) var song: NowPlaying?

    private static let spotifyID = "com.spotify.client"

    override init() {
        super.init()
        // Deliver straight away, so the song stays right while another app is in front.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playbackChanged),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appQuit),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc private func playbackChanged(_ notification: Notification) {
        song = notification.userInfo.flatMap(NowPlaying.init(announcement:))
    }

    @objc private func appQuit(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        if app?.bundleIdentifier == Self.spotifyID { song = nil }
    }

    /// Finds out what's already playing when the app opens. If Spotify isn't open, it stays closed.
    func checkCurrentSong() async {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: Self.spotifyID).isEmpty else { return }
        let output = await Task.detached { Self.runQuery() }.value
        if song == nil, let output { song = NowPlaying(queryOutput: output) }
    }

    /// Runs separately from the app, so a slow answer or a permission prompt can't freeze the window.
    private nonisolated static func runQuery() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", NowPlaying.query]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
    }
}
