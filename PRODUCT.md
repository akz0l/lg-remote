# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native SwiftUI menu bar app; not one of web/ios/android/adaptive — follows the macOS Human Interface Guidelines)

## Users
A single owner of an LG webOS TV whose physical remote broke. Primary scene (confirmed): working at the Mac desk and occasionally switching HDMI, adjusting volume, or launching an app on the TV. Keyboard-first: open the panel, press a key, close it.

## Product Purpose
Control an LG webOS TV from the Mac menu bar — navigation, volume, inputs, apps, power off, and power on via Wake-on-LAN even when the TV is fully off. Success: any action is one click on the menu bar icon plus one keystroke, with no terminal.

## Positioning
Works with recent webOS firmware (22+) that rejects the signed pairing manifest other tools use: pairs by PIN with an unsigned manifest, so it needs neither the physical remote nor accepting an on-screen prompt.

## Operating Context
Menu bar panel opened briefly while doing other work; the TV is across the room. The TV and the Mac share a local network. First run discovers the TV via SSDP (or manual IP), shows a PIN on the TV, and the user types it in the panel. An existing CLI `config.json` can be imported.

## Capabilities and Constraints
- Actions and shortcuts mirror the original CLI: arrows navigate, Return = OK, Delete = Back, H Home, S Quick settings, +/- volume, M mute, 1–4 HDMI, Y YouTube, N Netflix, P power off, W power on (Wake-on-LAN). Esc closes the panel.
- Power on requires the TV's MAC (captured automatically on first connection).
- UI copy is English (public open-source project).

## Brand Commitments
Product name "LG Remote" is descriptive only; do not use LG's logo or wordmark, nor the Claude logo, as the menu bar icon.

## Evidence on Hand
None (personal tool). Do not fabricate testimonials or claims.

## Product Principles
1. Keyboard first, mouse always possible.
2. Never a dead end: when the TV is off or unreachable, the next step (wake, retry, re-pair) is offered right there.
3. Honest state: the panel always shows whether commands will reach the TV.
4. Destructive actions (power off) are hard to hit by accident.

## Accessibility & Inclusion
Full VoiceOver labels, respect Reduce Motion and Increase Contrast, light and dark appearance.
