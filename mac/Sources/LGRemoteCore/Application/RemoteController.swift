import Foundation
import Observation

/// Orchestrates setup, connection and commands. The UI only reads its state and calls its intents.
@MainActor
@Observable
public final class RemoteController {
    public private(set) var state: TVConnectionState = .needsSetup
    public private(set) var config: TVConfig
    /// TVs found by the last discovery when there was more than one.
    public private(set) var discoveredHosts: [String] = []
    /// Short-lived message for the user ("HDMI 2", "No encontré el HDMI 3", …).
    public private(set) var notice: String?
    /// Last command sent, so the UI can briefly highlight the matching control.
    public private(set) var lastCommand: RemoteCommand?

    private let connector: any TVConnector
    private let discovery: any TVDiscovery
    private let wakeOnLan: any WakeOnLan
    private let macResolver: any MacAddressResolver
    private let store: any ConfigStore
    private let sleep: @Sendable (Double) async -> Void

    private var session: (any TVSession)?
    private var pairing: (any PinPairing)?
    private var connectTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?

    public init(
        connector: any TVConnector,
        discovery: any TVDiscovery,
        wakeOnLan: any WakeOnLan,
        macResolver: any MacAddressResolver,
        store: any ConfigStore,
        sleep: @escaping @Sendable (Double) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1e9)) }
    ) {
        self.connector = connector
        self.discovery = discovery
        self.wakeOnLan = wakeOnLan
        self.macResolver = macResolver
        self.store = store
        self.sleep = sleep
        self.config = store.load()
    }

    public var canWake: Bool { config.mac != nil }
    public var isConnected: Bool { state == .connected }

    // MARK: Lifecycle

    public func start() async {
        if config.isPaired { await connect() } else { state = .needsSetup }
    }

    /// Called whenever the panel opens: retries a dropped connection.
    public func panelDidOpen() async {
        switch state {
        case .unreachable, .failed: if config.isPaired { await connect() }
        default: break
        }
    }

    // MARK: Setup

    public func discover() async {
        state = .discovering
        discoveredHosts = []
        let hosts = await discovery.discover()
        switch hosts.count {
        case 0:
            state = .needsSetup
            show("No encontré ninguna TV LG en la red. Escribí la IP a mano.")
        case 1:
            await beginPairing(host: hosts[0])
        default:
            discoveredHosts = hosts
            state = .needsSetup
        }
    }

    public func beginPairing(host: String) async {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        await closeSession()
        state = .connecting
        do {
            pairing = try await connector.beginPinPairing(host: host)
            state = .awaitingPin(host: host)
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    public func submitPin(_ pin: String) async {
        guard case .awaitingPin(let host) = state, let pairing else { return }
        state = .connecting
        do {
            let key = try await pairing.submit(pin: pin)
            self.pairing = nil
            config.host = host
            config.clientKey = key
            persist()
            await connect()
        } catch {
            self.pairing = nil
            state = .failed(Self.describe(error))
        }
    }

    public func cancelPairing() async {
        await pairing?.cancel()
        pairing = nil
        state = config.isPaired ? .unreachable : .needsSetup
    }

    public func importConfig(from url: URL) async {
        do {
            let imported = try JSONConfigStore.importLegacy(from: url)
            await closeSession()
            config = imported
            persist()
            await connect()
        } catch {
            show(Self.describe(error))
        }
    }

    public func forgetTV() async {
        await closeSession()
        config = TVConfig()
        persist()
        state = .needsSetup
    }

    // MARK: Connection

    public func connect() async {
        if let connectTask { return await connectTask.value }
        let task = Task { await self.performConnect() }
        connectTask = task
        await task.value
        connectTask = nil
    }

    private func performConnect() async {
        guard let host = config.host, let key = config.clientKey else {
            state = .needsSetup
            return
        }
        state = .connecting
        do {
            let session = try await connector.connect(host: host, clientKey: key)
            self.session = session
            state = .connected
            monitor(session)
            await refreshMetadata(session: session, host: host)
        } catch SSAPError.notPaired {
            config.clientKey = nil
            persist()
            state = .needsSetup
            show(Self.describe(SSAPError.notPaired))
        } catch {
            state = .unreachable
        }
    }

    private func monitor(_ session: any TVSession) {
        Task { [weak self] in
            await session.waitUntilClosed()
            guard let self else { return }
            if let current = self.session, current as AnyObject === session as AnyObject {
                self.session = nil
                if self.state == .connected { self.state = .unreachable }
            }
        }
    }

    private func refreshMetadata(session: any TVSession, host: String) async {
        if config.mac == nil, let mac = await macResolver.macAddress(for: host) {
            config.mac = mac
        }
        let apps = (try? await session.listApps()) ?? []
        let inputs = (try? await session.listInputs()) ?? []
        TVMetadata.apply(apps: apps, inputs: inputs, to: &config)
        persist()
    }

    private func closeSession() async {
        let old = session
        session = nil
        await old?.close()
    }

    // MARK: Commands

    public func handle(key: KeyInput) async {
        guard let command = KeyBindings.command(for: key) else { return }
        await perform(command)
    }

    public func perform(_ command: RemoteCommand) async {
        lastCommand = command
        if command == .wake { return await wake() }

        if session == nil, config.isPaired { await connect() }
        guard let session else {
            show("La TV no responde. Si está apagada, encendela con W.")
            return
        }
        do {
            try await send(command, to: session)
        } catch {
            show(Self.describe(error))
        }
    }

    private func send(_ command: RemoteCommand, to session: any TVSession) async throws {
        switch command {
        case .button(let button): try await session.press(button)
        case .volumeUp: try await session.volumeUp()
        case .volumeDown: try await session.volumeDown()
        case .hdmi(let n):
            guard let input = config.hdmiMap[String(n)] else {
                show("No encontré el HDMI \(n) en la TV.")
                return
            }
            try await session.switchInput(id: input)
            show("HDMI \(n)")
        case .youtube:
            try await session.launchApp(id: config.appIds["youtube"] ?? TVConfig.defaultYouTubeId)
            show("YouTube")
        case .netflix:
            if let id = config.appIds["netflix"] {
                try await session.launchApp(id: id)
            } else {
                try await session.press(.netflix)
            }
            show("Netflix")
        case .powerOff:
            try await session.powerOff()
            show("Apagando la TV")
        case .wake:
            break
        }
    }

    /// Wake-on-LAN, then poll until the TV accepts a connection (like the CLI's `w`).
    public func wake() async {
        guard let mac = config.mac else {
            show("Todavía no conozco la MAC de la TV. Conectate una vez con la TV encendida.")
            return
        }
        do {
            try wakeOnLan.wake(mac: mac)
        } catch {
            show(Self.describe(error))
            return
        }
        guard config.isPaired else { return }
        state = .waking
        for _ in 0..<8 {
            await sleep(3)
            await performConnect()
            if let session {
                try? await session.powerOn()
                return
            }
            if state == .needsSetup { return }
            state = .waking
        }
        state = .unreachable
        show("Envié el encendido pero la TV no respondió. Revisá que \"Encender con el móvil\" esté activado.")
    }

    // MARK: Helpers

    private func persist() {
        do {
            try store.save(config)
        } catch {
            show("No pude guardar la configuración: \(error.localizedDescription)")
        }
    }

    private func show(_ message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
