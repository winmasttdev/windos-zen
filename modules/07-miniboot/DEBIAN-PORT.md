# MiniBoot → Debian 13 (Trixie) port plan — windOS Zen Module 7

Upstream: `winmasttdev/miniboot` (Arch-only). Target: Debian 13 Trixie,
`linux-image-amd64` 6.12, initramfs-tools 0.148, busybox 1:1.37.0, kexec-tools.
Verified in a `debian:trixie` container (kernel `6.12.107+deb13-amd64`) unless
marked otherwise. Prototype: `debian/` next to this file.

Design decision: **no mkinitcpio/dracut, no foreign packaging.** A dedicated
initramfs-tools confdir (`/etc/miniboot/initramfs-tools`) + one hook reproduces
the mkinitcpio preset 1:1, and `rdinit=` keeps working unchanged (it is a
*kernel* parameter — the kernel execs our script instead of `/init`, so the
initramfs-tools `/init` inside the image is dead weight, never executed).
Upstream `miniswitch.sh` / `detect-root.sh` run **verbatim**; only
`windos-preinit.sh` (ours, not upstream) needs a Debian branch (modprobe).

## 1. File-by-file mapping (Arch → Debian)

| Upstream (Arch) | Debian port | Notes |
|---|---|---|
| `hooks/miniswitch`, `hooks/miniboot` (`/usr/lib/initcpio/install/`, `build()` with `add_file`/`add_binary`) | `debian/hooks/miniboot` → `/etc/miniboot/initramfs-tools/hooks/miniboot` | Sources `hook-functions`; `copy_exec kexec`, `copy_file` the 3 scripts, bakes site defaults via `sed`. Runs **only** for MiniBoot builds (separate confdir), so stock initrds are untouched. |
| `miniboot-switch.conf` / `miniboot.conf` (`/etc/mkinitcpio.d/`, `MODULES=`/`HOOKS=` arrays) | `debian/initramfs.conf` + `debian/modules` | `MODULES=list` + explicit module list; `BUSYBOX=y`, `KEYMAP=n`, `COMPRESS=gzip`. ⚠️ `MODULES=dep` is unusable where `/` is undetectable (docker/overlayfs: "failed to determine device for /"); `list` also avoids that probe entirely. |
| `mkinitcpio -c … -k /boot/vmlinuz-linux -g /boot/miniboot-switch.img` | `mkinitramfs -d /etc/miniboot/initramfs-tools -o /boot/miniboot-switch.img <kver>` in `debian/miniboot-refresh.sh` → `/usr/sbin/miniboot-refresh.sh` | `<kver>` defaults to newest `/lib/modules`. `/usr/share` hooks still run for `-d` builds (udev/kmod/busybox) → image is ~14 MB gzip, not 6 MB. Accepted: maintainability over bytes. Silence the harmless `can't cd to …/scripts` warning with an empty `scripts/` dir in the confdir. |
| `systemd/95-miniboot.hook` (`/etc/pacman.d/hooks`, `Target=linux`) | `debian/zz-miniboot` → `/etc/kernel/postinst.d/zz-miniboot` | Kernel packages call it with `(version, image_path)` after every install. Chosen over `DPkg::Post-Invoke` (no version arg, fires on unrelated upgrades) — postinst.d is the exact pacman-hook equivalent. |
| `scripts/miniboot-refresh.sh` (hardcodes `/boot/vmlinuz-linux`) | `debian/miniboot-refresh.sh` | Takes `$KVER`, enforces **kernel pinning** (AGENTS.md): ESP kernel and image modules are always deployed as a pair (`vmlinuz-miniboot` + `miniboot-switch.img`). |
| `/boot/vmlinuz-linux` | `/boot/vmlinuz-<kver>` | ESP copy named `vmlinuz-miniboot` (never clobbers distro files). EFI entry: `-l /EFI/miniboot/vmlinuz-miniboot`. |
| `/boot/initramfs-<ver>.img`, `/boot/amd-ucode.img`, `/boot/intel-ucode.img` (kexec packing in `kexec_boot`) | ⚠️ **Needs upstream fallback** (see §3) | Debian: `initrd.img-<ver>`; **no `/boot/*-ucode.img` exist** — microcode ships in `/usr/lib/firmware/{intel-ucode,amd-ucode}/` and is prepended into *every* initrd as early-ucode cpio (verified: `AuthenticAMD.bin` in stock + MiniBoot images). kexec target therefore needs **no manual packing** — pass its `initrd.img` directly. |
| `install.sh` (`efibootmgr`, pacman, `optdepends`) | Not yet ported (straightforward) | Same flow, Debian spelling: `apt install efibootmgr kexec-tools busybox initramfs-tools`, `KERNEL=$(ls -v /boot/vmlinuz-* \| tail -1)`, rescue root via `debootstrap` instead of `pacstrap`. |
| `uninstall.sh`, `PKGBUILD`, `miniboot.install` | Not yet ported | `uninstall.sh` mirrors 1:1 (`rm` hook/confdir/postinst.d + `efibootmgr -B`); packaging TBD (native `.deb` vs windos module script). |
| Rescue root (`pacstrap` minimal Arch) | `debootstrap --variant=minbase trixie /opt/miniboot-root` + DE/`kexec-tools`/autologin getty | Same `/opt/miniboot-root` (SUBDIR) convention. |
| `lsinitcpio` (verify image) | `lsinitramfs` (+ `unmkinitramfs` to split early/main) | Used for all verification below. |

