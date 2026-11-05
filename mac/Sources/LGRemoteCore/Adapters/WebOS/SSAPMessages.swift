import Foundation

/// Registration manifest ported from aiowebostv, deliberately **unsigned**.
///
/// Recent webOS firmware (22+) rejects the signing certificate aiowebostv ships since 2014
/// ("403 Pairing rejected: blacklisted certificate detected"). Any firmware accepts an unsigned
/// manifest, although it only grants top-level permissions (so `getCurrentSWInformation` is
/// never called).
enum RegistrationManifest {
    static let permissions = [
        "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE", "TEST_OPEN", "TEST_PROTECTED",
        "CONTROL_AUDIO", "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_RECORDING",
        "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_TV", "CONTROL_POWER", "CONTROL_TV_SCREEN",
        "READ_APP_STATUS", "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST", "READ_NETWORK_STATE",
        "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST", "WRITE_NOTIFICATION_TOAST", "READ_POWER_STATE",
        "READ_COUNTRY_INFO", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD", "READ_INSTALLED_APPS",
        "READ_SETTINGS",
    ]

    static var manifest: [String: Any] {
        ["appVersion": "1.1", "manifestVersion": 1, "permissions": permissions]
    }
}

enum PairingType: String {
    case pin = "PIN"
    case prompt = "PROMPT"
}

enum SSAPURI {
    static let pointerSocket = "ssap://com.webos.service.networkinput/getPointerInputSocket"
    static let volumeUp = "ssap://audio/volumeUp"
    static let volumeDown = "ssap://audio/volumeDown"
    static let turnOff = "ssap://system/turnOff"
    static let turnOn = "ssap://system/turnOn"
    static let launch = "ssap://system.launcher/launch"
    static let switchInput = "ssap://tv/switchInput"
    static let listApps = "ssap://com.webos.applicationManager/listApps"
    static let listInputs = "ssap://tv/getExternalInputList"
    static let setPin = "ssap://pairing/setPin"
    static let foregroundApp = "ssap://com.webos.applicationManager/getForegroundAppInfo"
}

/// Builds the JSON text frames of the SSAP protocol.
enum SSAPMessages {
    static func hello() -> String {
        encode(["id": "hello", "type": "hello"])
    }

    static func register(clientKey: String?, pairingType: PairingType) -> String {
        var payload: [String: Any] = [
            "forcePairing": false,
            "manifest": RegistrationManifest.manifest,
            "pairingType": pairingType.rawValue,
        ]
        if let clientKey { payload["client-key"] = clientKey }
        return encode(["type": "register", "id": "register_0", "payload": payload])
    }

    static func request(id: String, uri: String, payload: [String: String]? = nil) -> String {
        var message: [String: Any] = ["type": "request", "id": id, "uri": uri]
        if let payload { message["payload"] = payload }
        return encode(message)
    }

    static func setPin(_ pin: String) -> String {
        request(id: "pin_req", uri: SSAPURI.setPin, payload: ["pin": pin])
    }

    /// Frame for the pointer input socket (not JSON).
    static func button(_ button: RemoteButton) -> String {
        "type:button\nname:\(button.rawValue)\n\n"
    }

    private static func encode(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

/// A decoded incoming SSAP frame.
struct SSAPIncoming: @unchecked Sendable {
    let type: String
    let id: String?
    let payload: [String: Any]
    let error: String?

    init?(text: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            let type = object["type"] as? String
        else { return nil }
        self.type = type
        self.id = object["id"] as? String
        self.payload = object["payload"] as? [String: Any] ?? [:]
        self.error = object["error"] as? String
    }

    var clientKey: String? { payload["client-key"] as? String }
    var returnValue: Bool? { payload["returnValue"] as? Bool }
}

public enum SSAPError: Error, Equatable, LocalizedError {
    case timeout
    case connectionClosed
    case unexpectedResponse(String)
    /// The saved client key is no longer accepted: pair again with a PIN.
    case notPaired
    case pairingRejected(String)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .timeout: return "The TV didn’t respond in time."
        case .connectionClosed: return "The connection to the TV was closed."
        case .unexpectedResponse(let text): return "Unexpected response from the TV: \(text)"
        case .notPaired: return "The TV no longer recognizes this Mac. Pair it again."
        case .pairingRejected(let text): return "The TV rejected pairing: \(text)"
        case .commandFailed(let text): return "The TV rejected the command: \(text)"
        }
    }
}
