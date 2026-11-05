import AppKit
import SwiftUI

/// The LG Remote mark (branding/lgremote-symbol.svg), drawn on its 256-unit grid.
/// Two input keys; when `live`, the right one is solid and carries the on-air tally bar.
struct TallyMark: Shape {
    var live = true

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256
        let origin = CGPoint(x: rect.midX - 128 * s, y: rect.midY - 128 * s)
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: origin.x + x * s, y: origin.y + y * s, width: w * s, height: h * s)
        }
        var path = Path()
        let corner = 26 * s
        let inner = 6 * s
        // Left key: always an outline.
        path.addRoundedRect(in: r(32, 76, 80, 144), cornerSize: CGSize(width: corner, height: corner), style: .continuous)
        path.addRoundedRect(in: r(52, 96, 40, 104), cornerSize: CGSize(width: inner, height: inner), style: .continuous)
        // Right key: solid when live, outlined otherwise.
        path.addRoundedRect(in: r(144, 76, 80, 144), cornerSize: CGSize(width: corner, height: corner), style: .continuous)
        if live {
            path.addRoundedRect(in: r(160, 40, 48, 16), cornerSize: CGSize(width: 8 * s, height: 8 * s))
        } else {
            path.addRoundedRect(in: r(164, 96, 40, 104), cornerSize: CGSize(width: inner, height: inner), style: .continuous)
        }
        return path
    }
}

/// Template images for the menu bar, so macOS tints them like system icons.
@MainActor
enum MenuBarIcon {
    private static var cache: [Bool: NSImage] = [:]

    static func image(live: Bool) -> NSImage {
        if let cached = cache[live] { return cached }
        let renderer = ImageRenderer(
            content: TallyMark(live: live)
                .fill(.black, style: FillStyle(eoFill: true))
                .frame(width: 18, height: 18))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "av.remote", accessibilityDescription: nil)!
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        cache[live] = image
        return image
    }
}