## 2. What needed NO changes

- **Scripts run verbatim.** Audited every external used by `miniswitch.sh` /
  `miniboot.sh` / `detect-root.sh` / `windos-preinit.sh`; Debian trixie
  busybox (the exact binary initramfs-tools embeds, `BUSYBOX=y`) provides all
  of them: `sh sed awk grep cut tr blkid mdev insmod modprobe switch_root
  mount umount reboot poweroff ls head uname find readlink`. Two deltas, both
  benign: `lspci` absent (sysinfo already degrades to `GPU="?"`), and `tr`
  **present** (only Arch's `mkinitcpio-busybox` lacked it — the AGENTS.md
  warning does not apply here).
- **`kexec-tools`**: same package name, `/usr/sbin/kexec`; Xen libs
  auto-resolved by `copy_exec`. `kexec --initrd` single-file rule unchanged.
- **`efibootmgr`/EFI variables/entries.conf/`switch_root`/reboot-to-firmware**:
  identical mechanics (efivarfs, `BootNext`, `OsIndications`).
- **PARTUUID trap, PID-file rule, function-before-use**: POSIX-level, carry over.

## 3. Required script deltas (upstream proposals, not windos forks)

1. **`kexec_boot()` initramfs names** (`miniswitch.sh:165-172`,
   same block in `miniboot.sh`): add Debian fallbacks —
   `initrd.img-${_ver}` → `initrd.img` — before giving up. Zero Arch impact.
2. **Microcode block** (`miniswitch.sh:163-164`): keep as-is (silent no-op on
   Debian); optionally add a comment that Debian targets self-carry early
   microcode. No behaviour change needed.
