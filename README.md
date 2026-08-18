<!-- Hero -->
<p align="center">
  <img src="airootfs/etc/calamares/branding/windos/logo.png" width="120" alt="windOS Zen logo"/>
</p>

<h1 align="center">windOS&nbsp;Zen</h1>

<p align="center">
  <b>Lighter Than Air</b> &mdash; an ultra-lightweight, beautiful Arch Linux distribution.
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/license-GPL--3.0-blue.svg"/>
  <img alt="Base" src="https://img.shields.io/badge/base-Arch%20Linux-blue?logo=archlinux"/>
  <img alt="Desktop" src="https://img.shields.io/badge/desktop-XFCE-lightgrey"/>
  <img alt="Shell" src="https://img.shields.io/badge/shell-ZSH-purple"/>
  <img alt="Installer" src="https://img.shields.io/badge/installer-Calamares%20%2F%20PySide6-orange"/>
  <img alt="Status" src="https://img.shields.io/badge/status-open--source-brightgreen"/>
</p>

<p align="center">
  <a href="https://github.com/winmasttdev/windos-zen">github.com/winmasttdev/windos-zen</a>
  &nbsp;•&nbsp;
  <a href="https://windos.nn1kk00.ru/">windos.nn1kk00.ru</a>
</p>

---

## ✨ What is windOS Zen?

