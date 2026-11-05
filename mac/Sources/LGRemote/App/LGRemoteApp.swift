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
            // Template symbol: follows the menu bar's light/dark appearance like system icons.
            Image(systemName: remote.isConnected ? "av.remote.fill" : "av.remote")
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
