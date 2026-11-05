import Foundation
import Testing
@testable import LGRemoteCore

private func json(_ text: String) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

@Suite struct SSAPMessagesTests {
    @Test func helloFrame() throws {
        let hello = try json(SSAPMessages.hello())
        #expect(hello["type"] as? String == "hello")
        #expect(hello["id"] as? String == "hello")
    }

    @Test func pinRegistrationUsesUnsignedManifest() throws {
        let message = try json(SSAPMessages.register(clientKey: nil, pairingType: .pin))
        #expect(message["type"] as? String == "register")
        let payload = try #require(message["payload"] as? [String: Any])
        #expect(payload["pairingType"] as? String == "PIN")
        #expect(payload["client-key"] == nil)
        let manifest = try #require(payload["manifest"] as? [String: Any])
        #expect(manifest["signatures"] == nil)
        #expect(manifest["signed"] == nil)
        let permissions = try #require(manifest["permissions"] as? [String])
        #expect(permissions.contains("CONTROL_POWER"))
        #expect(permissions.contains("CONTROL_INPUT_TV"))
    }

    @Test func registrationCarriesSavedClientKey() throws {
        let message = try json(SSAPMessages.register(clientKey: "secret", pairingType: .pin))
        let payload = try #require(message["payload"] as? [String: Any])
        #expect(payload["client-key"] as? String == "secret")
    }

    @Test func requestFrame() throws {
        let message = try json(SSAPMessages.request(id: "req_1", uri: SSAPURI.launch, payload: ["id": "netflix"]))
        #expect(message["type"] as? String == "request")
        #expect(message["id"] as? String == "req_1")
        #expect(message["uri"] as? String == "ssap://system.launcher/launch")
        #expect(message["payload"] as? [String: String] == ["id": "netflix"])
    }

    @Test func requestWithoutPayloadOmitsIt() throws {
        let message = try json(SSAPMessages.request(id: "req_2", uri: SSAPURI.volumeUp))
        #expect(message["payload"] == nil)
    }

    @Test func setPinFrame() throws {
        let message = try json(SSAPMessages.setPin("123456"))
        #expect(message["uri"] as? String == "ssap://pairing/setPin")
        #expect(message["payload"] as? [String: String] == ["pin": "123456"])
    }

    @Test func pointerButtonFrame() {
        #expect(SSAPMessages.button(.up) == "type:button\nname:UP\n\n")
        #expect(SSAPMessages.button(.quickMenu) == "type:button\nname:QMENU\n\n")
    }

    @Test func decodesIncomingFrames() throws {
        let registered = try #require(SSAPIncoming(text: #"{"type":"registered","id":"register_0","payload":{"client-key":"k1"}}"#))
        #expect(registered.type == "registered")
        #expect(registered.clientKey == "k1")

        let error = try #require(SSAPIncoming(text: #"{"type":"error","id":"req_1","error":"401 insufficient permissions"}"#))
        #expect(error.error == "401 insufficient permissions")

        let response = try #require(SSAPIncoming(text: #"{"type":"response","id":"req_2","payload":{"returnValue":false}}"#))
        #expect(response.returnValue == false)

        #expect(SSAPIncoming(text: "not json") == nil)
    }
}

/// Talks to a real TV. Skipped unless `LGREMOTE_LIVE_CONFIG` points to a paired `config.json`.
/// Read-only: it only lists apps and inputs.
@Suite struct LiveTVTests {
    static var liveConfig: TVConfig? {
        guard let path = ProcessInfo.processInfo.environment["LGREMOTE_LIVE_CONFIG"] else { return nil }
        return try? JSONConfigStore.importLegacy(from: URL(fileURLWithPath: path))
    }

    @Test(.enabled(if: liveConfig != nil))
    func connectsAndListsInputs() async throws {
        let config = try #require(Self.liveConfig)
        let session = try await WebOSConnector().connect(host: config.host!, clientKey: config.clientKey!)
        let inputs = try await session.listInputs()
        #expect(!inputs.isEmpty)
        await session.close()
    }
}