> **windOS Zen** is a from-scratch **Arch Linux** derivative built with
> [`archiso`](https://wiki.archlinux.org/title/Archiso). It boots to a tuned
> **XFCE** desktop, ships a custom **Plymouth** splash, a **ZSH** shell with
> hand-made branding, and a graphical installer. The whole thing is engineered
> to feel *calm, fast, and light* &mdash; hence **"Lighter Than Air."**

This repository contains **everything** that was built, fixed, and debugged to
get a working, installable, good-looking distro &mdash; documented below so
anyone can rebuild or extend it.

---

## 🧭 Table of Contents

- [Features](#-features)
- [The Build, End-to-End](#-the-build-end-to-end)
  - [1. Profile & squashfs](#1-profile--squashfs)
  - [2. Boot & initramfs](#2-boot--initramfs)
  - [3. Live environment (customize_airootfs.sh)](#3-live-environment)
  - [4. Desktop: XFCE](#4-desktop-xfce)
  - [5. Shell & branding](#5-shell--branding)
  - [6. Optimizations](#6-optimizations)
  - [7. Installer &mdash; Calamares](#7-installer--calamares)
  - [8. Native PySide6 installer (prototype)](#8-native-pyside6-installer-prototype)
- [Project Structure](#-project-structure)
- [Building the ISO](#-building-the-iso)
- [Testing in a VM](#-testing-in-a-vm)
- [Customizing](#-customizing)
- [License](#-license)

---

## 🚀 Features

| Area | What you get |
|------|--------------|
| **Base** | Pure Arch Linux, rolling, `archiso`-built |
| **Boot splash** | Custom **Plymouth** theme `windos-zen` |
| **Desktop** | **XFCE** (lightweight, snappy), with `network-manager-applet` + pulseaudio plugin |
| **Shell** | **ZSH** with custom prompt, ASCII art, `windfetch`, and a `sweet-tea` easter egg |
| **Installer** | **Calamares** with a bespoke *windOS Zen* branding theme (or a from-scratch PySide6 installer) |
| **Performance** | `zram-generator`, `earlyoom`, tuned `sysctl`, `mkinitcpio -P` rebuild |
| **Audio** | **PipeWire** enabled globally for the live user |
| **Branding** | Matches the official site [windos.nn1kk00.ru](https://windos.nn1kk00.ru/) |

---

## 🛠 The Build, End-to-End

This section documents **every part of the work**, including the bugs that were
hit and the exact fixes applied.

### 1. Profile & squashfs

`profiledef.sh` defines the image. Key settings:

- **Bootmodes:** `('bios.syslinux' 'uefi.grub')` &mdash; works on both legacy and UEFI.
- **Volume label:** `WINDOS_ZEN`.
- **Squashfs compression:** mksquashfs **4.7.5** rejects the old `--zstd-level`
  flag, so it was fixed to:

  ```sh
  airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')
  ```

`packages.x86_64` is a plain list (**no inline comments** &mdash; `archiso`'s
`mapfile` keeps trailing whitespace, which broke targets). Notable packages:

- `mkinitcpio-archiso` &mdash; **critical**: it provides the `archiso` initcpio
  *hook* (the mount handler). Without it the live boot fails with
  *"failed to mount ''"* and drops to an emergency shell.
- `xfce4 xfce4-goodies network-manager-applet xfce4-pulseaudio-plugin` &mdash;
  the XFCE base (replaced Fluxbox, which the user found unstable).
- Calamares runtime dependencies + the prebuilt Calamares package.

### 2. Boot & initramfs

- `airootfs/etc/mkinitcpio.conf` **HOOKS** were corrected: the non-existent
  `archiso_kms` install script was replaced with the real `kms` hook.
- **Boot entries** (both `syslinux/archiso_sys-linux.cfg` and `grub/grub.cfg`)
  carry the kernel parameters needed for a correct live boot:

  ```text
  archisolabel=WINDOS_ZEN console=ttyS0,115200
  ```

  `archisolabel=` tells the `archiso` hook where the live medium is; without it
  the initramfs can't find the squashfs.

- `pacman.conf` (bootstrap) uses `SigLevel = Never` with embedded mirrors so
  the `pacstrap` works inside the build chroot.

### 3. Live environment

All live customization lives in `airootfs/root/customize_airootfs.sh`, run by
`mkarchiso` inside the chroot. Fixes applied here:

- **PipeWire:** enabled with
  `systemctl --global enable pipewire.service pipewire-pulse.service`
  (had been breaking `set -e`).
- **Initramfs rebuild:** `mkinitcpio -P` runs *after* all packages are present.
- **Calamares injection:** installed via a **temporary** `pacman.conf`
  (`SigLevel=Never`, no `CheckSpace`) because pacman's space check fails inside
  the arch-chroot.
- **Machine-ID:** a real `machine-id` is written and
  `systemd-firstboot.service` is masked, so the live boot **does not** stop to
  ask for timezone/root password interactively.
- **Pacman keyring:** initialized with `pacman-key --init && pacman-key
  --populate archlinux` so Calamares' `netinstall` can verify signatures.
- **Autologin group:** `groupadd -r autologin` is created (it does **not**
  exist by default) and `liveuser` is added to it; otherwise LightDM's autologin
  PAM check *"user ingroup autologin not met"* fails and drops to a login
  greeter.
- **Graphical target:** explicit symlinks wire
  `display-manager.target.wants/lightdm.service` and
  `default.target → graphical.target`.
- **Serial console:** `serial-getty@ttyS0` is enabled so the boot log streams
  to the serial line for debugging.

### 4. Desktop: XFCE

- Switched from **Fluxbox** to **XFCE** per user preference ("fluxbox shits
  itself").
- `lightdm.conf.d/autologin.conf` sets `user-session=xfce` /
  `autologin-session=xfce`.
- Wallpaper is set via
  `airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml`
  pointing at `windos-light.png`.
- Fluxbox skel directory removed.

### 5. Shell & branding

- Default shell is **ZSH** (`chsh -s /bin/zsh` for root and liveuser).
- Custom `.zshrc` with prompt, ASCII banner, and the `sweet-tea` alias.
- **`sweet-tea` easter egg:** `airootfs/usr/local/bin/sweet-tea` + the alias
  `tea='sweet-tea'` in `.zshrc`.
- `windfetch` and a custom `windos-post-install.sh` (run by
  `windos-firstboot.service` on the installed system).

### 6. Optimizations

- `zram-generator` config for compressed swap-in-RAM.
- `earlyoom` to keep the system responsive under memory pressure.
- Tuned `sysctl` defaults for desktop responsiveness.

### 7. Installer — Calamares

Calamares is configured under `airootfs/etc/calamares/`. Several real bugs were
found and fixed during testing:

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| *"failed to start: no sequence set"* | `settings.conf` used a **flat** module list instead of `show:`/`exec:` action blocks | Rewrote `sequence:` with proper `show`/`exec` structure |
| *"Key not found: slideshow"* | `branding.desc` was **missing the mandatory `slideshow` key** | Added `slideshow: "slideshow.qml"` + a minimal QML slideshow; set `showSlideshow: false` in `welcome.conf` |
| Netinstall signature errors | Live **pacman keyring not initialized** (disabled by the fixed machine-id) | `pacman-key --init && --populate archlinux` in `customize_airootfs.sh` |
| Welcome blocked on internet | `welcome.conf` required `internet` | Requirement relaxed to `storage` only |
| Autologin greeter instead of desktop | `liveuser` not in `autologin` group | `groupadd -r autologin` + add user to it |

**Branding / theme** (`branding/windos/`):

- `branding.desc` — product name, sidebar logo/text, `slideshow`, and
  `stylesheet: "calamares.qss"`.
- `calamares.qss` — a custom **dark indigo "zen"** Qt stylesheet (deep navy
  `#0b0f1a`, indigo accent `#5b6bff`, gradient sidebar, soft rounded cards),
  matched to the [windos.nn1kk00.ru](https://windos.nn1kk00.ru/) identity.
- `logo.png` (512×512) and `slideshow.qml`.

<details>
<summary><b>📋 Calamares module sequence</b></summary>

```yaml
sequence:
    - show:    [ welcome ]
    - show:    [ locale ]
    - show:    [ keyboard ]
    - exec:    [ partition, users, netinstall, bootloader, shellprocess ]
    - show:    [ finished ]
```

Module configs: `welcome`, `locale`, `keyboard`, `partition`, `users`,
`netinstall` (+ `netinstall.yaml`), `bootloader`, `shellprocess`, `finished`,
`unpackfs`, `displaymanager`, `services`.
</details>

### 8. Native PySide6 installer (prototype)

A from-scratch **native** installer was prototyped in `windos-installer.py`
(Python + **PySide6**) as an alternative to Calamares &mdash; fast, no browser,
no lag.

- Wizard pages: **Welcome → Disk → User → Summary → Progress → Finish**.
- Backend drives the same real tools ( `parted`, `unsquashfs`, `genfstab`,
  `arch-chroot`, `grub-install`, `mkinitcpio`).
- **Dry-run mode** (default on) only *prints* the commands it would run &mdash;
  safe to open on a real machine for preview.
- Work runs in a `QThread` so the UI never freezes.

The full design brief handed to a code-generation model lives at
[`windos-installer/PROMPT.md`](windos-installer/PROMPT.md), and was written
against the verified host environment (Arch x86_64, Python 3.14, PySide6 6.11,
UEFI).

---

## 📂 Project Structure

```text
windos-zen/
├── profiledef.sh                 # archiso profile: label, bootmodes, squashfs
├── packages.x86_64               # packages baked into the live image
├── pacman.conf                   # bootstrap pacman config
├── build.sh / scripts/           # ISO build + Calamares AUR builder
├── syslinux/  grub/              # bootloader entries (archisolabel + serial)
├── airootfs/                     # overlay applied to the live root
│   ├── etc/
│   │   ├── calamares/            # installer config + windOS Zen branding
│   │   ├── lightdm/              # autologin config
│   │   ├── plymouth/             # boot splash theme
│   │   ├── skel/                 # user dotfiles (zsh, xfce, picom…)
│   │   └── mkinitcpio.conf
│   ├── root/
│   │   ├── customize_airootfs.sh # all live customization
│   │   └── calamares-*.pkg.tar.zst  # injected Calamares (gitignored)
│   └── usr/local/bin/            # sweet-tea, windfetch, windos-post-install.sh
├── ascii/  assets/               # branding art / artwork
├── windos-installer.py           # prototype native PySide6 installer
├── windos-installer/
│   └── PROMPT.md                 # design brief for the installer
├── README.md  LICENSE  .gitignore
```

---

## 🏗 Building the ISO

Requires an **Arch Linux** host with `archiso`, `squashfs-tools`, `grub`, and
`pacman`.

```sh
# 1. (optional) build the Calamares package from AUR and inject it
./scripts/build-calamares.sh

# 2. build the ISO
sudo ./scripts/build.sh ./out
```

- Output: `out/windos-zen-<date>-x86_64.iso`
- `WINDOS_WORK` controls archiso's temporary working directory.
- The Calamares `.pkg.tar.zst` is **gitignored** (regenerable via the script).

---

## 🧪 Testing in a VM

```sh
qemu-img create -f qcow2 test-disk.qcow2 20G
qemu-system-x86_64 -enable-kvm -m 2048 -cpu host \
  -cdrom out/windos-zen-*.iso \
  -drive file=test-disk.qcow2,format=qcow2,if=virtio \
  -boot d -vga virtio -display gtk
```

Add `-serial telnet:localhost:4321,server,nowait` and log in as `root`/`root`
(or `liveuser`/`liveuser`) on the serial console for debugging.

---

## 🎨 Customizing

- **Theme:** edit `airootfs/etc/calamares/branding/windos/calamares.qss`.
- **Boot splash:** `airootfs/etc/plymouth/themes/windos-zen/`.
- **Packages:** `packages.x86_64`.
- **Live behavior:** `airootfs/root/customize_airootfs.sh`.
- **Wallpaper / skel:** `airootfs/etc/skel/`.
- **Installer flow:** `airootfs/etc/calamares/settings.conf` + module configs.

---

## 📜 License

**GPL-3.0**. See [LICENSE](LICENSE).

<p align="center">
  <sub>windOS Zen &mdash; Lighter Than Air ☁️⚡</sub>
</p>
