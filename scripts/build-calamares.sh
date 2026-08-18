#!/bin/sh
#=============================================================================
# windOS Zen — build Calamares from the AUR on the HOST and inject it as a
# local package into the ISO (airootfs/root/). The live chroot has no network
# during customize_airootfs.sh, so we cannot build it there.
#
# Run as a NORMAL (non-root) user. Build dependencies are installed via sudo.
#=============================================================================
set -eu

PROFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKGBUILD_SRC="${CALAMARES_AUR:-/tmp/calamares-aur}"
BUILD_DIR="/tmp/calamares-build"
OUT_DIR="$PROFILE_DIR/airootfs/root"
PKGVER="3.4.2"
PKGREL="2"

# NOTE: this host has -git KDE framework packages installed (e.g.
# extra-cmake-modules-git, kconfig-git) which conflict with the stable
# names. They are ABI-identical (same 6.28.0), so we build with `makepkg -d`
# (skip dependency resolution) and let the already-installed -git libs satisfy
# the build. The produced package still declares the stable dependency names,
# so it installs cleanly into the ISO's stable-lib chroot.
BUILD_DEPS="
  base-devel cmake libglvnd ninja
  qt6-tools qt6-translations boost git wget
"

echo "==> Installing Calamares build tools (sudo)..."
sudo pacman -S --needed --noconfirm $BUILD_DEPS

echo "==> Preparing build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Copying PKGBUILD from $PKGBUILD_SRC"
cp "$PKGBUILD_SRC/PKGBUILD" "$BUILD_DIR/"

echo "==> Pre-downloading source tarball (avoids codeberg flakiness in makepkg)"
( cd "$BUILD_DIR"
  src="calamares-${PKGVER}.tar.gz"
  url="https://codeberg.org/Calamares/calamares/releases/download/v${PKGVER}/${src}"
  wget -O "$src" "$url"
)

echo "==> Building calamares ${PKGVER}-${PKGREL} (makepkg -d, as $(whoami))..."
( cd "$BUILD_DIR"
  # -d : skip dependency resolution (host has -git KDE libs, ABI-identical).
  # makepkg uses the pre-downloaded source if present + checksum matches.
  makepkg -d --noconfirm
)

PKG="$BUILD_DIR/calamares-${PKGVER}-${PKGREL}-x86_64.pkg.tar.zst"
if [ ! -f "$PKG" ]; then
  echo "!! Build failed: $PKG not found" >&2
  exit 1
fi

echo "==> Injecting package into ISO overlay: $OUT_DIR"
mkdir -p "$OUT_DIR"
cp -v "$PKG" "$OUT_DIR/"

echo "==> Done. Calamares package ready at $OUT_DIR/$(basename "$PKG")"
