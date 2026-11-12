import AppKit

/// Selects a cached, connection-local expression only while a cat is the visible cursor.
@MainActor
final class DesktopCatBlink {
    private struct CursorImage {
        let size: CGSize
        let hotSpot: CGPoint
        let bitmaps: [Bitmap]

        struct Bitmap {
            let width: Int
            let height: Int
            let pixels: CFData

            init?(_ image: CGImage) {
                guard let pixels = image.dataProvider?.data else { return nil }
                width = image.width
                height = image.height
                self.pixels = pixels
            }
        }

        init(_ frames: CursorFrames) {
            size = frames.size
            hotSpot = frames.hotSpot
            bitmaps = frames.images.compactMap(Bitmap.init)
        }

        static func hasGeometry(_ cursor: NSCursor, size: CGSize, hotSpot: CGPoint) -> Bool {
            let tolerance: CGFloat = 0.01
            return cursor.image.size == size
                && abs(cursor.hotSpot.x - hotSpot.x) < tolerance
                && abs(cursor.hotSpot.y - hotSpot.y) < tolerance
        }

        func matches(_ cursor: NSCursor) -> Bool {
            guard Self.hasGeometry(cursor, size: size, hotSpot: hotSpot),
                  let image = cursor.image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let visible = Bitmap(image) else { return false }
            return bitmaps.contains {
                $0.width == visible.width && $0.height == visible.height && CFEqual($0.pixels, visible.pixels)
            }
        }
    }

    private struct Slot {
        let openName: String
        let closedName: String
        let open: CursorImage
        let closed: CursorImage
    }

    private let server: WindowServer
    private var settings: ThemeSettings
    private var slots: [CursorRole: Slot] = [:]
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var active: Slot?
    private var timer: Timer?

    init(server: WindowServer, settings: ThemeSettings) {
        self.server = server
        self.settings = settings

        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
            return event
        }
    }

    private func handle(_ event: NSEvent.EventType) {
        if event == .leftMouseDown {
            blink()
        } else if active != nil {
            // Some apps select the normal cursor again on mouse-up. Complete the
            // current blink only if that same cursor is still under the pointer.
            DispatchQueue.main.async { [weak self] in
                guard let self, let active, let cursor = NSCursor.currentSystem,
                      active.open.matches(cursor) else { return }
                try? server.activate(active.closedName)
            }
        }
    }

    func blink() {
        guard let cursor = NSCursor.currentSystem else { return }
        if let active, active.closed.matches(cursor) {
            scheduleEnd(for: active)
            return
        }
        guard let role = [CursorRole.arrow, .link].first(where: {
            CursorImage.hasGeometry(cursor, size: settings.imageSize, hotSpot: settings.hotSpot(for: $0))
        }) else { return }
        let slot: Slot
        if let prepared = slots[role] {
            guard prepared.open.matches(cursor) else { return }
            slot = prepared
        } else {
            guard let prepared = prepareSlot(for: role, visible: cursor) else { return }
            slots[role] = prepared
            slot = prepared
        }

        do {
            try server.activate(slot.closedName)
            scheduleEnd(for: slot)
        } catch {
            // The system can drop a connection-local cursor across a session change.
        }
    }

    private func prepareSlot(for role: CursorRole, visible cursor: NSCursor) -> Slot? {
        // Build the expression for the first click on this role, avoiding extra
        // bitmap registrations on every tick of a slider or color picker.
        let openName = role == .arrow ? WindowServer.arrowName : WindowServer.linkName
        let closedName = "studio.papercursor.blink.\(role.rawValue)"
        do {
            guard let openFrames = try server.read(openName) else { return nil }
            let open = CursorImage(openFrames)
            guard open.matches(cursor) else { return nil }
            let expression = try CursorFrames(settings: settings, role: role, expression: .blink)
            try server.set(closedName, to: expression, globally: false)
            guard let closed = try server.read(closedName) else {
                throw DesktopCursorError.unavailable
            }
            return Slot(openName: openName, closedName: closedName, open: open, closed: CursorImage(closed))
        } catch {
            try? server.set(closedName, to: nil, globally: false)
            return nil
        }
    }

    func update(_ settings: ThemeSettings) {
        clearPreparedFrames()
        self.settings = settings
    }

    func stop() {
        clearPreparedFrames()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    private func clearPreparedFrames() {
        finish()
        for slot in slots.values { try? server.set(slot.closedName, to: nil, globally: false) }
        slots.removeAll()
    }

    private func scheduleEnd(for slot: Slot) {
        active = slot
        timer?.invalidate()
        let timer = Timer(timeInterval: CatExpression.blinkDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        defer { active = nil }
        // Another app may already have selected a text, resize, or drag cursor.
        guard let active, let cursor = NSCursor.currentSystem, active.closed.matches(cursor) else { return }
        try? server.activate(active.openName)
    }
}
