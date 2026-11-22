import AppKit
import Combine
import Sparkle
import SwiftUI

@MainActor
final class SoftwareUpdates: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false

    private let controller: SPUStandardUpdaterController?

    var isConfigured: Bool { controller != nil }

    init() {
        guard Self.hasUpdateConfiguration else {
            controller = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
    }

    func checkForUpdates() {
        NSApp.activate()
        if let controller {
            controller.checkForUpdates(nil)
        } else {
            let alert = NSAlert()
            alert.messageText = String(localized: "This version can’t check for updates online.")
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                alert.informativeText = String(localized: "You’re running version \(version).")
            }
            alert.addButton(withTitle: String(localized: "OK"))
            alert.runModal()
        }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    private static var hasUpdateConfiguration: Bool {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed),
              let host = url.host, !host.isEmpty,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return false }

        #if DEBUG
        if url.scheme == "http", host == "localhost" { return true }
        #endif
        return url.scheme == "https"
    }
}

struct UpdateMenuItems: View {
    @ObservedObject var updates: SoftwareUpdates

    var body: some View {
        Button("Check for Updates…") { updates.checkForUpdates() }
            .disabled(updates.isConfigured && !updates.canCheckForUpdates)

        if updates.isConfigured {
            Toggle(
                "Automatically Check for Updates",
                isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.setAutomaticChecks($0) }
                )
            )
        }
    }
}
