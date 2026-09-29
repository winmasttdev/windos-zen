#!/usr/bin/env bash
# ============================================================================
#  windOS Zen — build-iso.sh (Module 1)
#  Builds the Debian 13 "Trixie" Live ISO. Run on a Debian 13 builder.
#  Deps: live-build, cdebootstrap|debootstrap, squashfs-tools, xorriso,
#        librsvg2-bin (assets), dosfstools, mtools, grub-efi-amd64-bin.
# ============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
# 1. regenerate brand bitmaps from SVG masters
./../tools/gen-assets.sh
# 2. sync generated bitmaps into the chroot/binary overlays
PLYM_OUT="config/includes.chroot/usr/share/plymouth/themes/windos-zen"
mkdir -p "$PLYM_OUT"
cp ../assets/generated/plymouth/windos-logo*.png "$PLYM_OUT/" 2>/dev/null || true
cp ../assets/generated/plymouth/background-1920-1080.png "$PLYM_OUT/background.png" 2>/dev/null || true
cp -r ../assets/generated/plymouth/spinner "$PLYM_OUT/" 2>/dev/null || true
cp ../modules/02-plymouth/windos-zen.plymouth ../modules/02-plymouth/windos-zen.script "$PLYM_OUT/"
SKEL="$ROOT/config/includes.chroot/etc/skel"
mkdir -p "$SKEL"
cp -r ../modules/03-fluxbox/skel/. "$SKEL/"
# 3. configure + build
lb clean --purge 2>/dev/null || lb clean || true
sh auto/config
lb build 2>&1 | tee build.log
echo "OK: $(ls -1 *.iso 2>/dev/null | head -1)"
