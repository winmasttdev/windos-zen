#!/usr/bin/env bash
#
# fetch-logo.sh — obtain & rasterize the windOS cloud logo for Plymouth
#                 and (later) wallpapers.
#
# Priority:
#   1. Local override  -> $WINDOS_LOGO_SVG  (or ./assets/logo.svg)
#   2. Remote download -> $WINDOS_LOGO_URL  (default: windos.nn1kk00.ru)
#   3. Generated placeholder cloud (so the ISO still builds)
#
# You said you'll provide the real logo later: just drop your SVG at
#   assets/logo.svg
# or export WINDOS_LOGO_SVG=/path/to/cloud.svg before running build.sh.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_DIR="$ROOT/airootfs/usr/share/plymouth/themes/windos-zen"
ASSET_DIR="$ROOT/assets"
mkdir -p "$THEME_DIR" "$ASSET_DIR"

URL="${WINDOS_LOGO_URL:-https://windos.nn1kk00.ru/logo.svg}"

# Prefer a real asset dropped into ./assets (svg > png > jpg).
# Override explicitly with $WINDOS_LOGO_SVG / $WINDOS_LOGO_PNG / $WINDOS_LOGO_JPG.
LOCAL_SVG="${WINDOS_LOGO_SVG:-$ASSET_DIR/logo.svg}"
LOCAL_PNG="${WINDOS_LOGO_PNG:-$ASSET_DIR/logo.png}"
LOCAL_JPG="${WINDOS_LOGO_JPG:-$ASSET_DIR/logo.jpg}"

PNG="$THEME_DIR/windos-logo.png"

generate_placeholder() {
    # Minimal cloud SVG so the build never hard-fails without a real asset.
    cat > "$1" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <g fill="#3b82f6">
    <path d="M150 330a70 70 0 0 1 14-139 90 90 0 0 1 172-18 64 64 0 0 1 16 127H150z" opacity="0.95"/>
    <path d="M322 360a40 40 0 0 1-6-79 60 60 0 0 1 116-13 44 44 0 0 1 10 92H322z" opacity="0.55"/>
  </g>
</svg>
SVG
    echo "  -> generated placeholder cloud at $1"
}

resolve_source() {
    if [[ -f "$LOCAL_SVG" ]]; then
        echo "Using local logo: $LOCAL_SVG"
        SRC="$LOCAL_SVG"
    elif [[ -f "$LOCAL_PNG" ]]; then
        echo "Using local logo: $LOCAL_PNG"
        SRC="$LOCAL_PNG"
    elif [[ -f "$LOCAL_JPG" ]]; then
        echo "Using local logo: $LOCAL_JPG"
        SRC="$LOCAL_JPG"
    elif command -v curl >/dev/null 2>&1; then
        echo "Downloading logo from $URL"
        if curl -fsSL "$URL" -o "$ASSET_DIR/logo.svg"; then
            SRC="$ASSET_DIR/logo.svg"
        else
            echo "  download failed; using placeholder" >&2
            generate_placeholder "$ASSET_DIR/logo.svg"
            SRC="$ASSET_DIR/logo.svg"
        fi
    else
        echo "  no curl and no local SVG; using placeholder" >&2
        generate_placeholder "$ASSET_DIR/logo.svg"
        SRC="$ASSET_DIR/logo.svg"
    fi
}

rasterize() {
    case "$SRC" in
        *.svg)
            if command -v rsvg-convert >/dev/null 2>&1; then
                rsvg-convert -w 1024 -h 1024 "$SRC" -o "$PNG"
            elif command -v inkscape >/dev/null 2>&1; then
                inkscape "$SRC" -w 1024 -h 1024 -o "$PNG"
            elif command -v magick >/dev/null 2>&1; then
                magick "$SRC" -background none -resize 1024x1024 "$PNG"
            else
                echo "ERROR: no SVG rasterizer (librsvg/inkscape/imagemagick)." >&2
                exit 1
            fi
            ;;
        *)
            # Already-raster source: normalize to a 512px transparent PNG.
            # Corner-flood removes a flat (e.g. white) background if present;
            # no-op on sources that are already transparent.
            if command -v magick >/dev/null 2>&1; then
                magick "$SRC" -fuzz 8% -fill none \
                    -draw "color 0,0 floodfill"   -draw "color 639,0 floodfill" \
                    -draw "color 0,639 floodfill" -draw "color 639,639 floodfill" \
                    -background none -resize 512x512 "$PNG"
            elif command -v convert >/dev/null 2>&1; then
                convert "$SRC" -fuzz 8% -fill none \
                    -draw "color 0,0 floodfill"   -draw "color 639,0 floodfill" \
                    -draw "color 0,639 floodfill" -draw "color 639,639 floodfill" \
                    -background none -resize 512x512 "$PNG"
            else
                echo "ERROR: ImageMagick required to process raster logo." >&2
                exit 1
            fi
            ;;
    esac
}

resolve_source
rasterize
echo "Wrote $PNG ($(stat -c %s "$PNG") bytes)"
