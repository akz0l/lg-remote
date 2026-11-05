import Foundation

public enum WakeOnLanError: Error, Equatable, LocalizedError {
    case invalidMac(String)
    case socketFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidMac(let mac): return "Invalid MAC address: \(mac)"
        case .socketFailed(let code): return "Couldn’t send the Wake-on-LAN packet (errno \(code))."
        }
    }
}

public enum MagicPacket {
    /// 6 × 0xFF followed by the MAC repeated 16 times (102 bytes).
    public static func make(mac: String) throws -> Data {
        let hex = mac.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard hex.count == 12 else { throw WakeOnLanError.invalidMac(mac) }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { throw WakeOnLanError.invalidMac(mac) }
            bytes.append(byte)
            index = next
        }
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }
}

public struct WakeOnLanSender: WakeOnLan {
    public var broadcast: String
    public var port: UInt16

    public init(broadcast: String = "255.255.255.255", port: UInt16 = 9) {
        self.broadcast = broadcast
        self.port = port
    }

    public func wake(mac: String) throws {
        let packet = try MagicPacket.make(mac: mac)
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw WakeOnLanError.socketFailed(errno) }
        defer { close(fd) }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in.ipv4(broadcast, port: port)
        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { throw WakeOnLanError.socketFailed(errno) }
    }
}

extension sockaddr_in {
    static func ipv4(_ host: String, port: UInt16) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)
        return addr
    }
}
