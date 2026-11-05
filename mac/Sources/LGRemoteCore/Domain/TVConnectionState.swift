public enum TVConnectionState: Equatable, Sendable {
    /// Nothing configured yet: the user must find or type the TV address.
    case needsSetup
    case discovering
    /// The TV is showing a PIN and we wait for the user to type it.
    case awaitingPin(host: String)
    case connecting
    case connected
    /// The TV did not answer (usually powered off). Wake-on-LAN still works.
    case unreachable
    case waking
    case failed(String)
}
