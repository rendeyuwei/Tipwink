import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--restore-on-owner-exit" {
    if let owner = UUID(uuidString: arguments[1]) {
        DesktopThemeEngine.restoreAfterOwnerExit(owner: owner)
    }
    exit(0)
}
let mode = arguments[0]
let output = URL(fileURLWithPath: arguments[1])
let settings = ThemeSettings(theme: .nightCrosshair)

final class Probe: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var engine: DesktopThemeEngine?
    private var result: [String] = []
    private let cursors: [NSCursor] = [.arrow, .pointingHand, .iBeam]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
                              styleMask: [.titled], backing: .buffered, defer: false)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            result.append("foreground=\(NSApp.isActive)")
            guard NSApp.isActive else { finish("No active GUI session"); return }
            if mode == "--owner" {
                owner()
            } else {
                witness(index: 0)
            }
        }
    }

    private func owner() {
        let engine = DesktopThemeEngine()
        self.engine = engine
        do {
            try engine.apply(settings)
            let registered = try WindowServer().read(WindowServer.arrowName)
            result.append("registered-arrow size=\(registered?.size ?? .zero) hotspot=\(registered?.hotSpot ?? .zero)")
            result.append("applied=true")
            writeResult()
            waitForStop(until: Date().addingTimeInterval(40))
        } catch {
            finish(error.localizedDescription)
        }
    }

    private func waitForStop(until deadline: Date) {
        if FileManager.default.fileExists(atPath: arguments[2]) || Date() >= deadline {
            NSApp.terminate(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.waitForStop(until: deadline)
        }
    }

    private func witness(index: Int) {
        let roles = CursorRole.allCases
        guard index < roles.count else { finish(); return }
        cursors[index].set()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            let role = roles[index]
            let live = NSCursor.currentSystem
            let found = live?.image.size == settings.imageSize && live?.hotSpot == settings.hotSpot(for: role)
            result.append("\(role.rawValue) size=\(live?.image.size ?? .zero) hotspot=\(live?.hotSpot ?? .zero) matches=\(found)")
            witness(index: index + 1)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        do { try engine?.restore() } catch { print("Restore:", error.localizedDescription) }
    }

    private func writeResult() {
        try? result.joined(separator: "\n").appending("\n").write(to: output, atomically: true, encoding: .utf8)
    }

    private func finish(_ error: String? = nil) {
        if let error { result.append("error=\(error)") }
        writeResult()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let probe = Probe()
app.setActivationPolicy(.regular)
app.delegate = probe
app.run()
