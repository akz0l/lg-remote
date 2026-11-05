#if DEBUG
import AppKit
import LGRemoteCore
import SwiftUI

/// Debug-only: `LGREMOTE_PREVIEW=connected|unreachable|setup|pin` opens the panel in a window
/// backed by a simulated TV, so every state can be inspected and captured without hardware.
@MainActor
enum PreviewHarness {
    private static var window: NSWindow?

    static func openIfRequested() async {
        let env = ProcessInfo.processInfo.environment
        guard let scenario = env["LGREMOTE_PREVIEW"] else { return }
        if env["LGREMOTE_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        if env["LGREMOTE_APPEARANCE"] == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let paired = scenario == "connected" || scenario == "unreachable"
        let config = paired
            ? TVConfig(host: "192.168.40.118", clientKey: "preview", mac: "64:cb:e9:f8:57:ac",
                       appIds: ["youtube": "youtube.leanback.v4", "netflix": "netflix"],
                       hdmiMap: ["1": "HDMI_1", "2": "HDMI_2", "3": "HDMI_3", "4": "HDMI_4"])
            : TVConfig()
        let controller = RemoteController(
            connector: PreviewConnector(online: scenario != "unreachable"),
            discovery: PreviewDiscovery(),
            wakeOnLan: PreviewWake(),
            macResolver: PreviewMac(),
            store: PreviewStore(config: config))
        if scenario == "pin" { await controller.discover() } else { await controller.start() }

        let host = NSHostingView(rootView: RemotePanel().environment(controller))
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "LGRemotePreview-\(scenario)"
        window.contentView = effect
        window.setContentSize(host.fittingSize)
        window.center()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

private actor PreviewSession: TVSession {
    func press(_ button: RemoteButton) async throws {}
    func volumeUp() async throws {}
    func volumeDown() async throws {}
    func powerOff() async throws {}
    func powerOn() async throws {}
    func launchApp(id: String) async throws {}
    func switchInput(id: String) async throws {}
    func listApps() async throws -> [TVApp] { [] }
    func listInputs() async throws -> [TVInput] { [] }
    func foregroundAppId() async throws -> String? { "com.webos.app.hdmi2" }
    func waitUntilClosed() async { await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in } }
    func close() async {}
}

private struct PreviewPairing: PinPairing {
    func submit(pin: String) async throws -> String { "preview" }
    func cancel() async {}
}

private struct PreviewConnector: TVConnector {
    let online: Bool
    func connect(host: String, clientKey: String) async throws -> any TVSession {
        guard online else { throw SSAPError.timeout }
        return PreviewSession()
    }
    func beginPinPairing(host: String) async throws -> any PinPairing { PreviewPairing() }
}

private struct PreviewDiscovery: TVDiscovery {
    func discover() async -> [String] { ["192.168.40.118"] }
}

private struct PreviewWake: WakeOnLan {
    func wake(mac: String) throws {}
}

private struct PreviewMac: MacAddressResolver {
    func macAddress(for host: String) async -> String? { nil }
}

private final class PreviewStore: ConfigStore, @unchecked Sendable {
    var config: TVConfig
    init(config: TVConfig) { self.config = config }
    func load() -> TVConfig { config }
    func save(_ config: TVConfig) throws { self.config = config }
}
#endif
