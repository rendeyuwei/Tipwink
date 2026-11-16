import AppKit

enum SystemPointerColors {
    static func isCustomized() -> Bool {
        let domain = "com.apple.universalaccess" as CFString
        let fill = CFPreferencesCopyAppValue("cursorFill" as CFString, domain)
        let outline = CFPreferencesCopyAppValue("cursorOutline" as CFString, domain)
        return differsFromDefault(fill, component: 0) || differsFromDefault(outline, component: 1)
    }

    private static func differsFromDefault(_ value: CFPropertyList?, component: Double) -> Bool {
        // The default black and white can also be stored as explicit RGBA values.
        guard let value else { return false }
        guard let color = value as? [String: Double] else { return true }
        return color["red"] != component
            || color["green"] != component
            || color["blue"] != component
            || color["alpha"] != 1
    }

    static func openSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display") else { return false }
        return NSWorkspace.shared.open(url)
    }
}