3. **`windos-preinit.sh` (ours)**: add a `modprobe`-first branch. The
   initramfs-tools image stores compressed modules under
   `/usr/lib/modules/<ver>/` with `modules.dep`, and embeds kmod — so
   `modprobe` replaces the two-pass `insmod` loop (which targets the
   hand-rolled `/lib/modules/ko/*.ko` layout and no-ops here). Keep the
   `insmod` loop as fallback for the hand-built image from
   `tools/build-miniboot-initrd.sh`. Module list must mirror `debian/modules`.
   Proposed diff (verified in the QEMU test below; not yet applied to
   `windos-preinit.sh` itself — that file is out of scope for this task):
   ```sh
   _MP=""
   for _p in /usr/sbin/modprobe /sbin/modprobe; do
       [ -x "$_p" ] && _MP="$_p" && break
   done
   [ -z "$_MP" ] && _MP="$(command -v modprobe 2>/dev/null)"
   if [ -n "$_MP" ]; then
       for _m in virtio_pci virtio_blk virtio_scsi nvme sd_mod ahci libahci \
                  libata usb-storage uas ext4 xfs btrfs vfat; do
           "$_MP" "$_m" 2>/dev/null || :
       done
       unset _m
   else
       # ... existing two-pass insmod loop unchanged ...
   fi
   unset _MP _p
   ```
   (Absolute paths first: `rdinit` starts with a bare environment — no
   guarantee `modprobe` is on `PATH`.)

## 4b. Gotchas hit while prototyping (do not lose these)

- **Hooks must be executable.** `run_scripts` skips non-`+x` files *silently*:
  one `docker cp` (mode 644) produced a complete-looking 13.9 MB image with
  zero MiniBoot files in it. `install.sh` must `install -m0755` the hook.
- **Hook runs only via its own confdir; stock builds never see it** — by
  design (no `update-initramfs` bloat). Rebuild trigger is postinst.d, §1.
- **Empty `scripts/` dir required in the confdir**, else mkinitramfs warns
  `can't cd to …/scripts` (benign). `install.sh` must `mkdir -p` it.

## 4. Prototype + tests (Debian 13)

Prototype files: `debian/{hooks/miniboot,initramfs.conf,modules,miniboot.conf,
miniboot-refresh.sh,zz-miniboot}` — all `bash -n` clean.

- **Build** (trixie container, kernel 6.12.107): `mkinitramfs -d
  /etc/miniboot/initramfs-tools -o /boot/miniboot-switch.img <kver>` →
  **14 MB**; `lsinitramfs` confirms `/miniswitch.sh`, `/detect-root.sh`,
  `/windos-preinit.sh` (0755), `kexec` (+xen libs), 35 modules with deps
  auto-resolved (`scsi_mod`, `nvme-auth`, …), early-ucode cpio present.
- **QEMU boot** (AGENTS.md recipe, fixtures in `~/miniboot-test/`):
  `vmlinuz-6.12.107+deb13-amd64` + `miniboot-switch.img` (this prototype),
  `rdinit=/windos-preinit.sh miniboot.root=<uuid> miniboot.timeout=25
  miniboot.kextra=init=/bin/sh console=ttyS0,115200`, 1 GB virtio ext4 disk
  carrying the Debian kernel + stock `initrd.img` + a compat symlink
  `initramfs-<ver>.img → initrd.img-<ver>` (stand-in for §3.1):
  - TUI renders, sysinfo populated (`QEMU Virtual CPU`, `1973 MB RAM`,
    `disks: vda 1G`), countdown auto-picks Main (`deb13-port2.log`).
  - Root mounts (ext4 via modprobe branch), kernel picker lists the Debian
    kernel, auto-pick → `jumping into /boot/vmlinuz-6.12.107+deb13-amd64 …`
    → `kexec_core: Starting new kernel`.
  - Target kernel boots its stock initrd on VGA (`BusyBox 1.37.0 Debian`
    `(initramfs)` prompt, `deb13-shot2.png`); it stops there only because
    the fixture disk has no `/bin/sh` — expected, fixture limitation, not a
    port issue. Without the compat symlink `kexec_boot` prints
    `!! no initramfs`, confirming §3.1 is required.
  - Round 1 (unmodified `windos-preinit.sh`) failed exactly as predicted:
    no `/proc|/sys|/dev` in image → blank sysinfo + `!! cannot mount root`
    loop (`deb13-port.log`). Fixed by the hook skeleton (§4b) + the §3.3
    modprobe branch (tested as a container-side copy; `windos-preinit.sh`
    itself untouched).
