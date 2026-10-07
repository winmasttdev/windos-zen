#!/usr/bin/env python3
# ============================================================================
#  windOS Zen — logo image-to-ASCII generator
#  Renders assets/brand/logo-ascii.txt from the canonical SQUARE cloud icon.
#
#  Usage:   tools/logo-ascii.py [--src PNG] [--out FILE] [--bg RRGGBB]
#                               [--widths 24,48,72]
#  Defaults: --src assets/generated/icons/256x256/windos.png
#            --out assets/brand/logo-ascii.txt
#            --bg  0e0d16 (editorial warm black is 0e0d0b; see RATIONALE below)
#
#  IMPORTANT: use the SQUARE icon (256x256/windos.png, rendered from
#  assets/brand/windos-cloud.svg), NOT the wide wordmark banner
#  (assets/generated/logo/windos-logo-256.png). The banner's 900x200 canvas
#  is mostly empty dark pixels, so it ascii-maps to mush. The square icon
#  fills its frame and depicts a cloud.
#
#  RATIONALE --bg: the icon PNG is transparent-background; it must be
#  composited onto the dark terminal colour before luminance mapping.
#  Default is the brand night bg #090d16 (same canvas the SVGs are authored
#  on), so the glow halo maps to faint ramp chars instead of clipping.
# ============================================================================
import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("ERROR: needs Pillow (apt install python3-pil)\n")
    sys.exit(1)

RAMP = " .:-=+*#%@"
CHAR_ASPECT = 0.5  # monospace cells are ~2x taller than wide

SECTION_NAMES = ("NARROW", "MEDIUM", "WIDE")


def to_ascii(img_lum, width):
    w, h = img_lum.size
    height = max(1, int(round(h * width / w * CHAR_ASPECT)))
    small = img_lum.resize((width, height), Image.LANCZOS)
    px = list(small.tobytes())
    steps = len(RAMP) - 1
    rows = []
    for y in range(height):
        row = "".join(
            RAMP[min(px[y * width + x] * steps // 255, steps)]
            for x in range(width)
        ).rstrip()
        rows.append(row)
    # strip leading/trailing rows that are blank or halo-faint (only ' '/'.')
    while rows and not rows[0].strip(" ."):
        rows.pop(0)
    while rows and not rows[-1].strip(" ."):
        rows.pop()
    return rows


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description="windOS Zen logo image-to-ASCII")
    ap.add_argument("--src", default=os.path.join(
        root, "assets/generated/icons/256x256/windos.png"))
    ap.add_argument("--out", default=os.path.join(
        root, "assets/brand/logo-ascii.txt"))
    ap.add_argument("--bg", default="090d16")
    ap.add_argument("--widths", default="24,48,72")
    ap.add_argument("--floor", type=int, default=48,
                    help="luminance floor: the icon's soft glow halo lives "
                         "below ~48/255 on a dark composite and would "
                         "ascii-map to a fuzzy blob; lifting the floor keeps "
                         "the stroke ring crisp so the CLOUD reads")
    ap.add_argument("--pad", type=int, default=6,
                    help="transparent-margin trim padding, px")
    args = ap.parse_args()

    widths = [int(x) for x in args.widths.split(",") if x.strip()]
    if len(widths) != 3:
        sys.stderr.write("ERROR: --widths needs 3 values (narrow,medium,wide)\n")
        sys.exit(1)

    bg = tuple(int(args.bg[i:i + 2], 16) for i in (0, 2, 4))
    src = Image.open(args.src).convert("RGBA")
    # trim transparent margins so the mark fills the frame, then composite
    alpha = src.split()[3]
    bbox = alpha.point(lambda v: 255 if v > 16 else 0).getbbox()
    if bbox:
        l, u, r, b = bbox
        p = args.pad
        box = (max(0, l - p), max(0, u - p),
               min(src.width, r + p), min(src.height, b + p))
        src = src.crop(box)
        alpha = alpha.crop(box)
    canvas = Image.new("RGBA", src.size, bg + (255,))
    comp = Image.alpha_composite(canvas, src).convert("RGB").convert("L")
    # alpha-mask: the icon's soft glow halo is semi-transparent, the stroke
    # ring is fully opaque. Masking on alpha (not luminance) removes the halo
    # by construction instead of smearing it across the ramp as a fuzzy blob.
    bg_lum = int(round(0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2]))
    mask = alpha.point(lambda v: 255 if v >= 128 else 0)
    lum = Image.composite(comp, Image.new("L", comp.size, bg_lum), mask)
    # hard-clip the floor (no rescaling: rescaling would amplify halo
    # remnants back into visibility). Stroke body lives at 144+.
    lo = max(0, min(args.floor, 254))
    lum = lum.point(lambda v: 0 if v < lo else v)

    lines = [
        "windOS Zen — logo ASCII (generated from %s on #%s, image-to-ascii)"
        % (os.path.relpath(args.src, root), args.bg),
        "Ramp: '%s'. Monospace only, dark terminals." % RAMP,
        "",
    ]
    for name, width in zip(SECTION_NAMES, widths):
        lines.append("--- %s (%dch) ---" % (name, width))
        lines.extend(to_ascii(lum, width))
        lines.append("")

    with open(args.out, "w") as f:
        f.write("\n".join(lines))
    print("Wrote %s (%s)" % (args.out, ", ".join(
        "%s=%dch" % pair for pair in zip(SECTION_NAMES, widths))))


if __name__ == "__main__":
    main()
