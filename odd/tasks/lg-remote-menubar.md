# Feature: lg-remote-menubar
Objective: migrate the LG webOS CLI to a native macOS menu bar app (SwiftUI) under `mac/`.
Branch: feat/macos-menubar · Delivery: ask-on-risk · Test runner: `swift test` (mac/)

## Specs
- S1: "en lugar de cli sea una app para mac que tipo tenga tu icono aquí arriba" — menu bar icon (own template icon, not the Claude logo).
- S2: "cuando le de click se abra un modal hermoso con las opciones a realizar" — click opens a panel with every CLI action (arrows/OK/Back, Home, Quick settings, Volume +/-, Mute, HDMI 1-4, YouTube, Netflix, Power off, Wake-on-LAN).
- S3: "me permita o darle click o usar el teclado" — every action reachable by mouse and by keyboard, same shortcuts as the CLI.
- S4: "el diseño del modal lo podrás diseñar usando la skill de impecable" — panel designed with the `impeccable` skill.
- S5 (from approved plan): keep compatibility patches — unsigned manifest, PIN pairing, ws:3000 → wss:3001 fallback, no getCurrentSWInformation; import existing config.json; in-panel onboarding (SSDP / manual IP, PIN); clear connection states with reconnect.
- S6 (from approved plan): Python CLI stays unchanged.

## Tasks
| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S3,S5 | inline | done | d67e799 |
| T2 | S2,S5 | inline | done | a8dfe79 |
| T3 | S5 | inline | done | 909ef34 |
| T4 | S5 | inline | done | f15bfd1 |
| T5 | S1-S4 | inline | done | 2c3d1e1 |
| T6 | S1 | inline | done | 75c6ad0 |

T1 domain+ports+config store/import · T2 network adapters (WOL, SSDP, ARP) · T3 SSAP client + pointer socket + PIN pairing · T4 RemoteController (states, reconnect) · T5 UI (impeccable) + MenuBarExtra + onboarding · T6 build-app.sh + Info.plist + README.
Route evidence: no Writer trigger (units are sequential/dependent); parent writes inline.

## Log
- L1 (2026-11-04): "me gustaría migrar esta app para que en lugar de cli sea una app para mac que tipo tenga tu icono aquí arriba [Image #1] y cuando le de click se abra un modal hermoso con las opciones a realizar y me permita o darle click o usar el teclado. el diseño del modal lo podrás diseñar usando la skill de impecable. Valida la idea, mejora el prompt"
- L2: User chose "Swift nativo". Plan approved.
- L3: SSAP live smoke test could not run from the agent sandbox ("No route to host"); `LiveTVTests` left env-gated for the user (`LGREMOTE_LIVE_CONFIG=../config.json swift test --filter LiveTVTests`).
- L4 (impeccable): PRODUCT.md written (user: "Mac en el escritorio"). Roll seed:a1c6672a49ca865f → user chose "Mesa de switcheo" with note verbatim: "Si se puede usar liquid glass mejor, con colorea monocromáticos, blanco y negro, elegante y moderno." Decision page server died in sandbox; fallback to AskUserQuestion. Direction contract in .impeccable/surfaces/mac-sources-lgremote-ui.md. Finish-reviewer/documenter agents not available in this harness → DESIGN.md pending.
- L5: Added LiveSource (foreground app → tally) and commandCount (flash on repeated key). 42 tests green. Visual check via DEBUG preview harness (LGREMOTE_PREVIEW) in light/dark for connected/unreachable/setup/pin; fixed hidden D-pad arrows, inverted-ink contrast, rocker shape, truncated copy.
- L6: Risk item 2 (TLS trust limited to TV host, client key 0600) → independent verifier launched.
