/// Buttons sent through the webOS pointer input socket.
public enum RemoteButton: String, Sendable, CaseIterable {
    case up = "UP"
    case down = "DOWN"
    case left = "LEFT"
    case right = "RIGHT"
    case enter = "ENTER"
    case back = "BACK"
    case home = "HOME"
    case quickMenu = "QMENU"
    case mute = "MUTE"
    case netflix = "NETFLIX"
}

/// Every action the remote can perform, independent of how it is triggered.
public enum RemoteCommand: Hashable, Sendable {
    case button(RemoteButton)
    case volumeUp
    case volumeDown
    case hdmi(Int)
    case youtube
    case netflix
    case powerOff
    case wake

    /// Commands that do not need an open session with the TV.
    public var worksWhileDisconnected: Bool {
        self == .wake
    }
}

/// What is on screen right now, so the UI can mark it "on air".
public enum LiveSource: Equatable, Sendable {
    case hdmi(Int)
    case youtube
    case netflix

    /// Maps a webOS foreground app id to a source the remote can show.
    public init?(appId: String, config: TVConfig) {
        let low = appId.lowercased()
        if let range = low.range(of: "hdmi"), let n = low[range.upperBound...].first.flatMap({ Int(String($0)) }),
            (1...4).contains(n)
        {
            self = .hdmi(n)
        } else if appId == config.appIds["youtube"] || low.contains("youtube") {
            self = .youtube
        } else if appId == config.appIds["netflix"] || low.contains("netflix") {
            self = .netflix
        } else {
            return nil
        }
    }
}

/// Keyboard input, decoupled from AppKit/SwiftUI key types.
public enum KeyInput: Hashable, Sendable {
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case returnKey
    case delete
    case character(Character)
}

/// Same shortcuts as the original CLI (`lg_remote.py`).
public enum KeyBindings {
    public static func command(for key: KeyInput) -> RemoteCommand? {
        switch key {
        case .arrowUp: return .button(.up)
        case .arrowDown: return .button(.down)
        case .arrowLeft: return .button(.left)
        case .arrowRight: return .button(.right)
        case .returnKey: return .button(.enter)
        case .delete: return .button(.back)
        case .character(let char):
            switch char.lowercased() {
            case "h": return .button(.home)
            case "s": return .button(.quickMenu)
            case "+", "=": return .volumeUp
            case "-": return .volumeDown
            case "m": return .button(.mute)
            case "1", "2", "3", "4": return .hdmi(Int(String(char))!)
            case "y": return .youtube
            case "n": return .netflix
            case "p": return .powerOff
            case "w": return .wake
            default: return nil
            }
        }
    }

    /// Short label shown on each control so the shortcut is discoverable.
    public static func label(for command: RemoteCommand) -> String {
        switch command {
        case .button(.up): return "↑"
        case .button(.down): return "↓"
        case .button(.left): return "←"
        case .button(.right): return "→"
        case .button(.enter): return "↩"
        case .button(.back): return "⌫"
        case .button(.home): return "H"
        case .button(.quickMenu): return "S"
        case .button(.mute): return "M"
        case .button(.netflix), .netflix: return "N"
        case .volumeUp: return "+"
        case .volumeDown: return "−"
        case .hdmi(let n): return "\(n)"
        case .youtube: return "Y"
        case .powerOff: return "P"
        case .wake: return "W"
        }
    }
}
