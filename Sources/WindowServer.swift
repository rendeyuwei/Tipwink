import AppKit
import Darwin
import ImageIO
import UniformTypeIdentifiers

struct CursorFrames {
    var size: CGSize
    var hotSpot: CGPoint
    var frameCount: UInt
    var duration: CGFloat
    var images: [CGImage]

    init(settings: ThemeSettings, role: CursorRole, expression: CatExpression = .open) throws {
        size = settings.imageSize
        hotSpot = settings.hotSpot(for: role)
        frameCount = 1
        duration = 0
        let densities = [1, 2, 5, 10]
        images = densities.compactMap {
            CursorArtwork.bitmap(settings, role: role, expression: expression, pixelsPerPoint: $0)
        }
        guard images.count == densities.count else { throw DesktopCursorError.artwork }
    }

    init(size: CGSize, hotSpot: CGPoint, frameCount: UInt, duration: CGFloat, images: [CGImage]) {
        self.size = size
        self.hotSpot = hotSpot
        self.frameCount = frameCount
        self.duration = duration
        self.images = images
    }
}

enum DesktopCursorError: LocalizedError {
    case unavailable
    case busy
    case artwork
    case recoveryData
    case restoreRequired
    case readCursor(Int32)
    case removeCursor(Int32)
    case registerCursor(Int32)
    case refreshCursor(Int32)
    case finishRefreshingCursor(Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            String(localized: "Desktop themes are unavailable on this Mac. You can still try them in the preview.")
        case .busy:
            String(localized: "Another copy of Tipwink is restoring the cursor. Try again in a moment.")
        case .artwork:
            String(localized: "Couldn’t create the cursor image. Try again.")
        case .recoveryData:
            String(localized: "Couldn’t read the original cursor backup. Applying desktop themes is paused.")
        case .restoreRequired:
            String(localized: "The theme was only partially applied. Restore the original cursor before trying again.")
        case let .readCursor(code):
            String(localized: "The system couldn’t read the cursor (\(code)).")
        case let .removeCursor(code):
            String(localized: "The system couldn’t remove the cursor (\(code)).")
        case let .registerCursor(code):
            String(localized: "The system couldn’t register the cursor (\(code)).")
        case let .refreshCursor(code):
            String(localized: "The system couldn’t refresh the cursor (\(code)).")
        case let .finishRefreshingCursor(code):
            String(localized: "The system couldn’t finish refreshing the cursor (\(code)).")
        }
    }
}

/// The WindowServer ABI is private. All symbol lookup and numeric status codes stay here.
struct WindowServer {
    static let arrowName = "com.apple.coregraphics.ArrowS"
    static let linkName = "com.apple.cursor.13"

    private typealias Connection = @convention(c) () -> Int32
    private typealias Copy = @convention(c) (
        Int32, UnsafePointer<CChar>, UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<UInt>, UnsafeMutablePointer<CGFloat>, UnsafeMutablePointer<Unmanaged<CFArray>?>
    ) -> Int32
    private typealias Register = @convention(c) (
        Int32, UnsafePointer<CChar>, Bool, Bool, CGSize, CGPoint, UInt, CGFloat, CFArray,
        UnsafeMutablePointer<Int32>
    ) -> Int32
    private typealias Remove = @convention(c) (Int32, UnsafePointer<CChar>, Bool) -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    private typealias Select = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> Int32

    private let connection: Int32
    private let copy: Copy
    private let register: Register
    private let remove: Remove
    private let select: Select
    private let setProperty: SetProperty
    private static let graphics = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
    private static let cursorNotFound: Int32 = 1007

