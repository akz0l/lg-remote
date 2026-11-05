import Foundation
import Testing
@testable import LGRemoteCore

@Suite struct KeyBindingsTests {
    @Test(arguments: [
        (KeyInput.arrowUp, RemoteCommand.button(.up)),
        (.arrowDown, .button(.down)),
        (.arrowLeft, .button(.left)),
        (.arrowRight, .button(.right)),
        (.returnKey, .button(.enter)),
        (.delete, .button(.back)),
        (.character("h"), .button(.home)),
        (.character("s"), .button(.quickMenu)),
        (.character("+"), .volumeUp),
        (.character("="), .volumeUp),
        (.character("-"), .volumeDown),
        (.character("m"), .button(.mute)),
        (.character("1"), .hdmi(1)),
        (.character("4"), .hdmi(4)),
        (.character("y"), .youtube),
        (.character("n"), .netflix),
        (.character("p"), .powerOff),
        (.character("w"), .wake),
        (.character("H"), .button(.home)),
    ])
    func mapsCLIShortcuts(key: KeyInput, expected: RemoteCommand) {
        #expect(KeyBindings.command(for: key) == expected)
    }

    @Test func ignoresUnmappedKeys() {
        #expect(KeyBindings.command(for: .character("x")) == nil)
        #expect(KeyBindings.command(for: .character("5")) == nil)
    }

    @Test func onlyWakeWorksWhileDisconnected() {
        #expect(RemoteCommand.wake.worksWhileDisconnected)
        #expect(!RemoteCommand.powerOff.worksWhileDisconnected)
    }
}

@Suite struct TVMetadataTests {
    @Test func detectsAppsAndHdmiInputs() {
        var config = TVConfig()
        TVMetadata.apply(
            apps: [
                TVApp(id: "youtube.leanback.v4", title: "YouTube"),
                TVApp(id: "netflix", title: "Netflix"),
                TVApp(id: "com.webos.app.browser", title: "Web Browser"),
            ],
            inputs: [
                TVInput(id: "HDMI_1", label: "PlayStation"),
                TVInput(id: "HDMI_3", label: "HDMI 3"),
            ],
            to: &config)
        #expect(config.appIds == ["youtube": "youtube.leanback.v4", "netflix": "netflix"])
        #expect(config.hdmiMap == ["1": "HDMI_1", "3": "HDMI_3"])
    }

    @Test func keepsHdmiMapWhenInputsUnavailable() {
        var config = TVConfig(hdmiMap: ["1": "HDMI_1"])
        TVMetadata.apply(apps: [], inputs: [], to: &config)
        #expect(config.hdmiMap == ["1": "HDMI_1"])
    }
}

@Suite struct ConfigStoreTests {
    let legacyJSON = """
        {"client_key": "abc123", "mac": "aa:bb:cc:dd:ee:ff",
         "app_ids": {"netflix": "netflix", "youtube": "youtube.leanback.v4"},
         "hdmi_map": {"1": "HDMI_1"}, "host": "192.168.1.50"}
        """

    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.json")
    }

    @Test func importsCLIConfig() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try legacyJSON.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let config = try JSONConfigStore.importLegacy(from: url)
        #expect(config.host == "192.168.1.50")
        #expect(config.clientKey == "abc123")
        #expect(config.mac == "aa:bb:cc:dd:ee:ff")
        #expect(config.appIds["youtube"] == "youtube.leanback.v4")
        #expect(config.hdmiMap == ["1": "HDMI_1"])
    }

    @Test func rejectsUnpairedConfig() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"host": "192.168.1.50"}"#.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(throws: ConfigImportError.notPaired) { try JSONConfigStore.importLegacy(from: url) }
    }

    @Test func roundTripsWithCLIKeysAndPrivatePermissions() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = JSONConfigStore(url: url)
        let config = TVConfig(host: "10.0.0.2", clientKey: "k", mac: "m", appIds: ["netflix": "n"])

        try store.save(config)

        #expect(store.load() == config)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(raw.contains("\"client_key\""))
        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        #expect(perms == 0o600)
    }

    @Test func missingFileLoadsEmptyConfig() {
        #expect(JSONConfigStore(url: tempURL()).load() == TVConfig())
    }
}
