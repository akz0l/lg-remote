import Foundation

public enum ARPOutput {
    /// Parses `arp -n <ip>` output, e.g. `? (192.168.1.5) at a:b:c:d:e:f on en0 ifscope [ethernet]`.
    /// Returns the MAC normalized to two lowercase hex digits per byte.
    public static func mac(from output: String) -> String? {
        guard let atRange = output.range(of: " at ") else { return nil }
        let rest = output[atRange.upperBound...]
        let candidate = rest.split(separator: " ").first.map(String.init) ?? ""
        let parts = candidate.split(separator: ":")
        guard parts.count == 6, parts.allSatisfy({ (1...2).contains($0.count) && UInt8($0, radix: 16) != nil })
        else { return nil }
        return parts.map { $0.count == 1 ? "0\($0)" : String($0) }.joined(separator: ":").lowercased()
    }
}

public struct ARPMacResolver: MacAddressResolver {
    public init() {}

    public func macAddress(for host: String) async -> String? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
            process.arguments = ["-n", host]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return ARPOutput.mac(from: String(decoding: data, as: UTF8.self))
        }.value
    }
}