    init() throws {
        guard let library = Self.graphics,
              let connectionAddress = dlsym(library, "CGSMainConnectionID"),
              let copyAddress = dlsym(library, "CGSCopyRegisteredCursorImages"),
              let registerAddress = dlsym(library, "CGSRegisterCursorWithImages"),
              let removeAddress = dlsym(library, "CGSRemoveRegisteredCursor"),
              let selectAddress = dlsym(library, "CGSSetRegisteredCursor"),
              let propertyAddress = dlsym(library, "CGSSetConnectionProperty") else {
            throw DesktopCursorError.unavailable
        }
        connection = unsafeBitCast(connectionAddress, to: Connection.self)()
        guard connection > 0 else { throw DesktopCursorError.unavailable }
        copy = unsafeBitCast(copyAddress, to: Copy.self)
        register = unsafeBitCast(registerAddress, to: Register.self)
        remove = unsafeBitCast(removeAddress, to: Remove.self)
        select = unsafeBitCast(selectAddress, to: Select.self)
        setProperty = unsafeBitCast(propertyAddress, to: SetProperty.self)
    }

    func read(_ name: String) throws -> CursorFrames? {
        var size = CGSize.zero
        var hotSpot = CGPoint.zero
        var frameCount: UInt = 0
        var duration: CGFloat = 0
        var images: Unmanaged<CFArray>?
        let status = copy(connection, name, &size, &hotSpot, &frameCount, &duration, &images)
        let representations = images?.takeRetainedValue() as? [CGImage]
        if status == Self.cursorNotFound { return nil }
        guard status == 0 else { throw DesktopCursorError.readCursor(status) }
        guard let representations, !representations.isEmpty, size.width > 0, size.height > 0 else {
            throw DesktopCursorError.recoveryData
        }
        return CursorFrames(size: size, hotSpot: hotSpot, frameCount: frameCount,
                            duration: duration, images: representations)
    }

    func set(_ name: String, to value: CursorFrames?, globally: Bool = true) throws {
        let status: Int32
        if let value {
            var seed: Int32 = 0
            // The engine selects the visible cursor after updating the entire set.
            status = register(connection, name, globally, false, value.size, value.hotSpot,
                              value.frameCount, value.duration, value.images as CFArray, &seed)
        } else {
            status = remove(connection, name, globally)
            if status == Self.cursorNotFound { return }
        }
        guard status == 0 else {
            throw value == nil ? DesktopCursorError.removeCursor(status) : DesktopCursorError.registerCursor(status)
        }
    }

    func refreshArrow() throws {
        try activate(Self.arrowName)
    }

    func activate(_ name: String) throws {
        // Scope the connection property to one selection, including when invoked
        // from the menu bar or recovery process while another app has focus.
        let key = "SetsCursorInBackground" as CFString
        let enable = setProperty(connection, connection, key, kCFBooleanTrue)
        guard enable == 0 else { throw DesktopCursorError.refreshCursor(enable) }
        var seed: Int32 = 0
        let selected = select(connection, name, &seed)
        let reset = setProperty(connection, connection, key, kCFBooleanFalse)
        guard selected == 0 else { throw DesktopCursorError.refreshCursor(selected) }
        guard reset == 0 else { throw DesktopCursorError.finishRefreshingCursor(reset) }
    }

}

struct SavedCursor: Codable {
    var size: CGSize
    var hotSpot: CGPoint
    var frameCount: UInt
    var duration: CGFloat
    var pngs: [Data]

    init(_ frames: CursorFrames) throws {
        size = frames.size
        hotSpot = frames.hotSpot
        frameCount = frames.frameCount
        duration = frames.duration
        pngs = try frames.images.map { image in
            let bytes = NSMutableData()
            guard let encoder = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)
            else { throw DesktopCursorError.recoveryData }
            CGImageDestinationAddImage(encoder, image, nil)
            guard CGImageDestinationFinalize(encoder) else { throw DesktopCursorError.recoveryData }
            return bytes as Data
        }
    }

    func decode() throws -> CursorFrames {
        let images = try pngs.map { bytes in
            guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw DesktopCursorError.recoveryData }
            return image
        }
        guard !images.isEmpty else { throw DesktopCursorError.recoveryData }
        return CursorFrames(size: size, hotSpot: hotSpot, frameCount: frameCount, duration: duration, images: images)
    }
}
