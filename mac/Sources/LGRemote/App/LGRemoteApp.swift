import LGRemoteCore
import SwiftUI

@main
struct LGRemoteApp: App {
    @State private var remote = RemoteController(
        connector: WebOSConnector(),
        discovery: SSDPDiscovery(),
        wakeOnLan: WakeOnLanSender(),
        macResolver: ARPMacResolver(),
        store: JSONConfigStore.standard()
    )
    @State private var started = false

    var body: some Scene {
        MenuBarExtra {
            RemotePanel()
                .environment(remote)
        } label: {
            // Template image of the app's mark: the tally bar appears only while connected.
            Image(nsImage: MenuBarIcon.image(live: remote.isConnected))
                .accessibilityLabel("LG Remote")
                .task {
                    // The label exists from launch, so this connects before the panel is opened.
                    guard !started else { return }
                    started = true
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["LGREMOTE_PREVIEW"] != nil {
                        return await PreviewHarness.openIfRequested()
                    }
                    #endif
                    await remote.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
