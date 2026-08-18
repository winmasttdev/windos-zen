#!/usr/bin/env bash
#
# build.sh — build the windOS Zen live ISO.
# Requires an Arch Linux host with archiso + grub installed (see
# scripts/install-deps.sh). Must run as root (mkarchiso needs it).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/out}"
WORK="${WINDOS_WORK:-/tmp/windos-zen-work}"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (mkarchiso requirement)." >&2
    echo "Try: sudo $0" >&2
    exit 1
fi

# 1. Make sure we have a logo (download / local / placeholder).
"$ROOT/scripts/fetch-logo.sh"

# 2. Build.
rm -rf "$WORK"
mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$ROOT"

echo
echo "==> windOS Zen ISO written to: $OUT"
ls -lh "$OUT"/*.iso 2>/dev/null || true
