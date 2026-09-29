# Installing windOS Zen

You need: a 64-bit PC, a 4 GB+ USB stick, and the windOS Zen ISO from the
Releases page. **Back up anything important first** — partitioning can erase
disks.

## 1. Put the ISO on a USB stick

### Option A — Ventoy (easiest, recommended)

Install [Ventoy](https://www.ventoy.net/) on the stick once, then just copy
the `windos-zen-*.iso` file onto it. You can keep several ISOs side by side.

### Option B — dd (overwrites the whole stick)

On Linux, find your stick's device name (`lsblk` — usually something like
`/dev/sdb`, **not** a partition like `/dev/sdb1`), unmount it, then:

```sh
sudo dd if=windos-zen-1.0-trixie-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with your stick. Triple-check the letter — `dd` to the
wrong device erases the wrong disk. On Windows, use Rufus or balenaEtcher
in DD/image mode instead.

The ISO is a hybrid image and boots on both **BIOS (Legacy)** and
**UEFI** machines. If one mode fails, try the other in your firmware
settings. **Secure Boot must be off** (or enroll your own keys) — windOS
Boot is not signed with Microsoft keys.

## 2. Boot the stick

Plug it in, power on, and open your PC's one-time boot menu (often F12, F8,
Esc, or F9 — check your motherboard splash screen). Pick the USB stick.
You will land in the [live GNOME session](live-session.md). Nothing has
been installed yet — have a look around first.

## 3. The installer walkthrough

Double-click **Install windOS Zen** on the desktop. The installer
(Calamares) walks you through these pages:

1. **Welcome** — pick your language.
2. **Location** — your timezone (click the map).
3. **Keyboard** — layout and variant; test in the text box.
4. **Partitions** — erase-the-disk (simplest) or manual partitioning for
   advanced users. Confirm the target disk carefully.
5. **Users** — your name, username, computer name, and password. Reuse the
   same password for the administrator account unless you know why you'd
   separate them.
6. **Desktop Edition** — the fun part. Pick one of six:

   | Edition | What it is | Idle RAM |
   |---|---|---|
   | **GNOME (Modern, Default)** | Glassmorphic GNOME Shell with Dash to Dock, blur, app indicators | ~900 MB |
   | **KDE Plasma (Sleek)** | Plasma desktop, dark theme, telemetry/sync masked | ~600 MB |
   | **XFCE4 (Modernized Light)** | XFCE with dark theme, whisker menu — the sane middle | ~350 MB |
   | **LXQt (Potato-Class Qt)** | Pure Qt, Openbox window manager, no compositor | ~220 MB |
   | **Fluxbox (Ultra-Light)** | Minimal window manager with conky HUD, already on the live medium | <200 MB |
   | **Tiling / Minimalist** | Openbox, i3-wm, and Sway with starter dotfiles — keyboard-driven | minimal |

7. **Extra software (netinstall groups)** — optional bundles installable on
   top of any edition: Tiling/Minimalist extras (Openbox, i3-wm, Sway,
   labwc), Gaming helpers (Steam installer, Lutris, GameMode, MangoHud),
   Flatpak & Distrobox tools, and a Legacy rescue kit (memtest86+,
   smartmontools, testdisk, ddrescue). Tick what you want, or nothing.
8. **Summary** — review everything. This is the last chance to go back.
   Once you click Install, the disk gets written.

### Rescue-size choice

During install you can set `$WINDOS_RESCUE_SIZE` — how much space is
reserved for the **windOS Boot rescue system** (the recovery desktop
described in [windOS Boot](windos-boot.md)). The default is fine for most
people; raise it if you want a roomier rescue environment with extra tools,
lower it on tiny disks. If you skip it, a sensible default is used.

## 4. First boot

When the installer finishes, remove the USB stick and reboot. On UEFI you
will see a new **windOS Boot** entry first in the boot order (your old
entries are kept as fallback). Pick your system, log in with the user you
created, and continue with [After Installing](post-install.md).
