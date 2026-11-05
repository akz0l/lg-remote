---
version: 1
slug: "mac-sources-lgremote-ui"
primary_target: "mac/Sources/LGRemote/UI"
related_targets: []
---

# Surface: menu bar remote panel

Scope: MenuBarExtra window panel (~320pt), remote + onboarding states. Mode: Operate.
Task: open, press one key or click, close. Keyboard-first desk use. Must stay findable in seconds.
Constraints: native SwiftUI controls; macOS 14 fallback; Spanish copy.
User steer (verbatim): "Si se puede usar liquid glass mejor, con colorea monocromáticos, blanco y negro, elegante y moderno."

## Direction contract
FORM: Vision-mixer switcher (seed:a1c6672a49ca865f), chosen card "Mesa de switcheo", fused with Liquid Glass, monochrome.
THESIS: Switching input is cutting to camera: the input on screen carries the tally. Refuses the Control Center tile grid.
OWN-WORLD: Liquid Glass keys (.glassEffect, interactive) in a GlassEffectContainer on the system panel material; strictly black/white/greys, no hue. Tally = solid white (dark) / black (light) 3pt bar + inverted label on the live input. Shortcut legends in SF Mono 10pt, secondary opacity.
STORY: Header says if commands will land (filled dot = live, hollow = off, breathing = connecting). Rows: inputs bus, apps, nav cluster (Back/Home/Settings, round D-pad, volume rocker), footer with mute and isolated power.
FIRST VIEWPORT: The whole panel; inputs bus on top as the signature.
SIGNATURE: Tally bar slides to the newly live input (matchedGeometry; crossfade under Reduce Motion); keys flash when their shortcut fires.
RAISES: Grid fixed, only state changes (split-flap). One 4-column grid governs all rows (Crouwel).
