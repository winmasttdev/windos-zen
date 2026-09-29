# windOS Zen — Lighter Than Air

windOS Zen is a super-easy, ultra-lightweight Linux distribution based on
**Debian 13 "Trixie"**. It boots into a live **GNOME** desktop that idles
under **1.1 GB** of RAM, and its graphical installer lets you
**choose your desktop** — from a sub-200 MB Fluxbox up to full GNOME.

What makes it Zen:

- **Debian 13 inside.** Stable Trixie base, `apt` updates, huge package
  archive. Nothing exotic to learn.
- **Choose-your-desktop installer.** Six editions in one ISO, picked during
  install — no re-downloading.
- **windOS Boot.** A tiny boot menu (MiniBoot port) with one-key rescue:
  a full rescue desktop, kexec fast-boot into your system, and entries for
  your other installed systems.

## Download

Grab the latest ISO from the **Releases page** of the
[windOS Zen repository](https://github.com/winmasttdev/windos-zen).
You need the 64-bit (`amd64`) ISO and a USB stick of 4 GB or more.

## Quickstart

1. **Flash it.** Use Ventoy (copy the ISO on) or `dd` it to the USB stick.
   See [Installing](install.md) for exact commands.
2. **Boot it.** Pick the USB stick from your PC's boot menu, try the live
   GNOME session — nothing is installed yet.
3. **Install it.** Double-click **Install windOS Zen**, answer a few simple
   questions, pick your desktop, reboot. Done.
