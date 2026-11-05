# Contributing to LG Remote

Thanks for wanting to help! This is a small project, so every contribution matters — code, a bug report from a TV
model we haven't seen, docs, design, or translations.

## Ways to help

- **Report your TV.** Open a [TV compatibility report](https://github.com/akz0l/lg-remote/issues/new?template=tv_report.yml)
  with your model and webOS version, whether it works or not.
- **Fix a bug or build a feature.** Look for issues labelled
  [`good first issue`](https://github.com/akz0l/lg-remote/labels/good%20first%20issue) or
  [`help wanted`](https://github.com/akz0l/lg-remote/labels/help%20wanted). Comment on the issue so we don't duplicate work.
- **Improve docs or translations.** A Spanish (or any) localization of the panel, the CLI's messages, or clearer setup steps.

For anything bigger than a small fix, please open an issue first to agree on the approach.

## Development setup

You need macOS 14+ and Xcode 26 (or its Command Line Tools).

```bash
git clone https://github.com/akz0l/lg-remote.git
cd lg-remote/mac
swift test                                   # unit tests (no TV needed)
LGREMOTE_PREVIEW=connected swift run LGRemote  # the panel with a simulated TV
```

Preview scenarios: `connected`, `unreachable`, `setup`, `pin`. Add `LGREMOTE_APPEARANCE=light|dark` to force an
appearance. To test against a real, already paired TV (read-only):

```bash
LGREMOTE_LIVE_CONFIG=/path/to/config.json swift test --filter LiveTVTests
```

## Project layout

- `mac/Sources/LGRemoteCore` — domain, ports and adapters. No UI; everything here should be unit tested.
- `mac/Sources/LGRemote` — the SwiftUI menu bar app.
- `lg_remote.py` — the original Python CLI.
- `branding/` — logo sources and usage rules.

Keep the layering: the domain and `RemoteController` talk to the TV only through the protocols in `Ports/`, so they
can be tested with fakes (see `RemoteControllerTests.swift`).

## Pull requests

1. Fork and create a branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Add or update tests for behavior changes; `swift test` must pass.
3. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`…).
4. For UI changes, include before/after screenshots (light and dark).
5. Keep PRs focused — about 400 changed lines is a good upper bound for a smooth review.

## Design guidelines

The panel follows a few principles: keyboard first, honest connection state, no dead ends, monochrome Liquid Glass.
The tally bar marks only what's live on the TV. Please keep new controls on the panel's 4-column grid and show their
shortcut.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## License

By contributing, you agree that your contributions are licensed under the [GPL-3.0](LICENSE).
