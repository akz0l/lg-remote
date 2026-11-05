import SwiftUI

/// Panel geometry: one 4-column grid governs every row.
enum Grid {
    static let width: CGFloat = 320
    static let padding: CGFloat = 14
    static let gap: CGFloat = 6
    static let content = width - padding * 2
    static let column = (content - gap * 3) / 4
    static func span(_ columns: Int) -> CGFloat {
        column * CGFloat(columns) + gap * CGFloat(columns - 1)
    }
    static let keyRadius: CGFloat = 10
}

/// Liquid Glass on macOS 26+, a quiet monochrome fill before that.
/// `live` inverts the key (the tally state): solid primary with background-colored ink.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var live = false
    var interactive = true

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content.background(live ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary), in: shape)
        }
    }

    @available(macOS 26, *)
    private var glass: Glass {
        let base: Glass = live ? .regular.tint(.primary) : .regular
        return base.interactive(interactive)
    }
}

extension View {
    func glassSurface<S: Shape>(_ shape: S, live: Bool = false, interactive: Bool = true) -> some View {
        modifier(GlassSurface(shape: shape, live: live, interactive: interactive))
    }
}

/// Groups glass shapes so neighbors blend like one material (macOS 26+).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = Grid.gap
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Ink for content on an inverted (live) surface: black on white glass, white on black glass.
struct InvertedInk: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var active: Bool
    var opacity: Double = 1
    func body(content: Content) -> some View {
        if active {
            content.foregroundStyle((scheme == .dark ? Color.black : Color.white).opacity(opacity))
        } else {
            content
        }
    }
}

extension View {
    func invertedInk(_ active: Bool, opacity: Double = 1) -> some View {
        modifier(InvertedInk(active: active, opacity: opacity))
    }
}

/// Small shortcut legend shown in the corner of each key.
struct ShortcutLegend: View {
    let text: String
    var inverted = false
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .invertedInk(inverted, opacity: 0.6)
            .accessibilityHidden(true)
    }
}
