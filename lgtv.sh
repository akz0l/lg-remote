#!/usr/bin/env bash
# Wrapper para lanzar el control remoto de la TV LG webOS desde cualquier lugar.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/venv/bin/python" "$DIR/lg_remote.py" "$@"
