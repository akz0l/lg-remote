# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Report them privately via
[GitHub Security Advisories](https://github.com/akz0l/lg-remote/security/advisories/new). You'll get a reply within a
few days, and credit in the release notes if you want it.

## What's in scope

- Handling of the TV client key (stored in `~/Library/Application Support/LGRemote/config.json`, mode `600`).
- TLS trust: the app accepts the TV's self-signed certificate **only** for the TV's own host.
- Anything that could let another device on the network control the TV through the app.

## Known limitations

- When the TV still serves the unencrypted port `3000`, pairing and commands travel in cleartext on the local
  network (the same as the official protocol). Newer firmware uses `wss://` on port `3001`.
- The TV's certificate is not pinned after first pairing.
