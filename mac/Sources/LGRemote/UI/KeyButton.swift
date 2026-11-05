import LGRemoteCore
import SwiftUI

/// Briefly presses a control when its command fires (from a click or its shortcut).
struct CommandFlash: ViewModifier {
    @Environment(RemoteController.self) private var remote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let command: RemoteCommand
    @State private var flashing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(flashing && !reduceMotion ? 0.92 : 1)
            .opacity(flashing && reduceMotion ? 0.6 : 1)
            .onChange(of: remote.commandCount) {
                guard remote.lastCommand == command else { return }
                withAnimation(.easeOut(duration: 0.08)) { flashing = true }
                withAnimation(.spring(duration: 0.35, bounce: 0.3).delay(0.08)) { flashing = false }
            }
    }
}

/// A borderless control living inside a shared glass shape (D-pad arrows, volume rocker).
struct InsetKey: View {
    @Environment(RemoteController.self) private var remote
    let command: RemoteCommand
    let symbol: String
    let name: String
    var size = CGSize(width: 36, height: 36)

    var body: some View {
        Button {
            Task { await remote.perform(command) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(CommandFlash(command: command))
        .accessibilityLabel(name)
        .accessibilityHint("Shortcut: \(KeyBindings.label(for: command))")
    }
}

/// A glass key bound to one remote command. Shows its shortcut and flashes when it fires.
struct KeyButton: View {
    @Environment(RemoteController.self) private var remote
    let command: RemoteCommand
    var title: String = ""
    var symbol: String?
    var accessibilityName: String?
    var live = false
    var height: CGFloat = 40
    var showsLegend = true

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Grid.keyRadius, style: .continuous) }

    var body: some View {
        Button {
            Task { await remote.perform(command) }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 5) {
                    if let symbol { Image(systemName: symbol).imageScale(.medium) }
                    if !title.isEmpty { Text(title).lineLimit(1).minimumScaleFactor(0.8) }
                }
                .font(.system(size: 12.5, weight: live ? .semibold : .medium))
                .foregroundStyle(.primary)
                .invertedInk(live)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsLegend {
                    ShortcutLegend(text: KeyBindings.label(for: command), inverted: live)
                        .padding(.trailing, 6)
                        .padding(.bottom, 4)
                }
            }
            .frame(height: height)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .glassSurface(shape, live: live)
        .modifier(CommandFlash(command: command))
        .accessibilityLabel(accessibilityName ?? title)
        .accessibilityHint("Shortcut: \(KeyBindings.label(for: command))")
        .accessibilityAddTraits(live ? .isSelected : [])
    }
}
