import Foundation
import Testing
@testable import LGRemoteCore

// MARK: Fakes

actor FakeSession: TVSession {
    var calls: [String] = []
    var apps: [TVApp] = [TVApp(id: "youtube.leanback.v4", title: "YouTube")]
    var inputs: [TVInput] = [TVInput(id: "HDMI_2", label: "HDMI 2")]
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    private var closed = false

    func press(_ button: RemoteButton) async throws { calls.append("press:\(button.rawValue)") }
    func volumeUp() async throws { calls.append("volumeUp") }
    func volumeDown() async throws { calls.append("volumeDown") }
    func powerOff() async throws { calls.append("powerOff") }
    func powerOn() async throws { calls.append("powerOn") }
    func launchApp(id: String) async throws { calls.append("launch:\(id)") }
    func switchInput(id: String) async throws { calls.append("input:\(id)") }
    func listApps() async throws -> [TVApp] { apps }
    func listInputs() async throws -> [TVInput] { inputs }
    var foreground: String? = "com.webos.app.hdmi2"
    func foregroundAppId() async throws -> String? { foreground }
    func waitUntilClosed() async {
        if closed { return }
        await withCheckedContinuation { closeWaiters.append($0) }
    }
    func close() async {
        closed = true
        closeWaiters.forEach { $0.resume() }
        closeWaiters.removeAll()
    }
}

final class FakePairing: PinPairing, @unchecked Sendable {
    var submittedPin: String?
    func submit(pin: String) async throws -> String {
        submittedPin = pin
        return "new-key"
    }
    func cancel() async {}
}

final class FakeConnector: TVConnector, @unchecked Sendable {
    var session = FakeSession()
    var connectError: Error?
    var failuresBeforeSuccess = 0
    var connectAttempts = 0
    let pairing = FakePairing()
    var pairingHosts: [String] = []

    func connect(host: String, clientKey: String) async throws -> any TVSession {
        connectAttempts += 1
        if let connectError { throw connectError }
        if connectAttempts <= failuresBeforeSuccess { throw SSAPError.timeout }
        return session
    }

    func beginPinPairing(host: String) async throws -> any PinPairing {
        pairingHosts.append(host)
        return pairing
    }
}

struct FakeDiscovery: TVDiscovery {
    var hosts: [String]
    func discover() async -> [String] { hosts }
}

final class FakeWakeOnLan: WakeOnLan, @unchecked Sendable {
    var woken: [String] = []
    func wake(mac: String) throws { woken.append(mac) }
}

struct FakeMacResolver: MacAddressResolver {
    func macAddress(for host: String) async -> String? { "aa:bb:cc:dd:ee:ff" }
}

final class MemoryStore: ConfigStore, @unchecked Sendable {
    var config: TVConfig
    init(_ config: TVConfig = TVConfig()) { self.config = config }
    func load() -> TVConfig { config }
    func save(_ config: TVConfig) throws { self.config = config }
}

@MainActor
struct Harness {
    let connector = FakeConnector()
    let wol = FakeWakeOnLan()
    let store: MemoryStore
    let controller: RemoteController

    init(config: TVConfig = TVConfig(), hosts: [String] = []) {
        store = MemoryStore(config)
        controller = RemoteController(
            connector: connector, discovery: FakeDiscovery(hosts: hosts), wakeOnLan: wol,
            macResolver: FakeMacResolver(), store: store, sleep: { _ in })
    }
}

let paired = TVConfig(host: "10.0.0.5", clientKey: "key", hdmiMap: ["2": "HDMI_2"])

// MARK: Tests

@MainActor
@Suite struct RemoteControllerTests {
    @Test func unpairedStartNeedsSetup() async {
        let h = Harness()
        await h.controller.start()
        #expect(h.controller.state == .needsSetup)
        #expect(h.connector.connectAttempts == 0)
    }

    @Test func pairedStartConnectsAndCachesMetadata() async {
        let h = Harness(config: paired)
        await h.controller.start()
        #expect(h.controller.state == .connected)
        #expect(h.store.config.mac == "aa:bb:cc:dd:ee:ff")
        #expect(h.store.config.appIds["youtube"] == "youtube.leanback.v4")
        #expect(h.store.config.hdmiMap == ["2": "HDMI_2"])
        #expect(h.controller.liveSource == .hdmi(2))
    }

