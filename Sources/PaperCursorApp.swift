import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ThemeLibrary {
    static let shared = ThemeLibrary()

    private let desktop = DesktopThemeEngine()
    private let preferencesKey = "theme-settings"
    @ObservationIgnored private var settingsTimer: Timer?

    var settings: ThemeSettings {
        didSet {
            if settings != oldValue { scheduleSettingsUpdate() }
        }
    }

    private(set) var applied: ThemeSettings?
    private(set) var needsRecovery = false
    private(set) var message: String?

    private var selectionIsApplied: Bool {
        applied?.hasSameAppearance(as: settings) == true
    }

    var canApplyManually: Bool {
        applied == nil || (message != nil && !selectionIsApplied)
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           var saved = try? JSONDecoder().decode(ThemeSettings.self, from: data), saved.scale.isFinite {
            saved.scale = min(1.5, max(0.75, saved.scale))
            settings = saved
        } else {
            settings = ThemeSettings()
        }

        if desktop.needsRecovery { restore() }
    }

    func select(_ theme: CursorTheme) {
        settings.theme = theme
        if !needsRecovery { message = nil }
    }

    private func scheduleSettingsUpdate() {
        guard settingsTimer == nil else { return }
        // Use the newest value at most once per tick, including during slider tracking.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitSettingsUpdate() }
        }
        settingsTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func commitSettingsUpdate() {
        settingsTimer = nil
        saveSettings()
        guard applied != nil, !needsRecovery, !selectionIsApplied else { return }
        applyToDesktop()
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }

    private func cancelPendingUpdate() {
        settingsTimer?.invalidate()
        settingsTimer = nil
        saveSettings()
    }

    func apply() {
        cancelPendingUpdate()
        if !selectionIsApplied || needsRecovery { applyToDesktop() }
    }

    private func applyToDesktop() {
        do {
            try desktop.apply(settings)
            applied = settings
            needsRecovery = false
            message = nil
        } catch {
            if case DesktopCursorError.restoreRequired = error {
                applied = nil
            }
            if applied == nil { needsRecovery = desktop.needsRecovery }
            message = error.localizedDescription
        }
    }

    func restore() {
        cancelPendingUpdate()
        do {
            try desktop.restore()
            applied = nil
            needsRecovery = false
            message = nil
        } catch {
            needsRecovery = desktop.needsRecovery
            message = error.localizedDescription
        }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        ThemeLibrary.shared.restore()
    }
}

struct PaperCursorApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @State private var library = ThemeLibrary.shared

    var body: some Scene {
        Window("纸片光标", id: "library") {
            LibraryView(library: library)
        }
        .defaultSize(width: 884, height: 565)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("光标") {
                Button("应用主题") { library.apply() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!library.canApplyManually)
                Button("恢复原光标") { library.restore() }
                    .keyboardShortcut("0", modifiers: [.command, .option])
                    .disabled(library.applied == nil && !library.needsRecovery)
            }
        }

        MenuBarExtra("纸片光标", systemImage: "cursorarrow.rays") {
            LibraryMenu(library: library)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct LibraryMenu: View {
    @Environment(\.openWindow) private var openWindow
    let library: ThemeLibrary

    var body: some View {
        Button("打开主题库") {
            openWindow(id: "library")
            NSApp.activate()
        }
        Divider()
        ForEach(CursorTheme.allCases) { theme in
            Button {
                library.select(theme)
                library.apply()
            } label: {
                if library.applied?.theme == theme {
                    Label(theme.name, systemImage: "checkmark")
                } else {
                    Text(theme.name)
                }
            }
        }
        if let message = library.message {
            Text(message)
        }
        Divider()
        Button("恢复原光标") { library.restore() }
            .disabled(library.applied == nil && !library.needsRecovery)
        Button("退出纸片光标") { NSApp.terminate(nil) }
    }
}
