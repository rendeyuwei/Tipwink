import AppKit
import Darwin
import Foundation

@MainActor
final class DesktopThemeEngine {
    private struct Entry {
        let name: String
        let role: CursorRole
    }

    private struct Original {
        let name: String
        let frames: CursorFrames?
    }

    private struct Recovery: Codable {
        struct Entry: Codable {
            let name: String
            let image: SavedCursor?
        }
        let session: String
        let owner: UUID?
        let entries: [Entry]
    }

    private static let entries: [Entry] = [
        Entry(name: "com.apple.coregraphics.Arrow", role: .arrow),
        Entry(name: WindowServer.arrowName, role: .arrow),
        Entry(name: "com.apple.cursor.0", role: .arrow),
        Entry(name: WindowServer.linkName, role: .link),
        Entry(name: "com.apple.coregraphics.IBeam", role: .text),
        Entry(name: "com.apple.coregraphics.IBeamS", role: .text),
        Entry(name: "com.apple.coregraphics.IBeamXOR", role: .text),
        Entry(name: "com.apple.cursor.1", role: .text)
    ]

    private let directory: URL
    private var recoveryURL: URL { directory.appending(path: "recovery.json") }
    private var inMemoryOriginals: [Original]?
    private var appliedArtwork: [CursorRole: CursorFrames]?
    private var lockDescriptor: Int32 = -1
    private var watchdog: Process?
    private var ownerPipe: Pipe?
    private var catBlink: DesktopCatBlink?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appending(path: "PaperCursor", directoryHint: .isDirectory)
    }

    var needsRecovery: Bool { FileManager.default.fileExists(atPath: recoveryURL.path) }

    func apply(_ settings: ThemeSettings) throws {
        let server = try WindowServer()
        let session = try Self.sessionIdentifier()
        try acquireLock()
        defer { releaseWhenIdle() }
        if needsRecovery && inMemoryOriginals == nil {
            try recover(using: server, in: session)
        }

        let current: [Original]
        if let appliedArtwork {
            // The engine owns these registrations until it releases the session lock.
            current = Self.entries.map { Original(name: $0.name, frames: appliedArtwork[$0.role]) }
        } else {
            current = try Self.entries.map { entry in
                Original(name: entry.name, frames: try server.read(entry.name))
            }
            guard current.contains(where: { $0.name == WindowServer.arrowName && $0.frames != nil }) else {
                throw DesktopCursorError.unavailable
            }
        }
        let artwork = try Dictionary(uniqueKeysWithValues: CursorRole.allCases.map {
            ($0, try CursorFrames(settings: settings, role: $0))
        })
        let firstApplication = inMemoryOriginals == nil
        if firstApplication {
            let owner = UUID()
            try startWatchdog(owner: owner)
            let recovery = try Recovery(session: session, owner: owner, entries: current.map { original in
                Recovery.Entry(name: original.name, image: try original.frames.map(SavedCursor.init))
            })
            try JSONEncoder().encode(recovery).write(to: recoveryURL, options: .atomic)
            inMemoryOriginals = current
        }

        do {
            for entry in Self.entries {
                guard let frames = artwork[entry.role] else { throw DesktopCursorError.artwork }
                try server.set(entry.name, to: frames)
            }
            try server.refreshArrow()
        } catch let applicationError {
            do {
                try restore(current, using: server)
                if firstApplication { try discardRecovery() }
            } catch {
                // A partial rollback keeps the journal available to Restore and the watchdog.
                appliedArtwork = nil
                stopCatBlink()
                throw DesktopCursorError.restoreRequired
            }
            throw applicationError
        }

        appliedArtwork = artwork
        if settings.theme == .paperCat {
            if let catBlink {
                catBlink.update(settings)
            } else {
                catBlink = DesktopCatBlink(server: server, settings: settings)
            }
        } else {
            stopCatBlink()
        }
    }

    func restore() throws {
        guard needsRecovery else { return }
        try acquireLock()
        defer { releaseWhenIdle() }
        stopCatBlink()
        let server = try WindowServer()
        try recover(using: server, in: Self.sessionIdentifier())
    }

    private func stopCatBlink() {
        catBlink?.stop()
        catBlink = nil
    }

    private func recover(using server: WindowServer, in session: String) throws {
        if let inMemoryOriginals {
            try restore(inMemoryOriginals, using: server)
            try discardRecovery()
            return
        }
        let recovery = try readRecovery()
        guard recovery.session == session else {
            try discardRecovery()
            return
        }
        guard recovery.entries.map(\.name) == Self.entries.map(\.name) else {
            throw DesktopCursorError.recoveryData
        }
        let originals = try recovery.entries.map {
            Original(name: $0.name, frames: try $0.image?.decode())
        }
        try restore(originals, using: server)
        try discardRecovery()
    }

    private func restore(_ originals: [Original], using server: WindowServer) throws {
        var firstError: (any Error)?
        for original in originals {
            do {
                try server.set(original.name, to: original.frames)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
        try server.refreshArrow()
    }

    private func readRecovery() throws -> Recovery {
        try JSONDecoder().decode(Recovery.self, from: Data(contentsOf: recoveryURL))
    }

    private func discardRecovery() throws {
        try FileManager.default.removeItem(at: recoveryURL)
        inMemoryOriginals = nil
        appliedArtwork = nil
    }

    private func acquireLock(wait: Bool = false) throws {
        guard lockDescriptor < 0 else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: "session.lock").path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw DesktopCursorError.recoveryData }
        guard flock(descriptor, wait ? LOCK_EX : LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            throw DesktopCursorError.busy
        }
        lockDescriptor = descriptor
    }

    private func releaseWhenIdle() {
        guard inMemoryOriginals == nil, lockDescriptor >= 0 else { return }
        try? ownerPipe?.fileHandleForWriting.close()
        ownerPipe = nil
        watchdog = nil
        Darwin.close(lockDescriptor)
        lockDescriptor = -1
    }

    private func startWatchdog(owner: UUID) throws {
        guard let executable = Bundle.main.executableURL else { throw DesktopCursorError.unavailable }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = ["--restore-on-owner-exit", owner.uuidString]
        process.standardInput = pipe
        try process.run()
        watchdog = process
        ownerPipe = pipe
    }

    static func restoreAfterOwnerExit(owner: UUID) {
        // EOF is delivered by the kernel on both normal termination and a crash.
        _ = FileHandle.standardInput.readDataToEndOfFile()
        let engine = DesktopThemeEngine()
        guard (try? engine.readRecovery().owner) == owner else { return }
        do {
            try engine.acquireLock(wait: true)
            defer { engine.releaseWhenIdle() }
            guard (try? engine.readRecovery().owner) == owner else { return }
            try engine.restore()
        } catch {
            fputs("Tipwink recovery will be retried on the next launch.\n", stderr)
        }
    }

    private static func sessionIdentifier() throws -> String {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let identifier = session["CGSSessionUniqueSessionUUID"] as? String,
              !identifier.isEmpty else {
            throw DesktopCursorError.unavailable
        }
        return identifier
    }
}
