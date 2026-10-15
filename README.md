<p align="center">
  <b>windOS Zen — Lighter Than Air</b><br>
  <sub>Debian 13 "Trixie" &middot; live-build &middot; GNOME live session &middot; Calamares 6-edition installer &middot; Liquorix kernel</sub>
</p>

---

## What is windOS Zen?

A beginner-friendly Debian-based distribution built with Debian's
[`live-build`](https://salsa.debian.org/live-team/live-build). One `amd64`
hybrid ISO boots on **BIOS and UEFI** and lands you in a **GNOME live
session**. A graphical **Calamares installer** ships on the same ISO and lets
you pick one of **six desktop editions** during install — no second download,
no re-flashing.

It targets old hardware: a 1–4 GB box with a Celeron or a 2009 laptop, which
is the whole reason for zram, a curated locale set, masked daemons and a
`MODULES=dep`-shaped boot.

**Docs:** [`docs/`](docs/README.md) — start there, or jump to
[Installing](docs/install.md).
**Web:** [`site/`](site/index.html) — the marketing/gallery site.
**Measurements and the optimization plan:** [`OPTIMIZE.md`](OPTIMIZE.md).

## What is in the image

| | |
|---|---|
| Base | Debian 13 "Trixie" (`live-build` config version `20250505+deb13u1`) |
| Architecture | `amd64` only |
| Image type | `iso-hybrid` — `syslinux` on BIOS, `grub-efi` on UEFI, `memtest86+` entry |
| Live session | GNOME Shell 48 under `gdm3` with autologin, windOS dconf profile (Arc-Dark, cyan accent) plus dash-to-dock, blur-my-shell and appindicator extensions |
| Installer | Calamares 3.3.14 — pick GNOME / Fluxbox / XFCE / KDE Plasma / LXQt / Tiling, then optional netinstall groups |
| Kernel | **Liquorix** (Zen-tuned), `7.2.10-2-liquorix-amd64` in the current build, wired via `config/archives/liquorix.*` + `config/package-lists/05-kernel-liquorix.list.chroot` |
| Memory | zram swap on every boot (zstd, `min(50 % RAM, 2 GiB)`, priority 100), `earlyoom`, a tuned `sysctl.d` profile |
| Boot | **Verbose on purpose — no Plymouth.** No `quiet`, no `splash`; the initramfs prints a windOS handoff banner before PID 1 |
| Compression | squashfs `xz` with the `x86` BCJ pre-filter |
| Rescue | windOS Boot — a MiniBoot port with one-key rescue, kexec fast-boot and entries for other installed systems ([`modules/07-miniboot/`](modules/07-miniboot/DEBIAN-PORT.md)) |

### Deliberate omissions

Plymouth is not in the package lists at all — it is a plain removal, not a
mask. The theme sources stay in [`modules/02-plymouth/`](modules/02-plymouth/)
and the SVG masters in `assets/brand/plymouth-*.svg`, so re-enabling the
splash is a documented three-step change (see the comment block at the top of
[`config/package-lists/00-minimal.list.chroot`](live-build/config/package-lists/00-minimal.list.chroot)).
Watch out for `desktop-base`, which *Recommends* `plymouth-label`; live-build
installs with `Install-Recommends=false`, and that edge has to stay cut.

## Repo layout

```
windos-zen/
├── live-build/            the actual build tree — this is what `lb build` reads
│   ├── auto/config        one-shot `lb config noauto ...` invocation
│   ├── build-iso.sh       render assets -> stage -> lb clean -> lb config -> lb build
│   ├── config/
│   │   ├── archives/      third-party apt suites (Liquorix) + chroot apt.conf.d
│   │   ├── binary         ISO / bootloader / checksum options
│   │   ├── bootstrap      suite, mirrors, archive areas
│   │   ├── chroot         squashfs + kernel flavour options
│   │   ├── common         live-build version, image name, apt behaviour
│   │   ├── hooks/         live/ (ours) and normal/ (upstream symlinks)
│   │   ├── includes.binary/       isolinux splash
│   │   ├── includes.chroot/       everything overlaid into the image root
│   │   └── package-lists/         numbered .list.chroot sets
│   └── *.iso, chroot/,    build output — git-ignored, never committed
│       cache/, binary/
├── modules/               the numbered build modules (see below)
├── assets/
│   ├── brand/             editable masters: SVG, TTF fonts, patches
│   ├── generated/         rendered PNG/ICO output of tools/gen-assets.sh
│   └── shots-self/        screenshots taken from the live ISO in QEMU
├── tools/                 gen-assets.sh, logo-ascii.py, check-grub-theme.py
├── site/                  static site + gallery + vertical short
├── docs/                  user documentation
└── OPTIMIZE.md            measured baseline + the optimization plan
```

### Module map

`modules/NN-name/` is where a feature is *authored*;
`live-build/config/` is where it is *staged* into the image. Both copies are
tracked, and the module copy is the one to edit.

| Module | Path | What it does |
|---|---|---|
| 1 | `live-build/build-iso.sh`, `live-build/auto/config` | Renders brand assets, stages them, runs `lb config` + `lb build` with `MKSQUASHFS_OPTIONS="-comp xz -Xbcj x86"` |
| 2 | `modules/02-plymouth/` | Plymouth theme sources — **not staged**, kept for a future opt-in re-enable |
| 3 | `modules/03-fluxbox/` | Fluxbox edition: style, picom, conky HUD, nitrogen wallpaper, `.xsession`; its `skel/` is copied into `includes.chroot/etc/skel` |
| 4 | `modules/04-calamares/` | The installer: branding, the `packagechooser@de` edition picker, `netinstall-windos`, and `windos-de-setup.sh` — the dispatcher that runs **inside the installed target** and installs the chosen edition from `packages-<id>.list` |
| 5 | `modules/05-gnome/` | GNOME dconf profile plus the `install-<id>-edition.sh` scripts and package lists for the GNOME / XFCE / KDE / LXQt / Tiling editions |
| 6 | `modules/06-tuning/` | zram setup script + unit, and the `sysctl.d` profile |
| 7 | `modules/07-miniboot/` | windOS Boot: the MiniBoot port, its initramfs hook and the `zz-miniboot` chainloader. See [`DEBIAN-PORT.md`](modules/07-miniboot/DEBIAN-PORT.md) |
| 8 | `modules/08-grub-theme/` | gfxmenu theme for the **installed** system's boot menu: `theme.txt`, backdrop, and the Plus Jakarta Sans PF2 fonts GRUB can actually draw with |

Module 4's per-module config files are not optional. Calamares upstream
schemas are `additionalProperties: false` and several of these modules index
their keys with no fallback, so a missing file is a `KeyError` or an aborted
install step rather than a default. `bootloader.conf` + `grubcfg.conf` +
their two entries in `settings.conf` are what restore a working
`grub-install` on the installed disk, and `08-bootloader.list.chroot` is what
puts `grub-install` and the GRUB platform payloads into the target rootfs in
the first place — `unpackfs` copies the squashfs verbatim, so anything masked
out of the live image has to be explicitly re-enabled on the target
(`services-systemd.conf` does that for the masked units).

## Building the ISO

Run [`live-build/build-iso.sh`](live-build/build-iso.sh) on a Debian 13 builder
or inside a `debian:trixie` container. It renders the brand bitmaps with
`tools/gen-assets.sh` (needs `librsvg2-bin`), copies the Fluxbox skeleton into
the chroot overlay, exports `MKSQUASHFS_OPTIONS` and then runs `lb clean`,
`lb config` and `lb build`.

```bash
# host dependencies
apt install live-build debootstrap squashfs-tools xorriso \
            librsvg2-bin dosfstools mtools grub-efi-amd64-bin

cd live-build
./build-iso.sh
```

Or drive it by hand:

```bash
cd live-build
sh auto/config     # writes config/
lb build
```

The result is `live-build/windos-zen-1.0-trixie-amd64.hybrid.iso` plus a
`sha256` checksum. Build output — the ISO, `chroot/`, `cache/`, `binary/`,
`.build/` and the logs — is git-ignored and must stay local.

If you touch the GRUB theme, validate it before you ship it. GRUB ships no
theme linter and one bad line makes gfxmenu abandon the *entire* theme, so the
installed system silently falls back to a bare Debian menu:

```bash
tools/check-grub-theme.py modules/08-grub-theme/usr/share/grub/themes/windos-zen
```

## Measured performance

Numbers below are measurements, not targets. Re-measure before quoting them.

**Current build** — `windos-zen-1.0-trixie-amd64.hybrid.iso`, built
2026-10-13, 2,590,310,400 bytes (~2.5 GB), squashfs 2,244,456,448 bytes
(xz, 128 KiB blocks), 1687 packages. Settled idle in a 2 GB QEMU VM on
2026-10-14: **184 processes, 1058 MB RAM used.**

[`OPTIMIZE.md`](OPTIMIZE.md) holds the full baseline table and the ranked
action list. Its measurement pass (2026-10-12) was taken on the *earlier*
build, which still shipped Plymouth and two duplicate kernel payloads — so its
51.18 s to `graphical.target`, 1072 MB idle and 1918 MiB ISO figures describe
that image, not this one. Its structural findings (initramfs firmware bulk,
the duplicate `vmlinuz`/`initrd`, the `plymouth-quit-wait` stall) are what the
work since has been aimed at.

The tree is currently *ahead* of the last successful build. After 2026-10-13
13:00 the source gained the bootloader fix (`bootloader.conf`, `grubcfg.conf`,
`08-bootloader.list.chroot`), the Plymouth removal, the GRUB theme, the
curated locale set, the `rofi`/`conky-std` drop and the `-Xbcj x86`
squashfs flag. None of that is in the Oct 13 ISO; expect the next build to
differ.

## License

**GPL-3.0**. See [LICENSE](LICENSE).