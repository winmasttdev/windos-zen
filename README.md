# windOS Zen

> **Lighter Than Air** — an ultra-lightweight Arch Linux distribution.

windOS Zen is a minimal, fast Arch Linux (built with `archiso`) featuring:

- A clean **Plymouth** boot splash (`windos-zen`)
- **XFCE** as the default desktop, tuned for speed and low footprint
- A **ZSH** shell with custom branding and a `sweet-tea` easter egg
- System optimizations: `zram-generator`, earlyoom, and tuned `sysctl`
- A graphical installer (Calamares, or the in-progress native Python installer)
- Branding that matches the project site: <https://windos.nn1kk00.ru/>

## Project layout

```
windos-zen/
  profiledef.sh            # archiso profile definition (label, bootmodes, compression)
  packages.x86_64         # packages baked into the live image
  pacman.conf             # bootstrap pacman config
  airootfs/               # overlay applied to the live root (configs, skel, scripts)
  syslinux/ grub/         # bootloader entries (archisolabel + serial console)
  scripts/
    build.sh              # ISO build wrapper
    build-calamares.sh   # builds Calamares from AUR and injects it as a local package
  windos-installer.py     # prototype native PySide6 installer
  ascii/ assets/          # branding art and artwork
```

## Building the ISO

Requires an Arch Linux host with `archiso`, `squashfs-tools`, `grub`, and `pacman`.

```sh
# Build the Calamares package (optional; uses AUR) and inject it
./scripts/build-calamares.sh

# Build the ISO (output goes to ./out or a path you pass)
sudo ./scripts/build.sh ./out
```

The resulting ISO is written to the output directory (e.g. `out/windos-zen-<date>-x86_64.iso`).
Set `WINDOS_WORK` to control archiso's temporary working directory.

## Testing in a VM

```sh
qemu-system-x86_64 -enable-kvm -m 2048 -cpu host \
  -cdrom out/windos-zen-*.iso \
  -drive file=test-disk.qcow2,format=qcow2,if=virtio \
  -boot d -vga virtio -display gtk
```

## Installer

The live image ships **Calamares** (configured under `airootfs/etc/calamares/`)
with a custom `windOS Zen` branding theme. A from-scratch native **Python + PySide6**
installer is prototyped in `windos-installer.py` (see `windos-installer/PROMPT.md`
for the full design brief handed to a code-generation model).

## License

GPL-3.0. See [LICENSE](LICENSE).
