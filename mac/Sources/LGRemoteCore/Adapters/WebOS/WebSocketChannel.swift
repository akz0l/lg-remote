import Foundation

/// Text WebSocket over `URLSessionWebSocketTask`.
///
/// webOS serves `wss://` with a self-signed certificate. Like the CLI (which used an
/// unverified `ssl.SSLContext()`), we accept it, but **only** for the TV's own host;
/// every other host keeps the system's default validation.
final class WebSocketChannel: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let trustedHost: String
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask!

    init(url: URL, trustedHost: String) {
        self.trustedHost = trustedHost
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        socket = session.webSocketTask(with: url)
        socket.maximumMessageSize = 16 * 1024 * 1024
    }

    func open() {
        socket.resume()
    }

    func send(_ text: String) async throws {
        try await socket.send(.string(text))
    }

    func receive() async throws -> String {
        switch try await socket.receive() {
        case .string(let text): return text
        case .data(let data): return String(decoding: data, as: UTF8.self)
        @unknown default: throw SSAPError.unexpectedResponse("unknown frame")
        }
    }

    func ping() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            socket.sendPing { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func close() {
        socket.cancel(with: .normalClosure, reason: nil)
        session.finishTasksAndInvalidate()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            space.host.caseInsensitiveCompare(trustedHost) == .orderedSame,
            let trust = space.serverTrust
        {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// Runs `operation`, throwing `SSAPError.timeout` if it takes longer than `seconds`.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval, _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SSAPError.timeout
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
