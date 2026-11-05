import Foundation

/// A registered SSAP connection plus the pointer socket used for button presses.
actor SSAPSession: TVSession {
    private let main: WebSocketChannel
    /// Opened right after registration; its URL comes from `getPointerInputSocket`.
    private var pointer: WebSocketChannel?
    private var pending: [String: CheckedContinuation<SSAPIncoming, Error>] = [:]
    private var nextId = 0
    private var isClosed = false
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    private var tasks: [Task<Void, Never>] = []

    private init(main: WebSocketChannel) {
        self.main = main
    }

    /// Starts the receive loop and opens the pointer input socket.
    static func start(main: WebSocketChannel, host: String) async throws -> SSAPSession {
        let session = SSAPSession(main: main)
        await session.startLoops()
        do {
            try await session.openPointer(host: host)
            return session
        } catch {
            await session.close()
            throw error
        }
    }

    private func startLoops() {
        tasks.append(Task { [weak self] in await self?.receiveLoop() })
        tasks.append(Task { [weak self] in await self?.keepAliveLoop() })
    }

    private func openPointer(host: String) async throws {
        let response = try await request(SSAPURI.pointerSocket)
        guard let path = response.payload["socketPath"] as? String, let url = URL(string: path) else {
            throw SSAPError.unexpectedResponse("missing socketPath")
        }
        let channel = WebSocketChannel(url: url, trustedHost: host)
        channel.open()
        pointer = channel
    }

    // MARK: TVSession

    func press(_ button: RemoteButton) async throws {
        try ensureOpen()
        guard let pointer else { throw SSAPError.connectionClosed }
        try await pointer.send(SSAPMessages.button(button))
    }

    func volumeUp() async throws { _ = try await request(SSAPURI.volumeUp) }
    func volumeDown() async throws { _ = try await request(SSAPURI.volumeDown) }
    func powerOff() async throws { _ = try await request(SSAPURI.turnOff) }
    func powerOn() async throws { _ = try await request(SSAPURI.turnOn) }

    func launchApp(id: String) async throws {
        _ = try await request(SSAPURI.launch, payload: ["id": id])
    }

    func switchInput(id: String) async throws {
        _ = try await request(SSAPURI.switchInput, payload: ["inputId": id])
    }

    func listApps() async throws -> [TVApp] {
        let response = try await request(SSAPURI.listApps)
        let apps = response.payload["apps"] as? [[String: Any]] ?? []
        return apps.compactMap { app in
            guard let id = app["id"] as? String else { return nil }
            return TVApp(id: id, title: app["title"] as? String ?? "")
        }
    }

    func listInputs() async throws -> [TVInput] {
        let response = try await request(SSAPURI.listInputs)
        let devices = response.payload["devices"] as? [[String: Any]] ?? []
        return devices.compactMap { device in
            guard let id = device["id"] as? String else { return nil }
            return TVInput(id: id, label: device["label"] as? String ?? "")
        }
    }

    func foregroundAppId() async throws -> String? {
        try await request(SSAPURI.foregroundApp).payload["appId"] as? String
    }

    func waitUntilClosed() async {
        if isClosed { return }
        await withCheckedContinuation { closeWaiters.append($0) }
    }

    func close() async {
        guard !isClosed else { return }
        markClosed()
        main.close()
        pointer?.close()
    }

    // MARK: Internals

    private func ensureOpen() throws {
        if isClosed { throw SSAPError.connectionClosed }
    }

    private func request(_ uri: String, payload: [String: String]? = nil) async throws -> SSAPIncoming {
        try ensureOpen()
        nextId += 1
        let id = "req_\(nextId)"
        let main = self.main
        let response: SSAPIncoming = try await withTimeout(8) {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await self.register(id: id, continuation: continuation)
                    do {
                        try await main.send(SSAPMessages.request(id: id, uri: uri, payload: payload))
                    } catch {
                        await self.resolve(id: id, with: .failure(error))
                    }
                }
            }
        }
        if response.type == "error" { throw SSAPError.commandFailed(response.error ?? uri) }
        if response.returnValue == false {
            throw SSAPError.commandFailed(response.payload["errorText"] as? String ?? uri)
        }
        return response
    }

    private func register(id: String, continuation: CheckedContinuation<SSAPIncoming, Error>) {
        if isClosed {
            continuation.resume(throwing: SSAPError.connectionClosed)
        } else {
            pending[id] = continuation
        }
    }

    private func resolve(id: String, with result: Result<SSAPIncoming, Error>) {
        pending.removeValue(forKey: id)?.resume(with: result)
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let text = try await main.receive()
                if let message = SSAPIncoming(text: text), let id = message.id {
                    resolve(id: id, with: .success(message))
                }
            } catch {
                if !Task.isCancelled { await close() }
                return
            }
        }
    }

    /// Pings every 15 s so a TV that was switched off is noticed quickly.
    private func keepAliveLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if Task.isCancelled || isClosed { return }
            let main = self.main
            do {
                try await withTimeout(5) { try await main.ping() }
            } catch {
                await close()
                return
            }
        }
    }

    private func failPending(_ error: Error) {
        let waiting = pending
        pending.removeAll()
        waiting.values.forEach { $0.resume(throwing: error) }
    }

    private func markClosed() {
        isClosed = true
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        failPending(SSAPError.connectionClosed)
        closeWaiters.forEach { $0.resume() }
        closeWaiters.removeAll()
    }
}
