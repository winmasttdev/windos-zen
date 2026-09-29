# After Installing

First boot done? A few things worth knowing.

## Updates

windOS Zen is Debian, so updates are plain `apt`:

```sh
sudo apt update && sudo apt upgrade
```

Graphical update tools (like GNOME Software, if installed) work too.
Security updates for Trixie arrive through the normal Debian channels —
install them regularly.

## Already tuned

- **zram** is on out of the box: compressed swap in RAM, so low-memory
  machines stay responsive.
- **Drivers and firmware** are included (`non-free-firmware` is enabled),
  covering most Wi-Fi chips and GPUs. If something is still missing,
  `sudo apt install firmware-linux` plus your vendor's firmware package
  usually fixes it; check `dmesg | grep -i firmware` for clues.
- Early-boot OOM protection and desktop responsiveness tweaks are
  pre-configured — nothing to do.

## Flatpak and Distrobox

If you ticked the **Flatpak & Distrobox** group during install, you're
ready: install sandboxed apps with `flatpak`, and run other distros'
software with `distrobox`. If you skipped it:

```sh
sudo apt install flatpak distrobox podman
```

## GNOME extensions

The default GNOME edition ships Dash to Dock, Blur my Shell,
AppIndicator support, and User Themes with the windOS dark profile
pre-applied. Manage or remove them with **GNOME Tweaks** or the
**Extensions** app — disabling all extensions is also the fastest way to
check whether a desktop glitch is extension-caused.
