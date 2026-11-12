import Foundation

let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "--restore-on-owner-exit" {
    if let value = arguments.dropFirst().first, let owner = UUID(uuidString: value) {
        DesktopThemeEngine.restoreAfterOwnerExit(owner: owner)
    }
} else {
    PaperCursorApp.main()
}
