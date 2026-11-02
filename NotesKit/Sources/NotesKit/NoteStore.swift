import Foundation
import os

/// Stores each note as `<uuid>.md` in one directory.
///
/// The app and the widget run as separate processes, so every file access goes through
/// `NSFileCoordinator`. `update` reads and writes inside one coordinated block, which means
/// a pin toggled by the widget can't overwrite an edit saved by the app, or the reverse.
public struct NoteStore: Sendable {
    /// Must match the `application-groups` value in both entitlements files.
    public static let appGroupID = "group.com.naikko.notes"

    public enum StoreError: LocalizedError {
        case appGroupUnavailable(String)
        case noteNotFound(UUID)

        public var errorDescription: String? {
            switch self {
            case .appGroupUnavailable(let id):
                "Can't open the shared container for \(id). Check that this target has the App Groups capability."
            case .noteNotFound:
                "That note no longer exists."
            }
        }
    }

    private static let logger = Logger(subsystem: "com.naikko.notes", category: "NoteStore")

    public let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The store shared by the app and the widget.
    public static func shared() throws -> NoteStore {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw StoreError.appGroupUnavailable(appGroupID)
        }
        return try NoteStore(directory: container.appending(path: "Notes", directoryHint: .isDirectory))
    }

    /// All notes, pinned first, then most recently edited. Files that can't be read are skipped and logged.
    public func allNotes() throws -> [Note] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .compactMap { url -> Note? in
                guard url.pathExtension == "md", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                    return nil
                }
                do {
                    return try read(id: id)
                } catch StoreError.noteNotFound {
                    return nil
                } catch {
                    Self.logger.error("Skipping unreadable note \(id): \(error)")
                    return nil
                }
            }
            .sorted { ($0.isPinned ? 1 : 0, $0.updatedAt) > ($1.isPinned ? 1 : 0, $1.updatedAt) }
    }

    public func note(id: UUID) throws -> Note {
        try read(id: id)
    }

    @discardableResult
    public func create(body: String = "") throws -> Note {
        let note = Note(body: body)
        try coordinate(writing: url(for: note.id), options: .forReplacing) { try write(note, to: $0) }
        return note
    }

    /// Applies `change` to the latest version on disk. `updatedAt` only moves when the text changes,
    /// so pinning a note doesn't reorder it among its neighbours.
    @discardableResult
    public func update(id: UUID, _ change: (inout Note) -> Void) throws -> Note {
        try coordinate(writing: url(for: id), options: .forMerging) { url in
            let original = try load(id: id, from: url)
            var note = original
            change(&note)
            if note.body != original.body { note.updatedAt = .now }
            if note != original { try write(note, to: url) }
            return note
        }
    }

    public func delete(id: UUID) throws {
        try coordinate(writing: url(for: id), options: .forDeleting) { url in
            do {
                try FileManager.default.removeItem(at: url)
            } catch CocoaError.fileNoSuchFile {
                throw StoreError.noteNotFound(id)
            }
        }
    }

    /// Yields whenever a note is added, replaced or removed, by this process or another one.
    public func changes() -> AsyncStream<Void> {
        let path = directory.path
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else {
                Self.logger.error("Can't watch \(path) for changes")
                continuation.finish()
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .global())
            source.setEventHandler { continuation.yield() }
            source.setCancelHandler { close(descriptor) }
            continuation.onTermination = { _ in source.cancel() }
            source.resume()
        }
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).md", directoryHint: .notDirectory)
    }

    private func read(id: UUID) throws -> Note {
        var coordinationError: NSError?
        var result: Result<Note, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url(for: id), options: [], error: &coordinationError) { url in
            result = Result { try load(id: id, from: url) }
        }
        if let coordinationError { throw coordinationError }
        return try result!.get()
    }

    private func coordinate<T>(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> T) throws -> T {
        var coordinationError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) { url in
            result = Result { try body(url) }
        }
        if let coordinationError { throw coordinationError }
        return try result!.get()
    }

    private func load(id: UUID, from url: URL) throws -> Note {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let modified = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return MarkdownNoteFile.decode(text, id: id, fallbackDate: modified ?? .now)
        } catch CocoaError.fileReadNoSuchFile, CocoaError.fileNoSuchFile {
            throw StoreError.noteNotFound(id)
        }
    }

    private func write(_ note: Note, to url: URL) throws {
        try Data(MarkdownNoteFile.encode(note).utf8).write(to: url, options: .atomic)
    }
}
