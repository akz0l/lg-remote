# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-11-04

### Added
- Native macOS menu bar app (SwiftUI, macOS 14+) with a Liquid Glass, monochrome remote panel (macOS 26+).
- Keyboard shortcuts on every control, matching the CLI; `Esc` closes the panel.
- Live-source tally: the input or app currently on screen is highlighted; the menu bar icon shows the tally while connected.
- First-run setup: SSDP discovery, manual IP, PIN pairing, and import of the CLI's `config.json`.
- Wake-on-LAN power on with automatic MAC detection, and automatic reconnection.
- LG Remote logo and app icon.
- Contributor docs, issue templates, and CI.

### Kept
- The original Python CLI (`lg_remote.py`), now documented in `docs/cli.md`.

[1.0.0]: https://github.com/akz0l/lg-remote/releases/tag/v1.0.0
