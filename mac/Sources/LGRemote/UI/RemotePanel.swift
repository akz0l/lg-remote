import LGRemoteCore
import SwiftUI

/// Root of the menu bar panel: header plus the view for the current state.
struct RemotePanel: View {
    @Environment(RemoteController.self) private var remote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader()
            content
        }
        .padding(Grid.padding)
        .frame(width: Grid.width)
        .task { await remote.panelDidOpen() }
    }

    @ViewBuilder private var content: some View {
        switch remote.state {
        case .awaitingPin(let host):
            PinView(host: host)
        case .needsSetup, .discovering:
            SetupView()
        case .connecting where !remote.config.isPaired:
            WorkingView(text: "Pidiendo el PIN a la TV…")
        case .failed(let message) where !remote.config.isPaired:
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5))
                    .fixedSize(horizontal: false, vertical: true)
                SetupView()
            }
        default:
            RemoteView()
        }
    }
}

struct WorkingView: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).font(.system(size: 12.5))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

/// TV identity, honest connection state (shape, not color) and the app menu.
struct StatusHeader: View {
    @Environment(RemoteController.self) private var remote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        HStack(spacing: 8) {
            indicator
            VStack(alignment: .leading, spacing: 1) {
                Text("TV LG").font(.system(size: 13, weight: .semibold))
                Text(remote.notice ?? statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: remote.notice)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            menu
        }
    }

    private var statusText: String {
        let host = remote.config.host.map { " · \($0)" } ?? ""
        switch remote.state {
        case .connected: return "Conectada\(host)"
        case .connecting: return "Conectando…"
        case .waking: return "Encendiendo…"
        case .unreachable: return "Sin respuesta\(host)"
        case .discovering: return "Buscando…"
        case .awaitingPin: return "Emparejando"
        case .needsSetup: return "Sin configurar"
        case .failed(let message): return message
        }
    }

    private var isBusy: Bool {
        [.connecting, .waking, .discovering].contains(remote.state)
    }

    /// Filled = commands land. Hollow = they will not. Breathing = working on it.
    private var indicator: some View {
        ZStack {
            if remote.isConnected {
                Circle().fill(.primary)
            } else {
                Circle().strokeBorder(.primary, lineWidth: 1.5)
            }
        }
        .frame(width: 8, height: 8)
        .opacity(isBusy && breathe ? 0.25 : 1)
        .onChange(of: isBusy, initial: true) { _, busy in
            guard busy, !reduceMotion else {
                breathe = false
                return
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }

    private var menu: some View {
        Menu {
            if remote.config.isPaired {
                Button("Reconectar") { Task { await remote.connect() } }
                Button("Encender TV (Wake-on-LAN)") { Task { await remote.wake() } }
                    .disabled(!remote.canWake)
                Divider()
            }
            Button("Importar config.json…") { importConfig(into: remote) }
            Button("Olvidar esta TV") { Task { await remote.forgetTV() } }
                .disabled(remote.config.host == nil)
            Divider()
            Button("Salir de LG Remote") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Opciones")
    }
}
