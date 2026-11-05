import Foundation

/// Opens SSAP connections to an LG webOS TV.
public struct WebOSConnector: TVConnector {
    public init() {}

    public func connect(host: String, clientKey: String) async throws -> any TVSession {
        let channel = try await Self.openGreetedChannel(host: host)
        do {
            try await channel.send(SSAPMessages.register(clientKey: clientKey, pairingType: .pin))
            try await withTimeout(10) { try await Self.awaitRegistered(on: channel) }
            return try await SSAPSession.start(main: channel, host: host)
        } catch {
            channel.close()
            throw error
        }
    }

    public func beginPinPairing(host: String) async throws -> any PinPairing {
        let channel = try await Self.openGreetedChannel(host: host)
        do {
            try await channel.send(SSAPMessages.register(clientKey: nil, pairingType: .pin))
            let response = try await withTimeout(10) { try await channel.receive() }
            guard let message = SSAPIncoming(text: response),
                message.payload["pairingType"] as? String == PairingType.pin.rawValue,
                message.returnValue == true
            else { throw SSAPError.pairingRejected(response) }
            return PinPairingSession(channel: channel)
        } catch {
            channel.close()
            throw error
        }
    }

    /// Tries `ws://:3000` first and falls back to `wss://:3001` (newer firmware requires TLS),
    /// then exchanges the `hello` frame.
    static func openGreetedChannel(host: String) async throws -> WebSocketChannel {
        var lastError: Error = SSAPError.connectionClosed
        for url in ["ws://\(host):3000", "wss://\(host):3001"].compactMap(URL.init(string:)) {
            let channel = WebSocketChannel(url: url, trustedHost: host)
            channel.open()
            do {
                try await withTimeout(4) {
                    try await channel.send(SSAPMessages.hello())
                    let reply = try await channel.receive()
                    guard SSAPIncoming(text: reply)?.type == "hello" else {
                        throw SSAPError.unexpectedResponse(reply)
                    }
                }
                return channel
            } catch {
                channel.close()
                lastError = error
            }
        }
        throw lastError
    }

    /// Waits for `registered`. Any pairing prompt means the saved key is no longer valid.
    private static func awaitRegistered(on channel: WebSocketChannel) async throws {
        while true {
            let text = try await channel.receive()
            guard let message = SSAPIncoming(text: text) else { continue }
            switch message.type {
            case "registered": return
            case "error": throw SSAPError.pairingRejected(message.error ?? text)
            case "response" where message.payload["pairingType"] != nil: throw SSAPError.notPaired
            default: continue
            }
        }
    }
}

/// The TV is showing a PIN; `submit` sends it and returns the granted client key.
final class PinPairingSession: PinPairing, @unchecked Sendable {
    private let channel: WebSocketChannel

    init(channel: WebSocketChannel) {
        self.channel = channel
    }

    func submit(pin: String) async throws -> String {
        let channel = self.channel
        defer { channel.close() }
        try await channel.send(SSAPMessages.setPin(pin.trimmingCharacters(in: .whitespaces)))
        return try await withTimeout(60) {
            while true {
                let text = try await channel.receive()
                guard let message = SSAPIncoming(text: text) else { continue }
                if message.type == "error" { throw SSAPError.pairingRejected(message.error ?? text) }
                if let key = message.clientKey { return key }
            }
        }
    }

    func cancel() async {
        channel.close()
    }
}
