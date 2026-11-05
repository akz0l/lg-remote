# LG Remote — logo

**Idea:** two input keys; the live one is solid and carries the on-air tally bar — the same signature as the
remote panel. It also reads as 0 / 1 (off / on).

| File | Use |
|---|---|
| `lgremote-symbol.svg` | Master mark, 256-unit grid, black |
| `variants/lgremote-symbol-black.svg`, `-white.svg` | One-colour versions for light / dark backgrounds |
| `lgremote-appicon.svg` | macOS app icon master (1024 canvas, Apple grid: 824 body, 100 margin) |
| `../mac/Resources/AppIcon.icns` | Built app icon (16–1024 px), referenced by `CFBundleIconFile` |
| `concepts/` | Exploration (A chosen; B D-pad and C legend discarded) |

The menu bar icon is drawn in code from the same geometry (`mac/Sources/LGRemote/UI/TallyMark.swift`):
connected = right key solid with the tally bar; disconnected = both keys outlined, no bar.

## Usage
- Colours: `#0E0E10` (icon ground) and `#FFFFFF`. Monochrome only; no LG red, no gradients.
- Clear space: the height of the tally bar (16 units) on every side.
- Minimum size: 16 px (the outline stays ≥1 px).
- Don't: rotate, add colour, separate the tally bar from its key, put it on busy photos, or pair it with the LG logo.

## Rebuild the icon
1. Edit `lgremote-appicon.svg`.
2. Render 16, 32, 64, 128, 256, 512, 1024 px PNGs into an `AppIcon.iconset` (`icon_16x16.png`, `icon_16x16@2x.png`, …).
3. `iconutil -c icns AppIcon.iconset -o mac/Resources/AppIcon.icns`, then `mac/scripts/build-app.sh --install`.

Trademark clearance was not checked; "LG" is a trademark of LG Electronics and is used here only descriptively.
