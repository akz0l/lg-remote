# Command-line version (Python)

The original keyboard remote for the terminal. Useful on Linux or in scripts. It shares the same pairing approach
as the Mac app (PIN + unsigned manifest) and its `config.json` can be imported by the app.

> The CLI's on-screen messages are still in Spanish — translating them is a [good first issue](../CONTRIBUTING.md).

## Requirements

- Python 3.9+
- The TV and the computer on the same local network.

## Install

```bash
git clone https://github.com/akz0l/lg-remote.git
cd lg-remote
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
```

## First run (pairing)

```bash
./venv/bin/python lg_remote.py
```

- Finds the TV via SSDP. If it can't, pass the IP: `--ip 192.168.1.50`.
- The first time it asks for a **PIN**: read it on the TV and type it in the terminal.
- Saves the client key, the MAC (for Wake-on-LAN) and the app/HDMI mapping to `config.json` (git-ignored).

## Keys

| Key | Action |
|---|---|
| Arrows | Navigate |
| Enter | OK / select |
| Delete / Backspace | Back |
| `h` | Home |
| `s` | Quick settings |
| `+` / `-` | Volume |
| `m` | Mute |
| `1`–`4` | HDMI 1–4 |
| `y` | YouTube |
| `n` | Netflix |
| `p` | Power off |
| `w` | Power on (Wake-on-LAN) |
| `?` | Help |
| `q` | Quit |

## Options

- `--encender`: only power on the TV (Wake-on-LAN) and exit.
- `--ip <IP>`: use this IP instead of SSDP discovery.
- `--rediscover`: forget the saved IP and search again.

Shell alias: add `alias lgtv="/path/to/lg-remote/lgtv.sh"` to `~/.zshrc`.

## Technical note: blocked certificate

Recent webOS firmware (22+) rejects the signed pairing manifest that `aiowebostv` ships since 2014
(`403 Pairing rejected: blacklisted certificate detected`). The CLI patches it at runtime by sending an unsigned
manifest, pairs by PIN instead of the on-screen prompt, and skips `getCurrentSWInformation` (which requires a
permission only signed manifests get).
