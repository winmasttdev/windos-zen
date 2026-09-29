#!/usr/bin/env bash
# ============================================================================
#  windOS Zen — brand asset generator
#  Renders every bitmap the distro needs from the SVG masters in assets/brand/.
#  No ImageMagick, no Inkscape: rsvg-convert (librsvg2-bin) + fontconfig only,
#  so it runs on a stock Debian Bookworm builder.
#
#  Usage:   tools/gen-assets.sh [--out DIR]
#  Output:  assets/generated/**   (copied into the live-build tree by build-iso.sh)
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAND="$ROOT/assets/brand"
OUT="$ROOT/assets/generated"
[[ "${1:-}" == "--out" && -n "${2:-}" ]] && OUT="$2"

# --- make the bundled Plus Jakarta Sans visible to librsvg -------------------
FCDIR="$(mktemp -d)"
trap 'rm -rf "$FCDIR"' EXIT
cat > "$FCDIR/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$BRAND/fonts</dir>
  <dir>/usr/share/fonts</dir>
  <cachedir prefix="xdg">fontconfig</cachedir>
  <match target="pattern">
    <test name="family"><string>Plus Jakarta Sans</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Plus Jakarta Sans</string></edit>
  </match>
</fontconfig>
EOF
export FONTCONFIG_PATH="$FCDIR"

mkdir -p "$OUT"/{plymouth/spinner,wallpaper,calamares,icons,logo}

RSVG="${RSVG:-rsvg-convert}"
command -v "$RSVG" >/dev/null 2>&1 || { echo "ERROR: install librsvg2-bin (apt install librsvg2-bin)" >&2; exit 1; }

svg2png() { # svg2png <in.svg> <out.png> <width> [height]
  local in="$1" out="$2" w="$3" h="${4:-}"
  if [[ -n "$h" ]]; then "$RSVG" -f png -w "$w" -h "$h" -o "$out" "$in"
  else "$RSVG" -f png -w "$w" -o "$out" "$in"; fi
  printf '  %-46s %sx%-5s %8s B\n' "${out#$OUT/}" "$w" "${h:-auto}" "$(stat -c%s "$out")"
}

echo "== windOS Zen :: brand assets =="

# ---------------------------------------------------------------- Plymouth ---
echo "[1/7] plymouth logo + background"
for s in 64 128 256 512; do
  svg2png "$BRAND/windos-cloud.svg" "$OUT/plymouth/windos-logo-$s.png" "$s" "$s"
done
cp "$OUT/plymouth/windos-logo-256.png" "$OUT/plymouth/windos-logo.png"
for res in 1920x1080 1366x768 1024x768; do
  w="${res%x*}"; h="${res#*x}"
  svg2png "$BRAND/plymouth-background.svg" "$OUT/plymouth/background-$w-$h.png" "$w" "$h"
done

# centre lockup + progress-bar / password-dot primitives used by the script theme
svg2png "$BRAND/plymouth-lockup.svg" "$OUT/plymouth/windos-lockup.png" 512 300
BAR_SVG="$(mktemp /tmp/bar.XXXXXX.svg)"
cat > "$BAR_SVG" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="6" viewBox="0 0 320 6">
  <rect x="0" y="1" width="320" height="4" rx="2" fill="#ffffff" fill-opacity="0.09"/>
</svg>
EOF
svg2png "$BAR_SVG" "$OUT/plymouth/bar-track.png" 320 6; rm -f "$BAR_SVG"
SEG_SVG="$(mktemp /tmp/seg.XXXXXX.svg)"
cat > "$SEG_SVG" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6" viewBox="0 0 8 6">
  <rect x="0" y="1" width="8" height="4" fill="#38bdf8" fill-opacity="0.95"/>
</svg>
EOF
svg2png "$SEG_SVG" "$OUT/plymouth/bar-seg.png" 8 6; rm -f "$SEG_SVG"
# rounded ends for the fill bar
SEGL_SVG="$(mktemp /tmp/segl.XXXXXX.svg)"
cat > "$SEGL_SVG" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6" viewBox="0 0 8 6">
  <rect x="0" y="1" width="8" height="4" rx="2" fill="#7dd3fc"/>
</svg>
EOF
svg2png "$SEGL_SVG" "$OUT/plymouth/bar-seg-cap.png" 8 6; rm -f "$SEGL_SVG"
DOT_SVG="$(mktemp /tmp/dot.XXXXXX.svg)"
cat > "$DOT_SVG" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12">
  <circle cx="6" cy="6" r="3.4" fill="#e0f2fe"/>
</svg>
EOF
svg2png "$DOT_SVG" "$OUT/plymouth/pw-dot.png" 12 12; rm -f "$DOT_SVG"