    @Test func switchingInputMovesTheLiveSource() async {
        let h = Harness(config: paired)
        await h.controller.start()
        await h.controller.perform(.youtube)
        #expect(h.controller.liveSource == .youtube)
        await h.controller.perform(.hdmi(2))
        #expect(h.controller.liveSource == .hdmi(2))
    }

    @Test func rejectedKeyClearsPairing() async {
        let h = Harness(config: paired)
        h.connector.connectError = SSAPError.notPaired
        await h.controller.start()
        #expect(h.controller.state == .needsSetup)
        #expect(h.store.config.clientKey == nil)
        #expect(h.store.config.host == "10.0.0.5")
    }

    @Test func offlineTVIsUnreachable() async {
        let h = Harness(config: paired)
        h.connector.connectError = SSAPError.timeout
        await h.controller.start()
        #expect(h.controller.state == .unreachable)
    }

    @Test func singleDiscoveredTVStartsPinPairingAndSavesKey() async {
        let h = Harness(hosts: ["192.168.1.50"])
        await h.controller.discover()
        #expect(h.controller.state == .awaitingPin(host: "192.168.1.50"))

        await h.controller.submitPin(" 123456 ")
        #expect(h.connector.pairing.submittedPin == " 123456 ")
        #expect(h.store.config.host == "192.168.1.50")
        #expect(h.store.config.clientKey == "new-key")
        #expect(h.controller.state == .connected)
    }

    @Test func multipleDiscoveredTVsLetTheUserChoose() async {
        let h = Harness(hosts: ["192.168.1.50", "192.168.1.51"])
        await h.controller.discover()
        #expect(h.controller.state == .needsSetup)
        #expect(h.controller.discoveredHosts == ["192.168.1.50", "192.168.1.51"])
        #expect(h.connector.pairingHosts.isEmpty)
    }

    @Test func noDiscoveredTVAsksForManualIP() async {
        let h = Harness()
        await h.controller.discover()
        #expect(h.controller.state == .needsSetup)
        #expect(h.controller.notice != nil)
    }

    @Test func keysAreRoutedToTheSession() async {
        let h = Harness(config: paired)
        await h.controller.start()
        for key: KeyInput in [.arrowUp, .returnKey, .delete, .character("+"), .character("2"), .character("y"), .character("n"), .character("p")] {
            await h.controller.handle(key: key)
        }
        let calls = await h.connector.session.calls
        #expect(calls == [
            "press:UP", "press:ENTER", "press:BACK", "volumeUp", "input:HDMI_2",
            "launch:youtube.leanback.v4", "press:NETFLIX", "powerOff",
        ])
    }

    @Test func unknownHdmiShowsNoticeWithoutSending() async {
        let h = Harness(config: paired)
        await h.controller.start()
        await h.controller.perform(.hdmi(3))
        #expect(h.controller.notice == "HDMI 3 isn’t available on this TV.")
        #expect(await h.connector.session.calls.isEmpty)
    }

    @Test func droppedConnectionBecomesUnreachableAndReconnectsOnCommand() async throws {
        let h = Harness(config: paired)
        await h.controller.start()
        await h.connector.session.close()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(h.controller.state == .unreachable)

        h.connector.session = FakeSession()
        await h.controller.perform(.button(.home))
        #expect(h.controller.state == .connected)
        #expect(await h.connector.session.calls == ["press:HOME"])
    }

    @Test func wakeSendsMagicPacketAndPollsUntilConnected() async {
        var config = paired
        config.mac = "aa:bb:cc:dd:ee:ff"
        let h = Harness(config: config)
        h.connector.failuresBeforeSuccess = 2
        await h.controller.handle(key: .character("w"))
        #expect(h.wol.woken == ["aa:bb:cc:dd:ee:ff"])
        #expect(h.connector.connectAttempts == 3)
        #expect(h.controller.state == .connected)
        #expect(await h.connector.session.calls.contains("powerOn"))
    }

    @Test func wakeWithoutMacExplainsWhy() async {
        let h = Harness(config: paired)
        await h.controller.perform(.wake)
        #expect(h.wol.woken.isEmpty)
        #expect(h.controller.notice?.contains("MAC") == true)
    }

    @Test func forgetClearsConfig() async {
        let h = Harness(config: paired)
        await h.controller.start()
        await h.controller.forgetTV()
        #expect(h.store.config == TVConfig())
        #expect(h.controller.state == .needsSetup)
    }
}
