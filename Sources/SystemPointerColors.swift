import AppKit

enum SystemPointerColors {
    static func isCustomized() -> Bool {
        let domain = "com.apple.universalaccess" as CFString
        // Reset Colors removes the overrides. Manually picking black and white still sets them.
        return ["cursorFill", "cursorOutline"].contains { key in
            CFPreferencesCopyAppValue(key as CFString, domain) != nil
        }
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display") else { return }
        NSWorkspace.shared.open(url)
    }
}
