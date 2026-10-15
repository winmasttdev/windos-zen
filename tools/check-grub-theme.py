#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-literal
"""windOS Zen — offline validator for GRUB gfxmenu theme files.

grub-script-check validates grub.cfg, NOT theme.txt. GRUB ships no theme
linter, and one bad line makes gfxmenu's theme_loader abort the ENTIRE theme,
so the installed system silently boots into a bare Debian-styled menu. This
reimplements the parser of grub-core/gfxmenu/theme_loader.c (grub2 2.12) so
mistakes are caught here instead of at first boot.

It checks:
  * top-level keys are in theme_set_string()'s allow-list, and their values
    are double quoted (read_property rejects anything else)
  * object types are in read_object()'s allow-list
  * every widget property is one that widget actually implements
  * left/top/width/height parse as a proportional spec, and every painted
    widget gets all four (a zero-sized widget paints nothing)
  * desktop-image and any `file =` exist next to theme.txt
  * every font = "..." has a usable .pf2 beside theme.txt

Usage: tools/check-grub-theme.py <theme-dir> [more-dirs...]
Exit 0 = clean, 1 = at least one error.
"""
import os
import re
import sys

# theme_set_string(), gfxmenu/theme_loader.c
VIEW_KEYS = {
    "title-font", "message-font", "terminal-font", "title-color",
    "message-color", "message-bg-color", "desktop-image",
    "desktop-image-scale-method", "desktop-image-h-align",
    "desktop-image-v-align", "desktop-color", "terminal-box",
    "terminal-border", "terminal-left", "terminal-top", "terminal-width",
    "terminal-height", "title-text",
}
# read_object(), gfxmenu/theme_loader.c
OBJECT_TYPES = {
    "label", "image", "vbox", "hbox", "canvas", "progress_bar",
    "circular_progress", "boot_menu",
}
PAINTED = ("label", "boot_menu", "progress_bar", "circular_progress", "image")

LABEL_KEYS = {"text", "font", "color", "align", "visible", "id"}
PROGRESS_BAR_KEYS = {
    "text", "font", "text_color", "border_color", "bg_color", "fg_color",
    "bar_style", "highlight_style", "highlight_overlay", "id",
}
LIST_KEYS = {
    "item_font", "selected_item_font", "item_color", "selected_item_color",
    "icon_width", "icon_height", "item_height", "item_padding",
    "item_icon_space", "item_spacing", "visible", "menu_pixmap_style",
    "item_pixmap_style", "selected_item_pixmap_style", "scrollbar_frame",
    "scrollbar_thumb", "scrollbar_thumb_overlay", "scrollbar_width",
    "scrollbar_slice", "scrollbar_left_pad", "scrollbar_right_pad",
    "scrollbar_top_pad", "scrollbar_bottom_pad", "scrollbar", "id",
}
IMAGE_KEYS = {"file", "id"}
WIDGET_KEYS = {
    "label": LABEL_KEYS,
    "progress_bar": PROGRESS_BAR_KEYS,
    "circular_progress": PROGRESS_BAR_KEYS,
    "boot_menu": LIST_KEYS,
    "image": IMAGE_KEYS,
    "vbox": set(),
    "hbox": set(),
    "canvas": set(),
}
GEOMETRY = ("left", "top", "width", "height")
# parse_proportional_spec(): a SUM of [+-]N[%] terms, e.g. "100%-58"
SPEC_RE = re.compile(r"^(?:[+-]?\d+%?)+$")
FONT_FAMILY_WORDS = re.compile(r"[^a-z0-9]+")


def tokenize(text):
    """Yield (kind, payload, line). kind in {comment, ident, str, op}."""
    i, line = 0, 1
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            i, line = i + 1, line + 1
            continue
        if c in " \t\r\f":
            i += 1
            continue
        if c == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == '"':
            start = line
            i += 1
            buf = []
            while i < n and text[i] != '"':
                if text[i] == "\n":
                    line += 1
                buf.append(text[i])
                i += 1
            i += 1
            yield ("str", "".join(buf), start)
            continue
        if c in "{}:=+":
            yield ("op", c, line)
            i += 1
            continue
        j = i
        while j < n and (text[j].isalnum() or text[j] in "_-%."):
            j += 1
        if j == i:
            i += 1
            continue
        yield ("ident", text[i:j], line)
        i = j


