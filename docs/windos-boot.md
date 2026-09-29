# windOS Boot

windOS Boot is the small boot menu installed alongside your system (a port
of the [MiniBoot](https://github.com/winmastt/miniboot) bootloader). It
does **not** replace GRUB — it only *adds* a boot entry, first in the boot
order, with GRUB kept as fallback.

## Boot entries

- **Main system (kexec).** Boots straight into your installed windOS Zen
  with a fast `kexec` jump — no full reboot cycle. If several kernels are
  installed, you can pick which one.
- **Rescue desktop.** A minimal working desktop for when your main system
  won't boot (see below).
- **Other systems.** Automatically detected Linux installs on all your
  disks.
- **Custom entries.** Edit `entries.conf` on the EFI system partition
  (from any OS) to add your own entries — they are picked up automatically.
- **Firmware / Reboot / Poweroff.** One-key reboot into UEFI settings,
  plain reboot, and power off. Every failure drops you to a rescue shell
  instead of hanging.

## Rescue desktop basics

The rescue option boots a minimal desktop for repairs:

- **Login:** user `root`. The password is chosen at install time — change
  it anytime with `passwd`.
- **Boot the main system:** run `mainboot` — it kexec-boots your real
  install without a reboot cycle.
- **Repair the main install:** it is mounted at `/main` automatically
  (its EFI partition at `/main-esp`). Enter it with `chroot /main` and fix
  packages, configs, or passwords from inside.
- **Inspect failures:** `journalctl -b` for the boot log,
  `systemctl --failed` for broken services.
- **Network:** `nmcli device wifi list` or `nmtui` (NetworkManager runs).
- **SSH in:** the `sshd` service runs — `ssh root@<rescue-ip>`. Run
  `tailscale up` once for access outside your LAN.

## Kernel-pinning note

The rescue environment boots **its own kernel**, not your main system's.
A kernel only works with its matching modules, so the rescue kernel and
its module set are always deployed as a pair — after every kernel update
a hook rebuilds and redeploys them together. Never copy your main
system's kernel over the rescue one by hand, or hardware support (GPU,
Wi-Fi, filesystems) will silently stop loading.
