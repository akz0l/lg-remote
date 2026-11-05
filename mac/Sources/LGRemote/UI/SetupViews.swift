import AppKit
import LGRemoteCore
import SwiftUI

/// First run: find the TV (SSDP), type its IP, or import the CLI's config.json.
struct SetupView: View {
    @Environment(RemoteController.self) private var remote
    @State private var manualHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Conectá tu TV LG").font(.system(size: 15, weight: .semibold))
                Text("La TV y este Mac tienen que estar en la misma red.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if remote.state == .discovering {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Buscando TVs LG en la red…").font(.system(size: 12.5))
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            } else {
                PrimaryButton(title: "Buscar en la red", symbol: "magnifyingglass") {
                    Task { await remote.discover() }
                }
            }

            if !remote.discoveredHosts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Encontré varias TVs")
                    ForEach(remote.discoveredHosts, id: \.self) { host in
                        Button {
                            Task { await remote.beginPairing(host: host) }
                        } label: {
                            Label(host, systemImage: "tv")
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassSurface(RoundedRectangle(cornerRadius: Grid.keyRadius, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("O escribí la IP")
                HStack(spacing: Grid.gap) {
                    TextField("192.168.1.50", text: $manualHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12.5, design: .monospaced))
                        .onSubmit(connectManual)
                    Button("Conectar", action: connectManual)
                        .disabled(manualHost.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider()

            Button {
                importConfig(into: remote)
            } label: {
                Label("Importar config.json del CLI…", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12))
            }
            .buttonStyle(.link)
            .foregroundStyle(.primary)
        }
    }

    private func connectManual() {
        let host = manualHost
        Task { await remote.beginPairing(host: host) }
    }
}

/// The TV is showing a PIN: type it here.
struct PinView: View {
    @Environment(RemoteController.self) private var remote
    let host: String
    @State private var pin = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mirá la TV").font(.system(size: 15, weight: .semibold))
                Text("Escribí el PIN que aparece en la pantalla para emparejar este Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("PIN", text: $pin)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .tracking(6)
                .frame(height: 54)
                .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: false)
                .focused($focused)
                .onSubmit(submit)
                .accessibilityLabel("PIN de la TV")

            HStack {
                Button("Cancelar") { Task { await remote.cancelPairing() } }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                PrimaryButton(title: "Emparejar", symbol: "link", action: submit)
                    .frame(width: 140)
                    .disabled(pin.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text(host)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .onAppear { focused = true }
    }

    private func submit() {
        let value = pin
        Task { await remote.submitPin(value) }
    }
}

/// Main call to action: inverted (solid) glass key.
struct PrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .invertedInk(true)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassSurface(RoundedRectangle(cornerRadius: Grid.keyRadius, style: .continuous), live: true)
    }
}

@MainActor
func importConfig(into remote: RemoteController) {
    NSApp.activate(ignoringOtherApps: true)
    let panel = NSOpenPanel()
    panel.title = "Importar config.json"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { await remote.importConfig(from: url) }
}
