import Foundation

/// An open, authenticated session with the TV.
public protocol TVSession: Sendable {
    func press(_ button: RemoteButton) async throws
    func volumeUp() async throws
    func volumeDown() async throws
    func powerOff() async throws
    func powerOn() async throws
    func launchApp(id: String) async throws
    func switchInput(id: String) async throws
    func listApps() async throws -> [TVApp]
    func listInputs() async throws -> [TVInput]
    /// Returns when the connection drops for any reason.
    func waitUntilClosed() async
    func close() async
}

/// A PIN pairing in progress: the TV is already showing the code.
public protocol PinPairing: Sendable {
    /// Returns the client key granted by the TV.
    func submit(pin: String) async throws -> String
    func cancel() async
}

public protocol TVConnector: Sendable {
    func connect(host: String, clientKey: String) async throws -> any TVSession
    func beginPinPairing(host: String) async throws -> any PinPairing
}

public protocol TVDiscovery: Sendable {
    /// IP addresses of LG TVs found on the local network.
    func discover() async -> [String]
}

public protocol WakeOnLan: Sendable {
    func wake(mac: String) throws
}

public protocol MacAddressResolver: Sendable {
    func macAddress(for host: String) async -> String?
}

public protocol ConfigStore: Sendable {
    func load() -> TVConfig
    func save(_ config: TVConfig) throws
}
