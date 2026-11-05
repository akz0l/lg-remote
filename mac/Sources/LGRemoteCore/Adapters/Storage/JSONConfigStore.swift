import Foundation

/// Stores the config as JSON, using the same keys as the CLI's `config.json`.
public struct JSONConfigStore: ConfigStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/LGRemote/config.json`
    public static func standard() -> JSONConfigStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return JSONConfigStore(url: base.appendingPathComponent("LGRemote/config.json"))
    }

    public func load() -> TVConfig {
        guard let data = try? Data(contentsOf: url) else { return TVConfig() }
        return (try? JSONDecoder().decode(TVConfig.self, from: data)) ?? TVConfig()
    }

    public func save(_ config: TVConfig) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
        // The client key grants control of the TV: keep it private to this user.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Reads a CLI `config.json`. Throws when the file is not a valid config or has no pairing.
    public static func importLegacy(from url: URL) throws -> TVConfig {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(TVConfig.self, from: data)
        guard config.isPaired else { throw ConfigImportError.notPaired }
        return config
    }
}

public enum ConfigImportError: Error, Equatable, LocalizedError {
    case notPaired

    public var errorDescription: String? {
        switch self {
        case .notPaired: return "That file has no paired TV (host or client_key is missing)."
        }
    }
}
