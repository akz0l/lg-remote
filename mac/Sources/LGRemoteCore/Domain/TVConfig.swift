/// Persisted TV settings. Keys match the CLI's `config.json` so it can be imported as-is.
public struct TVConfig: Codable, Equatable, Sendable {
    public var host: String?
    public var clientKey: String?
    public var mac: String?
    public var appIds: [String: String]
    public var hdmiMap: [String: String]

    public init(
        host: String? = nil,
        clientKey: String? = nil,
        mac: String? = nil,
        appIds: [String: String] = [:],
        hdmiMap: [String: String] = [:]
    ) {
        self.host = host
        self.clientKey = clientKey
        self.mac = mac
        self.appIds = appIds
        self.hdmiMap = hdmiMap
    }

    enum CodingKeys: String, CodingKey {
        case host
        case clientKey = "client_key"
        case mac
        case appIds = "app_ids"
        case hdmiMap = "hdmi_map"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decodeIfPresent(String.self, forKey: .host)
        clientKey = try c.decodeIfPresent(String.self, forKey: .clientKey)
        mac = try c.decodeIfPresent(String.self, forKey: .mac)
        appIds = try c.decodeIfPresent([String: String].self, forKey: .appIds) ?? [:]
        hdmiMap = try c.decodeIfPresent([String: String].self, forKey: .hdmiMap) ?? [:]
    }

    public var isPaired: Bool { host != nil && clientKey != nil }

    public static let defaultYouTubeId = "youtube.leanback.v4"
}

public struct TVApp: Equatable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct TVInput: Equatable, Sendable {
    public let id: String
    public let label: String
    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// Port of `cache_tv_metadata` from the CLI: remembers app ids and the HDMI mapping.
public enum TVMetadata {
    public static func apply(apps: [TVApp], inputs: [TVInput], to config: inout TVConfig) {
        for app in apps {
            let id = app.id.lowercased()
            let title = app.title.lowercased()
            if id.contains("youtube") || title.contains("youtube") { config.appIds["youtube"] = app.id }
            if id.contains("netflix") || title.contains("netflix") { config.appIds["netflix"] = app.id }
        }
        var hdmi: [String: String] = [:]
        for input in inputs {
            let normalized = (input.label + input.id).lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
            for n in 1...4 where normalized.contains("hdmi\(n)") {
                hdmi[String(n)] = input.id
            }
        }
        if !inputs.isEmpty { config.hdmiMap = hdmi }
    }
}
