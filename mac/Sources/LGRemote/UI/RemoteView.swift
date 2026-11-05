import LGRemoteCore
import SwiftUI

/// The remote itself. Rows never move; only state (tally, dimming) changes.
struct RemoteView: View {
    @Environment(RemoteController.self) private var remote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tally
    @FocusState private var focused: Bool

    private var reachable: Bool { remote.isConnected }

    var body: some View {
        VStack(spacing: 12) {
            if !reachable { UnreachableBar() }

            GlassGroup {
                VStack(alignment: .leading, spacing: 10) {
                    inputsBus
                    appsRow
                    navigationCluster
                }
                .disabled(!reachable)
                .opacity(reachable ? 1 : 0.4)
            }

            footer
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in handle(press) }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0.2), value: remote.liveSource)
    }

    // MARK: Rows

    private var inputsBus: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Entrada")
            HStack(spacing: Grid.gap) {
                ForEach(1...4, id: \.self) { n in
                    source(.hdmi(n), title: "HDMI \(n)", command: .hdmi(n), width: Grid.column)
                }
            }
        }
    }

    private var appsRow: some View {
        HStack(spacing: Grid.gap) {
            source(.youtube, title: "YouTube", command: .youtube, width: Grid.span(2))
            source(.netflix, title: "Netflix", command: .netflix, width: Grid.span(2))
        }
    }

    /// A key that can be "on air": the tally bar sits on top of the live one and slides between them.
    private func source(_ source: LiveSource, title: String, command: RemoteCommand, width: CGFloat) -> some View {
        let live = remote.liveSource == source
        return KeyButton(command: command, title: title, live: live)
            .frame(width: width)
            .overlay(alignment: .top) {
                if live {
                    Capsule()
                        .fill(.primary)
                        .frame(width: width * 0.42, height: 3)
                        .offset(y: -6)
                        .matchedGeometryEffect(id: "tally", in: tally)
                        .accessibilityHidden(true)
                }
            }
    }

    private var navigationCluster: some View {
        let height = Grid.span(2)
        return HStack(spacing: Grid.gap) {
            VStack(spacing: Grid.gap) {
                let keyHeight = (height - Grid.gap * 2) / 3
                KeyButton(command: .button(.back), title: "Atrás", height: keyHeight)
                KeyButton(command: .button(.home), title: "Inicio", height: keyHeight)
                KeyButton(command: .button(.quickMenu), title: "Ajustes", height: keyHeight)
            }
            .frame(width: Grid.column)

            DirectionPad(diameter: height)
                .frame(width: Grid.span(2))

            VolumeRocker(height: height)
                .frame(width: Grid.column)
        }
    }

    private var footer: some View {
        HStack(spacing: Grid.gap) {
            KeyButton(command: .button(.mute), title: "Silencio", symbol: "speaker.slash", height: 30)
                .frame(width: Grid.span(2))
                .disabled(!reachable)
                .opacity(reachable ? 1 : 0.4)
            Spacer(minLength: 0)
            // Isolated in the corner so it is not hit by accident.
            KeyButton(command: .powerOff, symbol: "power", accessibilityName: "Apagar TV", height: 30)
                .frame(width: Grid.column)
                .disabled(!reachable)
                .opacity(reachable ? 1 : 0.4)
        }
        .padding(.top, 2)
    }

    // MARK: Keyboard

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        if press.key == .escape {
            NSApp.keyWindow?.close()
            return .handled
        }
        guard let input = Self.keyInput(press), KeyBindings.command(for: input) != nil else { return .ignored }
        Task { await remote.handle(key: input) }
        return .handled
    }

    static func keyInput(_ press: KeyPress) -> KeyInput? {
        switch press.key {
        case .upArrow: return .arrowUp
        case .downArrow: return .arrowDown
        case .leftArrow: return .arrowLeft
        case .rightArrow: return .arrowRight
        case .return: return .returnKey
        case .delete, .deleteForward: return .delete
        default: return press.characters.first.map(KeyInput.character)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Round D-pad: one glass disc carrying four arrows around a central OK key.
struct DirectionPad: View {
    let diameter: CGFloat

    var body: some View {
        let ok = diameter * 0.42
        let reach = diameter * 0.355
        ZStack {
            InsetKey(command: .button(.up), symbol: "chevron.up", name: "Arriba").offset(y: -reach)
            InsetKey(command: .button(.down), symbol: "chevron.down", name: "Abajo").offset(y: reach)
            InsetKey(command: .button(.left), symbol: "chevron.left", name: "Izquierda").offset(x: -reach)
            InsetKey(command: .button(.right), symbol: "chevron.right", name: "Derecha").offset(x: reach)

            KeyButton(command: .button(.enter), title: "OK", accessibilityName: "OK, seleccionar", height: ok, showsLegend: false)
                .frame(width: ok)
                .clipShape(Circle())
        }
        .frame(width: diameter, height: diameter)
        .glassSurface(Circle(), interactive: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navegación")
    }
}

/// Vertical volume rocker: one glass capsule, + on top, − at the bottom.
struct VolumeRocker: View {
    let height: CGFloat

    var body: some View {
        let half = CGSize(width: 46, height: height / 2 - 10)
        VStack(spacing: 0) {
            InsetKey(command: .volumeUp, symbol: "plus", name: "Subir volumen", size: half)
            Text("VOL")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(height: 20)
                .accessibilityHidden(true)
            InsetKey(command: .volumeDown, symbol: "minus", name: "Bajar volumen", size: half)
        }
        .frame(width: 46, height: height)
        .glassSurface(Capsule(), interactive: false)
        .frame(maxWidth: .infinity)
    }
}

/// Shown when the TV does not answer: the next step is always one key away.
struct UnreachableBar: View {
    @Environment(RemoteController.self) private var remote

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("La TV no responde").font(.system(size: 12.5, weight: .semibold))
                Text(remote.canWake ? "Puede estar apagada." : "¿Está encendida y en la misma red?")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if remote.canWake {
                KeyButton(command: .wake, title: "Encender", symbol: "power", height: 32)
                    .frame(width: Grid.span(2) - 24)
            } else {
                Button("Reintentar") { Task { await remote.connect() } }
            }
        }
    }
}
