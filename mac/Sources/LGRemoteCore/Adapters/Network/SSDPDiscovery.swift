import Foundation

/// Pure helpers ported from `discover_tv` / `_looks_like_lg_tv` in the CLI.
public enum SSDPResponse {
    public static func location(in response: String) -> URL? {
        for line in response.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "location"
            else { continue }
            return URL(string: parts[1].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    public static func mentionsLG(_ response: String) -> Bool {
        let low = response.lowercased()
        return low.contains("lg") || low.contains("lge")
    }

    public static func descriptionMentionsLG(_ body: String) -> Bool {
        let low = body.lowercased()
        return low.contains("lg electronics") || low.contains("lge-com") || low.contains("lg.com")
    }
}

public struct SSDPDiscovery: TVDiscovery {
    public var timeout: TimeInterval

    public init(timeout: TimeInterval = 4) {
        self.timeout = timeout
    }

    public func discover() async -> [String] {
        let responses = await Task.detached { [timeout] in Self.search(timeout: timeout) }.value
        var lgHosts: [String] = []
        for (ip, raw) in responses.sorted(by: { $0.key < $1.key }) {
            if await Self.looksLikeLGTV(raw) { lgHosts.append(ip) }
        }
        return lgHosts
    }

    private static func looksLikeLGTV(_ raw: String) async -> Bool {
        if SSDPResponse.mentionsLG(raw) { return true }
        guard let location = SSDPResponse.location(in: raw) else { return false }
        var request = URLRequest(url: location)
        request.timeoutInterval = 2
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return false }
        return SSDPResponse.descriptionMentionsLG(String(decoding: data.prefix(4096), as: UTF8.self))
    }

    /// Sends an `ssdp:all` M-SEARCH and collects one raw response per IP.
    private static func search(timeout: TimeInterval) -> [String: String] {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return [:] }
        defer { close(fd) }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
        var ttl: UInt8 = 2
        setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size))
        if let local = localIPv4() {
            var iface = in_addr()
            inet_pton(AF_INET, local, &iface)
            setsockopt(fd, IPPROTO_IP, IP_MULTICAST_IF, &iface, socklen_t(MemoryLayout<in_addr>.size))
        }
        var tv = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let message = Array(
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: ssdp:all\r\n\r\n"
                .utf8)
        var dest = sockaddr_in.ipv4("239.255.255.250", port: 1900)
        for _ in 0..<2 {  // the first datagram is sometimes lost
            withUnsafePointer(to: &dest) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = sendto(fd, message, message.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        var found: [String: String] = [:]
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &from) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &fromLen)
                }
            }
            guard count > 0 else { continue }
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &from.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: ipBuffer)
            if found[ip] == nil {
                found[ip] = String(decoding: buffer[0..<count], as: UTF8.self)
            }
        }
        return found
    }

    /// Local IP used for outbound traffic (UDP connect sends no packets).
    static func localIPv4() -> String? {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var remote = sockaddr_in.ipv4("8.8.8.8", port: 80)
        let connected = withUnsafePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return nil }
        var local = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let ok = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        guard ok == 0 else { return nil }
        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &local.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: ipBuffer)
    }
}
