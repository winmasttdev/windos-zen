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
# NOTE: the Plymouth boot splash is NOT staged any more. plymouth is not in the
# package list (owner decision: verbose boot), so /usr/share/plymouth/themes/ in
# the chroot would be a theme with no daemon to run it — dead weight plus ~5 MB
# of PNGs in the squashfs. The sources stay put in modules/02-plymouth/ and
# assets/brand/plymouth-*.svg, so re-enabling the splash is: add plymouth +
# plymouth-themes to config/package-lists/00-minimal.list.chroot, restore the
# 020 registration hook, and re-add the staging block below.
SKEL="$ROOT/config/includes.chroot/etc/skel"
mkdir -p "$SKEL"
cp -r ../modules/03-fluxbox/skel/. "$SKEL/"
# 3. configure + build
# Use every core for squashfs: live-build passes no -processors flag itself,
# but mksquashfs honors $MKSQUASHFS_OPTIONS. xz + x86 BCJ filter = maximum
# practical density for an x86_64 payload (BCJ pre-filters executables;
# dict left at default — a bigger window risks OOM decompress on 1 GB boxes).
NPROC="$(nproc 2>/dev/null || echo 4)"
export MKSQUASHFS_OPTIONS="-processors ${NPROC} -comp xz -Xbcj x86"
lb clean --purge 2>/dev/null || lb clean || true
sh auto/config
lb build 2>&1 | tee build.log
echo "OK: $(ls -1 *.iso 2>/dev/null | head -1)"