# ------------------------------------------------------- Plymouth spinner ---
echo "[2/7] plymouth spinner (24 frames, 96px, CPU-cheap)"
FRAMES="${PLYMOUTH_SPINNER_FRAMES:-24}"
SIZE="${PLYMOUTH_SPINNER_SIZE:-96}"
C=$(( SIZE / 2 ))
R=$(( SIZE / 2 - 9 ))
TMP="$(mktemp -d /tmp/spinner.XXXXXX)"
for (( i = 0; i < FRAMES; i++ )); do
  ang=$(( i * 360 / FRAMES ))
  cat > "$TMP/f.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$SIZE" height="$SIZE" viewBox="0 0 $SIZE $SIZE">
  <defs>
    <linearGradient id="a" gradientUnits="userSpaceOnUse" x1="$((C-R))" y1="$C" x2="$((C+R))" y2="$C">
      <stop offset="0"   stop-color="#38bdf8" stop-opacity="0"/>
      <stop offset="0.4" stop-color="#7dd3fc" stop-opacity="0.55"/>
      <stop offset="1"   stop-color="#ffffff" stop-opacity="1"/>
    </linearGradient>
  </defs>
  <circle cx="$C" cy="$C" r="$R" fill="none" stroke="#38bdf8" stroke-opacity="0.14" stroke-width="3"/>
  <g transform="rotate($ang $C $C)">
    <path d="M $((C-R)) $C A $R $R 0 0 1 $((C+R)) $C" fill="none"
          stroke="url(#a)" stroke-width="3" stroke-linecap="round"/>
  </g>
</svg>
EOF
  printf -v idx '%02d' "$i"
  "$RSVG" -f png -w "$SIZE" -h "$SIZE" -o "$OUT/plymouth/spinner/spinner-$idx.png" "$TMP/f.svg"
done
rm -rf "$TMP"
echo "  spinner/spinner-00..$(printf '%02d' $((FRAMES-1))).png  (${FRAMES} frames @ ${SIZE}px)"

# -------------------------------------------------------------- Wallpaper ---
echo "[3/7] desktop wallpaper"
svg2png "$BRAND/wallpaper.svg" "$OUT/wallpaper/windos-zen-1920x1080.png" 1920 1080
svg2png "$BRAND/wallpaper.svg" "$OUT/wallpaper/windos-zen-1366x768.png"  1366 768
svg2png "$BRAND/wallpaper.svg" "$OUT/wallpaper/windos-zen-2560x1440.png" 2560 1440
# legacy CRT / netbook fallback
svg2png "$BRAND/wallpaper.svg" "$OUT/wallpaper/windos-zen-1024x768.png"  1024 768

# -------------------------------------------------------------- Calamares ---
echo "[4/7] calamares installer art"
svg2png "$BRAND/calamares-sidebar.svg" "$OUT/calamares/windos-sidebar.png" 160 520
# productWelcome / banner strip reuses the lockup at installer-header scale
svg2png "$BRAND/windos-logo.svg"       "$OUT/calamares/windos-banner.png"  600 133

# ------------------------------------------------------------------- Logo ---
echo "[5/7] wordmark lockups"
svg2png "$BRAND/windos-logo.svg" "$OUT/logo/windos-logo-1024.png" 1024 228
svg2png "$BRAND/windos-logo.svg" "$OUT/logo/windos-logo-512.png"   512 114
svg2png "$BRAND/windos-logo.svg" "$OUT/logo/windos-logo-256.png"   256 57

# ------------------------------------------------------------------ Icons ---
echo "[6/7] hicolor icon set (for .desktop launchers + lightdm-gtk-greeter)"
for s in 16 22 24 32 48 64 96 128 256 512 1024; do
  mkdir -p "$OUT/icons/${s}x${s}"
  svg2png "$BRAND/windos-cloud.svg" "$OUT/icons/${s}x${s}/windos.png" "$s" "$s"
done
mkdir -p "$OUT/icons/scalable"
cp "$BRAND/windos-cloud.svg" "$OUT/icons/scalable/windos.svg"

# favicon.ico (multi-resolution, PNG-compressed entries) + apple-touch-icon.
# Packed with python3-stdlib only (struct) — no Pillow/ImageMagick, so this
# still runs on a stock Debian Bookworm builder.
FAV_TMP="$(mktemp -d /tmp/favicon.XXXXXX)"
for s in 16 32 48; do
  svg2png "$BRAND/windos-cloud.svg" "$FAV_TMP/fav-$s.png" "$s" "$s"
done
svg2png "$BRAND/windos-cloud.svg" "$OUT/apple-touch-icon.png" 180 180
python3 - "$FAV_TMP" "$OUT/favicon.ico" <<'EOF'
import struct, sys
tmp, out = sys.argv[1], sys.argv[2]
sizes = [16, 32, 48]
blobs = [open(f"{tmp}/fav-{s}.png", "rb").read() for s in sizes]
count = len(blobs)
offset = 6 + 16 * count
hdr = struct.pack("<HHH", 0, 1, count)
entries = b""
for s, b in zip(sizes, blobs):
    entries += struct.pack("<BBBBHHII", s, s, 0, 0, 1, 32, len(b), offset)
    offset += len(b)
open(out, "wb").write(hdr + entries + b"".join(blobs))
print(f"  favicon.ico ({', '.join(str(s) for s in sizes)}px PNG entries)")
EOF
rm -rf "$FAV_TMP"

# ------------------------------------------------------------- Manifest ---
echo "[7/7] manifest"
{
  echo "# windOS Zen generated brand assets"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# source:    assets/brand/*.svg  (edit the SVGs, then re-run tools/gen-assets.sh)"
  echo "# renderer:  $("$RSVG" --version 2>&1 | head -1)"
  echo
  ( cd "$OUT" && find . -type f | sort | sed 's|^\./||' | while read -r f; do
      printf '%-46s %8d B\n' "$f" "$(stat -c%s "$f")"
    done )
} > "$OUT/MANIFEST.txt"
cat "$OUT/MANIFEST.txt" | head -4
echo
echo "TOTAL: $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1)"
echo "Done -> $OUT"
