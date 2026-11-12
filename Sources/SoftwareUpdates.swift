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
            alert.messageText = "此版本无法在线检查更新"
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                alert.informativeText = "当前版本为 \(version)。"
            }
            alert.addButton(withTitle: "好")
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
        Button("检查更新…") { updates.checkForUpdates() }
            .disabled(updates.isConfigured && !updates.canCheckForUpdates)

        if updates.isConfigured {
            Toggle(
                "自动检查更新",
                isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.setAutomaticChecks($0) }
                )
            )
        }
    }
}