class Parser:
    def __init__(self, text, errors):
        self.toks = list(tokenize(text))
        self.pos = 0
        self.errors = errors

    def peek(self):
        return self.toks[self.pos] if self.pos < len(self.toks) else None

    def take(self):
        t = self.peek()
        if t is not None:
            self.pos += 1
        return t

    def err(self, line, msg):
        self.errors.append(f"line {line}: {msg}")

    # --- expressions (widget context; quoting optional) --------------------
    def expr(self):
        t = self.peek()
        if t is None:
            self.err(0, "unexpected end of file (value expected)")
            return None
        if t[0] == "str":
            self.pos += 1
            return t[1], True
        if t[0] == "ident":
            self.pos += 1
            return t[1], False
        if t[0] == "op" and t[1] == "(":
            self.pos += 1
            buf = ["("]
            while True:
                x = self.take()
                if x is None:
                    self.err(t[2], "unterminated '(' value")
                    break
                buf.append(x[1])
                if x[0] == "op" and x[1] == ")":
                    break
            return "".join(buf), True
        self.err(t[2], f"expected a value, got {t[1]!r}")
        self.pos += 1
        return None, False

    def parse(self, themedir):
        while self.peek() is not None:
            t = self.peek()
            if t[0] == "op" and t[1] == "+":
                self.take()
                self.obj(themedir)
            else:
                self.prop(themedir, None)

    def prop(self, themedir, wtype):
        t = self.take()
        if t is None or t[0] != "ident":
            self.err(t[2] if t else 0, "expected a property name")
            return None
        name, line = t[1], t[2]
        sep = self.take()
        if wtype is None:
            if sep is None or sep[0] != "op" or sep[1] != ":":
                self.err(line, f"expected ':' after top-level property {name!r}")
                return None
            nt = self.peek()
            if nt is None or nt[0] != "str":
                if nt:
                    self.err(line, f"{name}: value {nt[1]!r} is not quoted — "
                                   "read_property() rejects this and aborts the theme")
                else:
                    self.err(line, f"{name}: missing quoted value")
                self.pos += 1
                return None
            self.take()
            value = nt[1]
            quoted = True
        else:
            if sep is None or sep[0] != "op" or sep[1] != "=":
                self.err(line, f"expected '=' after {name!r}")
                return None
            value, quoted = self.expr()
            if value is None:
                return None
        self.check(themedir, wtype, name, value, line, quoted)
        return name
        self.check(themedir, wtype, name, value, line, quoted)

    def check(self, themedir, wtype, name, value, line, _quoted):
        if wtype is None:
            if name not in VIEW_KEYS:
                self.err(line, f"unknown top-level property {name!r} "
                               "(GRUB aborts the whole theme on this)")
                return
            if name in GEOMETRY or name in ("terminal-left", "terminal-top",
                                             "terminal-width", "terminal-height"):
                self.geometry(name, value, line)
            if name == "terminal-border":
                if not value.isdigit():
                    self.err(line, f"terminal-border {value!r} is not an integer")
            if name == "desktop-image":
                if not os.path.exists(os.path.join(themedir, value)):
                    self.err(line, f"desktop-image {value!r} is not in the theme dir")
            if name == "desktop-image-scale-method" and value not in (
                    "stretch", "crop", "padding", "fitwidth", "fitheight"):
                self.err(line, f"unsupported desktop-image-scale-method {value!r}")
            if name == "desktop-image-h-align" and value not in ("left", "center", "right"):
                self.err(line, f"unsupported desktop-image-h-align {value!r}")
            if name == "desktop-image-v-align" and value not in ("top", "center", "bottom"):
                self.err(line, f"unsupported desktop-image-v-align {value!r}")
            if name in ("title-font", "terminal-font", "message-font"):
                self.font(themedir, value, line)
            return

        if name in GEOMETRY:
            self.geometry(name, value, line)
            return
        known = WIDGET_KEYS.get(wtype, set()) | set(GEOMETRY) | {"theme_dir", "theme_path"}
        if name not in known:
            self.err(line, f"property {name!r} is not implemented by '+ {wtype}' "
                           "(GRUB ignores it)")
        if name == "font":
            self.font(themedir, value, line)
        if name == "file" and not os.path.exists(os.path.join(themedir, value)):
            self.err(line, f"file {value!r} is not in the theme dir")
        if name == "visible" and value not in ("true", "false"):
            self.err(line, f"visible {value!r} must be true/false")

    def font(self, themedir, spec, line):
        parts = spec.split()
        if len(parts) < 3 or not parts[-1].isdigit():
            return  # not a "family style size" spec; GRUB falls back, never fatal
        size = parts[-1]
        words = [w for w in FONT_FAMILY_WORDS.split(" ".join(parts[:-2]).lower()) if w]
        for f in sorted(os.listdir(themedir)):
            if not f.endswith(".pf2"):
                continue
            norm = FONT_FAMILY_WORDS.sub("", f.lower()[:-4])
            if size in norm and all(w in norm for w in words):
                return
        self.errors.append(
            f"line {line}: font {spec!r} has no matching .pf2 next to theme.txt "
            "— GRUB silently falls back to Unifont")

    def geometry(self, name, value, line):
        if not SPEC_RE.match(value):
            if "." in value:
                self.err(line, f"{name} {value!r} uses a decimal: "
                               "parse_proportional_spec() spins forever on '.', "
                               "which HANGS the boot menu")
            else:
                self.err(line, f"{name} {value!r} is not a proportional spec")

    def obj(self, themedir):
        t = self.take()
        if t is None or t[0] != "ident":
            self.err(t[2] if t else 0, "expected an object type after '+'")
            return
        wtype, line = t[1], t[2]
        if wtype not in OBJECT_TYPES:
            self.err(line, f"unknown object type '+ {wtype}' "
                           "(GRUB aborts the whole theme on this)")
            return
        brace = self.take()
        if brace is None or brace[0] != "op" or brace[1] != "{":
            self.err(line, f"expected '{{' after '+ {wtype}'")
            return
        seen = set()
        while True:
            t = self.peek()
            if t is None:
                self.err(line, f"unterminated '+ {wtype} {{' block")
                return
            if t[0] == "op" and t[1] == "}":
                self.take()
                break
            if t[0] == "op" and t[1] == "+":
                self.take()
                self.obj(themedir)
                continue
            before = self.pos
            name = self.prop(themedir, wtype)
            if self.pos == before:
                self.pos += 1
            if self.pos >= len(self.toks):
                return
            if name:
                seen.add(name)
        if wtype in PAINTED:
            missing = [g for g in GEOMETRY if g not in seen]
            if missing:
                self.err(line, f"+ {wtype} has no {'/'.join(missing)}: "
                               "a zero-sized widget paints nothing")


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    rc = 0
    for d in argv[1:]:
        theme = os.path.join(d, "theme.txt")
        if not os.path.exists(theme):
            print(f"FAIL {d}: no theme.txt")
            rc = 1
            continue
        with open(theme, encoding="utf-8") as fh:
            text = fh.read()
        errors = []
        Parser(text, errors).parse(d)
        if errors:
            rc = 1
            print(f"FAIL {theme}")
            for e in errors:
                print(f"  {e}")
        else:
            files = os.listdir(d)
            total = sum(os.path.getsize(os.path.join(d, f)) for f in files)
            print(f"OK   {theme}  ({sum(1 for f in files if f.endswith('.pf2'))} pf2, {total} B)")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
