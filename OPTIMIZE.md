# windOS Zen — Optimization Plan

**Research date:** 2026-10-12 · **Target:** Debian 13 "Trixie", GNOME live session + Calamares multi-DE installer
**Method:** static audit of `/home/winmastt/windos-zen/live-build` + **live measurement** of the built ISO
(`windos-zen-1.0-trixie-amd64.hybrid.iso`) booted under QEMU/KVM. Nothing in the tree was modified; no builds were run.

---

## 0. Measurement baseline (read this first)

The built ISO was booted twice under KVM (Ryzen 7 5700G host, 16 cores, `-smp 2`, emulated CD-ROM),
logged in over a serial console and instrumented. **All timings below are real, from that ISO.**

| Metric | Value | Source |
|---|---|---|
| Total to `graphical.target` | **51.18 s** (13.87 s kernel+initrd, 37.31 s userspace) | `systemd-analyze` |
| `graphical.target` reached | 37.31 s | `systemd-analyze` |
| **Critical chain owner** | `plymouth-quit-wait.service` **+20.68 s** | `systemd-analyze critical-chain` |
| Next worst units | `dev-sr0.device` 9.21 s, `dev-loop0.device` 8.04 s, `ldconfig.service` 6.29 s, `live-config.service` 4.68 s | `systemd-analyze blame` |
| Idle RAM @2 GB VM | 1072 MB used / 900 MB available, 15 MB zram used | `free -m`, `/proc/swaps` |
| Idle RAM @1 GB VM | 990 MB total, 495 MB zram configured, 0 in use | `free -m` |
| Failed units | **0** | `systemctl --failed` |
| ISO size | **1918 MiB** | `ls` |
| ├ squashfs | 1759 MiB (91.7 %), xz, 128 K blocks | `file`, build log |
| ├ **initrd ×2, byte-identical** | **267 MiB (13.9 %) wasted** | md5 identical |
| └ **vmlinuz ×2, byte-identical** | **23 MiB (1.2 %) wasted** | md5 identical |
| initrd uncompressed | **264 MiB**, of which **198 MiB is firmware** | cpio parse |
| Rootfs firmware | **851 MB** across 37 firmware packages | `du` |
| Packages | 1653 | `.packages` |

### The single most important finding

**systemd is not the bottleneck.** The critical chain is:

```
graphical.target @37.309s
└─power-profiles-daemon.service @37.170s
  └─multi-user.target
    └─getty.target
      └─serial-getty@ttyS0
        └─plymouth-quit-wait.service @16.479s +20.684s   <-- 41% of userspace boot
          └─systemd-user-sessions.service
            └─network.target @16.312s
              └─dbus.service → basic.target → sockets.target
                └─uuidd.socket @15.694s
                  └─sysinit.target
                    └─ldconfig.service @9.366s +6.293s
```

Every entry in that chain is either **I/O wait on the emulated optical drive**
(`dev-sr0`, `dev-loop0`), **a blocking wait unit** (`plymouth-quit-wait`), or a
**shell-script service doing real work** (`ldconfig`, `console-setup`, `keyboard-setup`).
Not one is "systemd scheduling overhead". Replacing PID 1 would change ~0 of these (see §4).

> **Caveat on absolute numbers:** emulated CD-ROM I/O is much slower than real USB/SSD, so
> `dev-sr0`/`dev-loop0` (17.2 s combined) are inflated. Re-measure on real media before
> prioritizing I/O items. The *structural* findings (initrd size, firmware bloat, duplicate
> payloads, the plymouth-quit-wait stall) are media-independent and are the basis of this plan.

### How to reproduce these measurements

```bash
ISO=windos-zen-1.0-trixie-amd64.hybrid.iso
# Extract without mounting (7z handles iso+squashfs; or use xorriso for /live/*)
mkdir -p /tmp/wz && 7z x -o/tmp/wz "$ISO" >/dev/null

# Boot with serial console, no GPU (add -vga std for a display), log in user/live:
qemu-system-x86_64 -enable-kvm -cpu host -m 1024 -smp 2 -vga std \
  -kernel /tmp/wz/live/vmlinuz -initrd /tmp/wz/live/initrd.img \
  -append 'boot=live components hostname=windos-zen console=ttyS0,115200n8' \
  -drive file="$ISO",media=cdrom,readonly=on -display none -serial stdio -no-reboot

# Then, at the login prompt (user / live):
systemd-analyze                      # headline numbers
systemd-analyze blame | head -25
systemd-analyze critical-chain
systemd-analyze dump | head -10      # kernel/userspace/finish timestamps
ps -eo rss,comm --sort=-rss | head -30
systemctl --failed
cat /proc/sys/vm/{swappiness,vfs_cache_pressure,min_free_kbytes}
cat /sys/block/zram0/disksize
```

To A/B test a change, rebuild the ISO and diff `systemd-analyze` totals. Keep
`-smp 2 -m 1024` constant; variance across runs is ±1–2 s, so only trust deltas >3 s.

---

## 1. BOOT TIME

### Where boot time actually goes

| Phase | Measured | What it is |
|---|---|---|
| Firmware → kernel | not measurable here | UEFI/BIOS. Hybrid ISO boots via `isolinux` (BIOS) or `grubx64.efi` (UEFI). |
| Kernel + initramfs | **13.87 s** | Decompressing a **264 MiB** initramfs and loading **198 MiB of firmware** it will never use for booting. |
| Userspace → `sysinit.target` | ~15.7 s | udev, `ldconfig` (6.3 s), `console-setup`, `keyboard-setup` |
| → `network.target` | +0.6 s | NetworkManager, `wpa_supplicant` |
| → `plymouth-quit-wait` finishes | +20.7 s | **Blocking wait on the splash teardown** |
| → `graphical.target` | +20.8 s | gdm3, GNOME Shell start |

**The kernel/initramfs phase is the single largest controllable cost**, and it is
self-inflicted: the initrd carries 198 MiB of firmware for datacenter NICs (netronome
24.9 MiB), NVIDIA GSP (61.6 MiB), AMD (77.8 MiB) and i915 (10 MiB) that a "potato hardware"
distro will never touch.

### 1.1 — Cut the initramfs firmware payload ★★★★★

- **Gain: 100–180 MiB off the initrd (140 → ~20–40 MiB).** Expected boot saving **2–6 s**
  on real media (less on SSD, more on USB 2.0 / spinning rust). Also cuts ~100 MiB off the ISO.
- **Measure:** `du -h /tmp/wz/live/initrd.img` before/after; `systemd-analyze` total;
  `lsinitramfs /tmp/wz/live/initrd.img | grep -c firmware`.
- **Risk: MEDIUM.** Too aggressive a whitelist will break boot on some GPUs/NICs.
  The safe subset: exclude firmware for hardware that cannot appear in this distro's
  target class (netronome/liquidio/mrvl datacenter NICs, nvidia GSP, xe) while keeping
  i915/amdgpu/radeon/ath*/rtw*/brcm/realtek.
- **Exact change:** new file
  `live-build/config/includes.chroot/etc/initramfs-tools/hooks/windos-slim-initramfs`
  (initramfs-tools copies `/usr/lib/firmware` wholesale when `MODULES=most`).
  Add to `live-build/config/hooks/live/010-windos-tuning.hook.chroot`, after the existing
  blocks, a hook that prunes `/usr/lib/firmware/{netronome,liquidio,mrvl,nvidia,xe,airoha,cavium,cisco,netxen,qlogic,myricom,...}`
  **before** the binary stage runs `mkinitramfs`. Pair with an `initramfs-tools/conf.d/`
  drop-in that sets `MODULES=dep`.

### 1.2 — `MODULES=most` → `MODULES=dep` ★★★★☆

- **Gain: 34.8 MiB → a few MiB** (the 893 `.ko.xz` modules embedded by `MODULES=most`).
  Contributes ~0.3–1 s on fast media, more on slow.
- **Measure:** same as 1.1; compare `lsinitramfs | grep -c '\.ko'`.
- **Risk: MEDIUM-HIGH.** `dep` guesses from the *build host's* hardware. In a chroot that is
  your build machine, so `dep` can omit the exact driver a user's machine needs. **This is
  the classic live-image footgun.** Prefer `MODULES=most` + firmware pruning (1.1), which
  keeps driver coverage and removes only dead weight. If you do try `dep`, ship a known-good
  `/etc/initramfs-tools/modules` list and test on real hardware.
- **Exact change:** `live-build/config/includes.chroot/etc/initramfs-tools/initramfs.conf`
  (currently `MODULES=most` at line 20), or better an override file
  `live-build/config/includes.chroot/etc/initramfs-tools/conf.d/01-windos`.

### 1.3 — Fix the duplicated `vmlinuz`/`initrd` in the ISO ★★★★★

- **Gain: 290 MiB (15 % of the ISO) removed.** Byte-identical duplicates (verified by md5:
  both `initrd.img` and `initrd.img-6.12.111+deb13-amd64` = `e3a6861a…`; both vmlinuz = `3dd36133…`).
  Faster to write to USB, less to download, smaller to host. Boot speed impact ~0
  (both paths are read, but from a smaller ISO), so **this is a size/usability win, not a boot win.**
- **Measure:** `xorriso -indev "$ISO" -ls /live | sort -k7 -n`; ISO byte count before/after.
- **Risk: LOW-MEDIUM.** Both `isolinux/live.cfg` and `boot/grub/grub.cfg` reference the
  unversioned names (`linux /live/vmlinuz`, `initrd /live/initrd.img`) while the versioned
  copies exist for other consumers. Deleting the *versioned* copies is the safer half —
  but confirm nothing references them. live-build emits both by design in
  `LB_SYSTEM=live` mode.
- **Exact change:** binary-stage hook
  `live-build/config/hooks/live/021-windos-plymouth-binary.hook` (extend it) or a new
  `025-windos-dedup-payload.hook` — remove one of each pair from `live/` before ISO assembly.

### 1.4 — `plymouth-quit-wait.service`: 20.68 s ★★★★★ (highest gain/risk on this list)

- **Gain: up to ~20 s of userspace boot**, i.e. potentially the largest single win measured.
  This unit sits on the critical chain and *blocks* on the splash. It is also the reason
  `getty.target` cannot complete until 37.3 s.
- **Measure:** `systemd-analyze blame | grep plymouth`; `systemd-analyze critical-chain`.
- **Risk: LOW.** Two safe options: (a) drop plymouth entirely and remove the splash from
  the kernel cmdline; (b) keep plymouth but ensure `plymouth-quit-wait` is not the gate —
  it normally returns immediately, so a 20 s stall suggests the splash is being held by a
  slow `plymouth-quit`/`plymouth-quit-wait` handshake with gdm3. On the live ISO, the
  simplest robust fix is to not ship plymouth.
- **Exact change:** remove `plymouth` + `plymouth-themes` from
  `live-build/config/package-lists/00-minimal.list.chroot` (lines 32–33); drop `quiet splash`
  from the cmdline built in
  `live-build/config/hooks/live/020-windos-plymouth.hook.chroot` (line 28).
  **Trade-off: lose the branded boot splash (Module 2).** A compromise is keeping the theme
  but adding `plymouth.enable=0`… which is the same as removing it.
  *If the splash is a product requirement, do 1.1/1.3 first and re-measure — a large part of
  this stall is the splash waiting on a slow graphics stack, and a 100 MiB smaller initrd may
  shrink it substantially.*

### 1.5 — Mask/trim safe units on a live session ★★★★☆

Confirmed enabled-and-active on the booted ISO (`systemctl is-enabled`):

| Unit | Measured cost | Recommendation |
|---|---|---|
| `NetworkManager-wait-online.service` | on critical chain | **mask** — live session needs no boot-time network wait |
| `fwupd.service` | 1.31 s boot, **47 MB RSS (181 MB @1 GB!)** | **mask + remove `fwupd` pkg** |
| `e2scrub_reap.service` | enabled, active | **mask** — live overlay is tmpfs, scrubbing is meaningless |
| `cron.service` | enabled, active | **mask** — nothing to schedule |
| `apt-daily.timer`, `apt-daily-upgrade.timer` | timers.target | **mask** — no point updating package lists in RAM |
| `man-db.timer`, `dpkg-db-backup.timer`, `logrotate.timer`, `fstrim.timer`, `fwupd-refresh.timer` | timers.target | **mask** |
| `console-setup.service` (2.23 s), `keyboard-setup.service` (2.99 s) | serial scripts | **disable** on live (keymap already baked) |
| `grub-common.service` (enabled in 5 target wants) | idle | **mask** |
| `switcheroo-control`, `power-profiles-daemon` | small | keep (power-profiles is on the critical chain) |
| `low-memory-monitor.service` (GRD alias) | small | keep |

- **Gain: ~3–5 s** combined, plus ~50–230 MB RAM from fwupd alone.
- **Measure:** `systemd-analyze blame` before/after; `ps -eo rss,comm | grep fwupd`;
  `systemctl --failed` must stay empty.
- **Risk: LOW.** All are either irrelevant on a live overlay or trivially re-enabled.
- **Exact change:** extend the existing `for svc in ...` loop in
  `live-build/config/hooks/live/010-windos-tuning.hook.chroot` (lines 21–31) with the list above,
  and add `systemctl mask apt-daily.timer apt-daily-upgrade.timer …`.

### 1.6 — Squashfs: xz vs zstd vs block size ★★★☆☆

Current: **xz, 131072-byte blocks** (from the build log: `Exportable Squashfs 4.0 filesystem, xz compressed, data block size 131072`).
Kernel has all decompressors (`CONFIG_SQUASHFS_XZ=y`, `CONFIG_SQUASHFS_ZSTD=y`, `CONFIG_SQUASHFS_LZ4=y`,
and `CONFIG_SQUASHFS_DECOMP_MULTI_PERCPU=y` for parallel decompression).

| Codec | Decompress speed (relative) | Size | Verdict for potato CPU |
|---|---|---|---|
| **xz** (current) | ~1× (slowest, single-digit MB/s on old cores) | smallest | Costs boot time and every file read |
| **zstd -19** | **3–5× faster** | ~8–15 % larger | Best default for this distro |
| **zstd -12** | ~5–7× faster | ~15–25 % larger | Faster still |
| lz4 | fastest | +30–50 % | Too big for a 1.9 GB ISO |

- **Gain: meaningful CPU-time reduction on every squashfs read** — this is the difference
  between a session that feels sluggish on an old CPU and one that doesn't, because *every*
  binary/library read from the live rootfs is a decompress. Realistically **1–3 s off boot**
  and a broad reduction in interactive latency on the whole session.
- **Measure:** `unsquashfs -stat` on the built squashfs for size;
  `systemd-analyze` total; `hyperfine 'cat /usr/lib/x86_64-linux-gnu/libX11.so.6'` in-guest
  repeated 20× for I/O latency.
- **Risk: LOW.** Fully supported; changes only ISO size and read speed.
- **Exact change:** `live-build/config/common` — currently **no `LB_SQUASHFS_OPTIONS` is set**,
  so live-build picked the Debian default. Add e.g.:
  `LB_SQUASHFS_OPTIONS="-comp zstd -b 131072 -Xcompression-level 19"`
  Note: **`-b 131072` should be kept.** Larger blocks (e.g. 1 MB) compress better but
  inflate decompression latency per read and RAM spikes; smaller blocks (4–32 K) reduce
  per-read latency and RAM spikes at the cost of size — worth A/B testing 64 K vs 128 K
  specifically for the interactive-latency goal.
- **Secondary: shrink the ISO root cause.** The 851 MB `/usr/lib/firmware` in the rootfs is
  44 % of the squashfs's uncompressed content. netronome (141 MB), nvidia (124 MB), mrvl (68 MB),
  mediatek (45 MB), ath11k (63 MB) are largely irrelevant to the stated hardware class.
  Dropping the datacenter/vendor blobs could cut the ISO by 300–400 MB. Same risk class as 1.1.

---

## 2. RAM

Target from the tree: *"Idle budget for the whole LiveCD session: < 180 MB RSS"*
(`00-minimal.list.chroot` lines 3–4). **Measured reality: ~1072 MB used at idle on GNOME.**
That budget is off by ~6×. The gap is not a tuning bug — it is that `gnome-core` is GNOME 48
with Software, PackageKit, Clocks, Online Accounts and Tracker installed.

### 2.1 — The measured RSS table (2 GB VM, `ps -eo rss,comm --sort=-rss`)

| RSS (KiB) | Process | Assessment |
|---|---|---|
| 372556 | `gnome-shell` | irreducible for GNOME; compositor choice is the lever (§3) |
| **140804** | **`gnome-software`** | **~141 MB. Not wanted on a live image.** Biggest single win. |
| 117584 | `mutter-x11-fram(e)` | the compositor — see §3 |
| 79312 | `gsd-xsettings` | high because GTK/XSettings compile is cold on first run |
| **75268** | **`evolution-alarm`** | **Clocks' alarm-notification stack; idle in a live session** |
| 63732 | `Xwayland` | running XWayland under a **Wayland** session — see §3.1 |
| **60504** | **`evolution-source`** | **evolution-data-server; pulled in by gnome-clocks** |
| **47572 (181 MB @1 GB)** | **`fwupd`** | **useless on live media; scales badly** |
| 43780 | `packagekitd` | Software's backend |
| 42408 | `xdg-desktop-portal` | required by Flatpak/Software; drops if Software goes |
| 40360 | `gnome-control-center` | on-demand normally; was open here |
| 37460 + 34908 | `localsearch-3` + `localsearch-extract` | **~72 MB of file indexing — useless on a read-only squashfs** |
| 29360 | `evolution-addressbook` | ditto |
| 25280 | `goa-daemon` | Online Accounts — needed only if the user signs in |
| 24296 | `wireplumber` | PipeWire session manager — see 2.4 |

### 2.2 — Priority-ordered RAM actions

**A. Drop GNOME Software + PackageKit (~185 MB) ★★★★★**
- **Gain: ~185 MB RSS** (140804 + 43780), plus removes `xdg-desktop-portal`'s main
  activator, plus **1.3 s** of `fwupd`-adjacent boot work. Software is a store client — on a
  live image it has nothing to install into.
- **Measure:** `ps -eo rss,comm | grep -E 'gnome-software|packagekitd'`; `free -m` idle delta.
- **Risk: MEDIUM.** GNOME's Software is how a user installs packages on the live session.
  Mitigation: replace with the already-shipped `synaptic`/`gdebi` or document apt.
- **Exact change:** remove `gnome-core` → substitute explicit GNOME session packages in
  `live-build/config/package-lists/10-gnome.list.chroot` (line 8); or keep `gnome-core` and
  add `dpkg --remove`/`--purge gnome-software packagekit` in
  `live-build/config/hooks/live/010-windos-tuning.hook.chroot`.

**B. Drop Tracker/localsearch (~72 MB) ★★★★★**
- **Gain: ~72 MB RSS** and removes an ongoing indexing workload — on a read-only squashfs
  overlay this is pure waste and background I/O.
- **Measure:** `ps -eo rss,comm | grep -E 'localsearch|tracker'`;
  `systemctl --user is-active localsearch-3.service`.
- **Risk: LOW.** Only loses GNOME's file search. Can keep the UI by pointing search at
  `tracker3` disabled + a lighter indexer, or just accept losing it.
- **Exact change:** `live-build/config/hooks/live/010-windos-tuning.hook.chroot` —
  `systemctl --global disable localsearch-3.service tracker-miner-fs-3.service`;
  and remove `tracker-extract` from the package lists (it is pulled in, not listed).

**C. Drop gnome-clocks / evolution-data-server (~168 MB total) ★★★★☆**
- **Gain: ~168 MB RSS** (`evolution-alarm` 75 + `evolution-source` 61 + `evolution-addressbook` 29 +
  `evolution-calendar` 24, minus overlap). All idle in a live session.
- **Risk: LOW-MEDIUM.** Removes the clock/calendar panel. For a "lightweight" distro this is
  the correct call; for a "modern glassmorphic" brand, it is a visible feature loss.
- **Exact change:** remove `gnome-clocks` (pulled via `gnome-core`) from
  `live-build/config/package-lists/10-gnome.list.chroot`; purge
  `evolution-data-server` in the 010 hook.

**D. Mask fwupd (~48–181 MB) ★★★★★**
Already covered in §1.5. Worst offender at 1 GB RAM, which is precisely the target class.

**E. geoclue / pipewire / cups / ModemManager ★★★★☆**
- `geoclue-2.0` is installed but only activates on demand; **no** idle cost. Leave it.
- **PipeWire**: already the right choice over PulseAudio. `wireplumber` 24 MB is normal.
  Do **not** "optimize" by removing it — see §3 myths.
- `cups`, `ModemManager`, `bluetooth`, `avahi`: already correctly masked in the 010 hook
  (verified: symlinks to `/dev/null` exist in the chroot). **Good — no action.**
  One gap: `cups-browsed.service` is masked but the package still ships; dropping
  `cups-browsed` saves ~0 RSS and ~4 MB of squashfs.

### 2.3 — zram sizing: validate it ★★★☆☆

Policy in `live-build/config/includes.chroot/usr/local/lib/windos/zram-setup.sh`:
`min(50% RAM, 2 GiB)`, floor 256 MiB, **zstd level 3**, `swapon -p 100`.

Verified live at 1 GB: `MemTotal 990300 kB` → `SwapTotal 495148 kB`,
`/sys/block/zram0/disksize = 507035648` (= 483 MiB = 50 % of RAM), `comp_algorithm` shows
`lz4 lz4hc [zstd] deflate` with **zstd selected** — so the `ALG=zstd` write **works**.
At 2 GB: `disksize 1034731520` (986 MiB). The policy is correct and the cap logic is sound.

**Three real issues:**

1. **`swapon -p 100` + `vm.swappiness = 10` fight each other.** Priority 100 makes zram the
   top-priority swap device, but swappiness 10 tells the kernel to avoid swapping. Result,
   observed: **15 MB of zram in use at idle while 219 MB sits completely free.** The zram
   device is doing nothing under normal load — it is insurance that only engages under
   pressure. That is arguably the correct behaviour, but then swappiness 10 is doing
   double duty and the policy deserves an explicit decision.
2. **Level 3 zstd is a reasonable default; level 1 would be faster.** For a swap device,
   compression *ratio* matters more than speed (you are already out of memory), so **keep 3**.
3. **`mkswap` runs on every boot** inside the unit. On a RAM-backed live overlay that is a
   needless write to tmpfs; harmless (~ms) but it is also why `swapoff` on shutdown logs
   capacity-change messages. Minor.

- **Gain from changing sizing:** ~0 on boot. **Recommendation: keep 50 %/2 GiB/zstd-3.**
  If you want zram to actually engage earlier, raise `vm.swappiness` to **60–100** (the
  common zram recommendation, since zram swap is ~RAM-speed) instead of 10. This is the
  single highest-leverage line in the whole sysctl file.
- **Measure:** `cat /sys/block/zram0/mm_stat` (field 1 = orig_data_size, 2 = compr_data_size →
  compression ratio), `vmstat 1` under load, `earlyoom` kill log.
- **Risk: LOW.**

### 2.4 — sysctl sanity review of `99-windos.conf`

| Setting | Verdict | Note |
|---|---|---|
| `vm.swappiness = 10` | **Questionable** | Contradicts a 50 %-RAM zram at priority 100. With zram, 60–100 is the usual setting. See 2.3. |
| `vm.vfs_cache_pressure = 50` | **Fine** | Mild, defensible for small RAM. |
| `vm.min_free_kbytes = 16384` | **Wrong — actively harmful** | See below. |
| `vm.dirty_ratio/background/expire/writeback` | Fine | `dirty_writeback_centisecs=500` is aggressive-but-safe. |
| `vm.laptop_mode = 0` | No-op | Already the kernel default; the comment ("without the daemon") describes something this line does not do. |
| `vm.overcommit_memory = 0` + `overcommit_ratio = 80` | **No-op** | With `overcommit_memory=0` (heuristic), `overcommit_ratio` is **ignored**. The comment implies it does something. Pick one: either heuristic (mode 0, drop the ratio line) or always-overcommit (mode 1, drop the ratio). |
| `vm.compact_unevictable_allowed = 0` | **Misleading** | This is a debug/threshold knob, not the THP switch the comment describes. **There is no `transparent_hugepage` setting in this file at all.** Add `vm.thp_defrag = never` or leave THP alone. |
| `net.core.rmem_max/wmem_max = 4 MB` | **Comment is wrong** | The comment says "small buffers"; 4 MiB is *large*. The real legacy-NIC lever is `net.core.netdev_max_backlog` and `ethtool -K`, not rmem. Harmless, but delete or fix the comment. |
| `net.ipv4.tcp_congestion_control = bbr` | **Verify it applies** | `tcp_bbr.ko.xz` exists in the module tree but BBR is a **module**. If it isn't loaded before sysctl runs, the write silently fails. Also `tcp_congestion_control` belongs in `/etc/modules-load.d/` + `sysctl`, and `bbr` requires `tcp_bbr`. **Measure: `cat /proc/sys/net/ipv4/tcp_congestion_control` after boot.** If it reads `cubic`, this line is decorative. |
| atime | **Comment claims per-fstab noatime, but there is no fstab in this tree** | grep to confirm. |

**`min_free_kbytes` — concrete bug.** The kernel computes
`min_free_kbytes = clamp(int_sqrt(lowmem_kbytes * 16), 128, 262144)` (verified in
`mm/page_alloc.c`, `calculate_min_free_kbytes()`). For 1 GB RAM that is **~4096 kB**;
for 2 GB, **~5793 kB**. The tree hardcodes **16384 kB** with the comment "*(scaled: ~16 MB)*".
It is not scaled — it is a constant, and it is **4–16× the kernel default**. On a 1 GB box
that pins 16 MB (1.6 % of RAM) permanently out of general allocation, which is exactly the
memory you are trying to conserve. **Remove the line and let the kernel scale it.**

- **Exact change:** `live-build/config/includes.chroot/etc/sysctl.d/99-windos.conf` line 29 —
  delete `vm.min_free_kbytes = 16384` (and the now-wrong comment on line 28).
  Mirror copy to update: `modules/06-tuning/99-windos.conf` (verified byte-identical today —
  **keep them in sync**).
- **Gain:** ~10 MB of usable RAM on a 1 GB machine. Small but free, and it removes a
  "tuning" knob that is actively wrong.

### 2.5 — earlyoom validation ★★★☆☆

Current: `EARLYOOM_ARGS="-r 3600 -m 5 -s 2 --prefer '(chrome|firefox|chromium)'"`

- `-r 3600` is the **memory *report* interval**, not the check interval — earlyoom polls
  adaptively up to 10×/s regardless. So `-r 3600` is harmless and, if anything, good (it
  keeps the journal quiet). **Not a bug.** (Easy to misread this one.)
- `-m 5 -s 2` trips at 5 % available RAM / 2 % free swap. With only 483 MB of zram, 2 %
  free swap = ~10 MB — earlyoom will fire very late in a real squeeze. **Reasonable but
  tight.** Consider `-m 8 -s 8` so it acts before the OOM killer.
- `--prefer '(chrome|firefox|chromium)'` is an ERE matched against the process name.
  windOS Zen **ships no browser** in the GNOME edition (Firefox is only in
  `packages-fluxbox.list`), so this rule matches nothing in the default image. Harmless,
  but it signals the config was copied from a different project.
- **Missing: `--avoid` protection for the session itself.** earlyoom's default victim
  selection is "largest oom_score". On this image that could be `gnome-shell` (372 MB) —
  killing it drops the user to a black screen mid-work. Consider:
  `--avoid '(gnome-shell|Xorg|systemd|pipewire)'`.
- **Gain:** correctness, not speed. Prevents the worst-case failure mode on a 1 GB box.
- **Risk: LOW.** **Exact change:** `live-build/config/hooks/live/010-windos-tuning.hook.chroot`
  lines 12–17 (the `cat > /etc/default/earlyoom` heredoc).

---

## 3. RUNTIME FEEL ON POTATO HARDWARE

### 3.1 — Compositor: the biggest interactive-latency lever ★★★★☆

**The measured session ran XWayland under Wayland and still had 63 MB of XWayland plus
117 MB of `mutter-x11-frames`.** On a CPU with no hardware GL, GNOME 48's native Wayland
compositor falls back and costs *more*, not less. This is a real, measured effect.

| Edition | Current compositor | Recommendation |
|---|---|---|
| **GNOME** (default) | Mutter (Wayland or X11) | Keep Mutter — GNOME cannot run without it. Reduce its **work**: disable blur, drop `blur-my-shell`, disable animations, force `X11`/`on-demand` for old GPUs. |
| **Fluxbox** | `picom` (already in `packages-fluxbox.list`) | Keep. picom with `--backend xrender` (or none) is the right call on potato hardware. |
| **XFCE** | xfwm4 | Keep; compositor optional. |
| **LXQt** | openbox | Keep. |
| **KDE** | kwin | Expensive; keep kwin but disable effects in the edition script. |
| **Tiling** | sway/openbox | Cheap. |

**Critical measured finding for GNOME:** `blur-my-shell` is **enabled by default** in
`config/includes.chroot/usr/share/windos/windos-gnome.dconf`
(`enabled-extensions=[… 'blur-my-shell@aunetx' …]`). A gaussian blur of every window on every
frame, composited in software, is one of the most expensive things you can ask a potato CPU
to do. **It is a per-frame CPU cost, invisible to every measurement in this document except
frame rate.**

- **Gain: the difference between usable and unusable on old hardware.** Not expressible in
  seconds — measure it in **frame rate**: `LIBGL_ALWAYS_SOFTWARE=1 glxgears -info 2>&1 | grep FPS`,
  and GNOME's own `Alt+F2` → `lg` (Looking Glass) FPS counter.
- **Risk: LOW** technically; **HIGH** for the brand, because blur is the "Modern
  Glassmorphic" identity. This is a product decision, not an engineering one. Recommend an
  **auto-detect**: disable blur when no hardware GL is detected
  (`glxinfo | grep -q 'direct rendering' && glxinfo | grep -q 'OpenGL renderer string: llvmpipe' → disable`).
- **Exact change:** `live-build/config/hooks/live/040-windos-gnome-defaults.hook.chroot`
  (which installs `windos-gnome.dconf` into `/etc/dconf/db/local.d/00-windos`), plus
  `live-build/config/includes.chroot/usr/share/windos/windos-gnome.dconf` for the static case.
- **Also enabled:** `dashtodock`, `appindicator`, `user-theme`. Dash-to-dock and
  user-theme are cheap. **`appindicator`** adds a per-app icon-overdraw cost — drop it on the
  low-end profile.

### 3.2 — I/O scheduler for spinning rust ★★★☆☆

- **The live session runs from a read-only squashfs over a DVD/USB stick — the scheduler
  matters mainly for the *installed* system on an HDD.** Default on modern kernels is
  `mq-deadline`, which is correct for a live image.
- **`bfq`** gives dramatically better interactive latency on rotational disks (it is the
  fair-scheduling I/O scheduler) at a small throughput cost. It is **not in mainline** —
  it ships as `bfq` in `linux-image-rt`/Debian's `bfq` module package.
- **Recommendation:** keep `mq-deadline` for the **live** image (bfq on a DVD/USB stick buys
  nothing you can feel). For **installed** systems on a potato HDD, offer `bfq` via the
  installer as an opt-in, or set it in `windos-de-setup.sh`.
- **Gain (installed systems on HDD):** interactive latency 2–5× better under concurrent
  load. **Live image: ~0.**
- **Risk: LOW-MEDIUM** — `bfq` is out-of-tree-ish and adds a module dependency.
- **Exact change:** `live-build/config/includes.chroot/usr/local/bin/windos-de-setup.sh`
  (post-install script), gated on the target device being rotational.

### 3.3 — CPU frequency governor ★★★☆☆

`linux-cpupower` is installed but **nothing sets a governor** — `cpufreq` defaults to
`schedutil` (or `ondemand` on older kernels), which is a reasonable default.

- **Recommendation: leave it alone, or set `powersave` explicitly only on battery.**
  On a *desktop* (always on AC), `performance` is measurably better and thermally irrelevant.
  The tree's `20-zen-extras.list.chroot` comment already states this intent; there is just
  no unit implementing it.
- **Gain: 0–5 % single-core throughput on a desktop.** Small.
- **Risk: LOW.** `performance` on a laptop = heat and fan noise. Gate on AC.
- **Exact change:** a new unit, e.g.
  `live-build/config/includes.chroot/etc/systemd/system/windos-cpufreq.service`, enabled from
  the 010 hook — or better, do it in `power-profiles-daemon`, which is **already enabled**
  and already manages this. Probably the correct answer is *no change at all*.

### 3.4 — journald: validate the 32 MB cap ★☆☆☆☆ (no action)

`SystemMaxUse=32M`, `RuntimeMaxUse=16M`, `MaxLevelStore=warning`.
Measured live: **`journalctl --disk-usage` → 4 MB.** The cap is working and is never
approached. It is also irrelevant on a live session because there is no persistent journal
to fill — `/var/log/journal` lives on the tmpfs overlay and dies at shutdown.

**Verdict: correctly configured, no change needed.** The only arguable tweak is
`MaxLevelStore=warning`, which suppresses info-level logs and makes debugging harder
(`systemd-analyze` and gnome-shell tracing both want info/debug). Leave it; the 32 MB cap
costs nothing when actual use is 4 MB.

### 3.5 — logind / handle-lid ★★☆☆☆

- **Default `HandleLidSwitch=suspend`.** On a **live image running from removable media**,
  closing the lid suspends the machine — and suspending a live session is a data-loss /
  confused-user experience (the CD may be ejected on resume).
- **Recommendation:** set `HandleLidSwitch=ignore` and `IdleAction=ignore` for the live
  session only; restore the defaults in `windos-de-setup.sh` for the installed system.
- **Gain:** avoids a support FAQ ("my live session sleeps when I close the lid"). Not a speed win.
- **Risk: LOW.** Getting it wrong on the *installed* system would be bad — hence the
  "live only" split.
- **Exact change:** new file
  `live-build/config/includes.chroot/etc/systemd/logind.conf.d/99-windos-live.conf`;
  restore in `live-build/config/includes.chroot/usr/local/bin/windos-de-setup.sh`.

### 3.6 — Myths to AVOID (do not do these)

| Myth | Why it's wrong |
|---|---|
| **preload / readahead daemons** | `preload` was removed from Debian and is absent upstream for a reason: it guesses wrong, wastes RAM, and on a **squashfs** (already-compressed, already-ordered, read-once) it cannot help at all. Modern kernels do readahead in the block layer automatically. **Do not add.** |
| **`systemd is slow / PID 1 overhead** | Measured critical chain (§0): the chain is I/O wait + `plymouth-quit-wait` + shell scripts. There is no "PID 1 overhead" line in it. See §4. |
| **disable journald / auditd to "save RAM"** | journald measured 4 MB. audit/AppArmor cost more but provide security. **Do not disable AppArmor** on a live image that runs `pkexec calamares`. |
| **`swappiness=0` or "never swap"** | With a zram device present, high swappiness is the point — zram swap is RAM-speed. `swappiness=10` under-uses it (§2.3). `0` would be actively wrong. |
| **Remove PipeWire for "lighter" audio** | PipeWire is *already* the lighter and better-behaved option; `wireplumber` at 24 MB is normal. PulseAudio would be a regression. |
| **`vm.swappiness` + `vfs_cache_pressure` micro-tuning as a performance lever** | These change *which* memory is reclaimed under pressure. They do not make a fast path faster. The measured zram usage (15 MB of 483 MB) shows the current policy is mostly inert anyway. |
| **Dropping `plymouth` "because splash is slow"** | Correct instinct, wrong diagnosis — but see §1.4, where it is nonetheless the right move for a *different* reason (the 20 s blocking wait). |
| **`noflush`/`sync` tuning, `vm.dirty_*` micro-tuning on a read-only overlay** | The live rootfs is squashfs (read-only) with a tmpfs overlay. Dirty-page tuning barely applies. Harmless, but no gain. |

---

## 4. THE INIT QUESTION — replacing systemd PID 1

**Short answer: do not do it. The measurements say the cost/benefit is strongly negative,
and the dependency facts say the migration is a rewrite, not a swap.**

### 4.1 — What the measurements say

The critical chain (§0) contains **zero units attributable to PID 1's own work**.
`systemd-analyze` attributes time to *units*, and the top offenders are:

- `dev-sr0.device` (9.2 s) / `dev-loop0.device` (8.0 s) — **device I/O wait**, not scheduling
- `plymouth-quit-wait.service` (20.7 s) — **a deliberate blocking wait**, which is a
  *design choice of the image*, not of the init system
- `ldconfig.service` (6.3 s), `console-setup` (2.2 s), `keyboard-setup` (3.0 s) — **shell
  scripts doing real work**; a different init would still have to run them

Every one of those is fixable **without touching PID 1** (§1.4, §1.5, and `update-rc.d`-style
masking). An alternative init that *also* has to run ldconfig and udev rules would land in
the same place. **Expected gain from swapping PID 1: single-digit percent, possibly zero,
possibly negative** (a less-parallel init can be *slower* on a 2-core VM).

There is a legitimate, much cheaper framing: systemd's *reputation* for slowness comes from
**serial dependencies** (e.g. `uuidd.socket` on the chain). Those are ordering choices in
your unit files, fixable with drop-ins.

### 4.2 — What breaks if you replace PID 1 anyway

This is the decisive part. On this specific stack:

1. **GNOME is now a hard systemd dependency.** GNOME 48 (shipped here) postdates upstream's
   2025 announcement of *stronger* systemd dependencies — GNOME now requires the systemd
   user-instance manager for session process spawning, and `gnome-shell` delegates its
   process management to `systemd --user`. The historical escape hatch was **elogind**
   (systemd-logind reimplemented standalone). elogind works, but:
   - It is a **substitute for logind only** — it does not provide `systemd --user`, the
     dbus-activated unit semantics, `sd-bus` notifications, or `sd-login` semantics that
     newer GNOME uses.
   - Debian does **not** ship an elogind build of GNOME 48. You would be maintaining a
     patched GNOME stack — the opposite of what this project wants.
   - Upstream GNOME has signalled it is moving *further* toward systemd, not away. This
     debt only gets more expensive.

2. **Calamares is systemd-shaped.** 3.3.14 ships `systemd` unit files and its modules
   (`displaymanager`, `services`, `users`, `luksbootkeyfile`, …) invoke `systemctl
   enable/disable/start` to configure the **installed** system. Notably, your
   `unpackfs.conf`/`netinstall-windos.conf`/`packagechooser-de.conf` chain installs a Debian
   or Devuan *target* system — if the live image's init differs from the target's, the
   installer has to bridge two init systems. Your `displaymanager` handling would need an
   OpenRC/sysvinit equivalent for the target.

3. **Debian package maintainer scripts are systemd-shaped.** 1653 packages ship
   `deb-systemd-helper` enable/disable calls, `systemctl preset`, and
   `postinst` snippets that assume `systemctl` exists. On a live image these mostly no-op,
   but any runtime script that calls `systemctl` (GNOME's own, NetworkManager's, `live-config`,
   udev rules with `SYSTEMD_WANTS`) breaks or silently degrades.

4. **You also lose:** socket activation (your `live-config.service` and the masked
   `cups.socket`/`avahi-daemon.socket` model), `sd_notify` readiness protocol (gdm3,
   NetworkManager, and GNOME Shell all use it — this is how the *graphical* boot is
   sequenced at all), cgroup-based resource control, and `systemd-analyze` itself — i.e.
   **you lose the measuring instrument** that produced this entire report.

5. **You do not gain a supported Debian derivative.** Devuan is Debian-derived, but
   switching to it changes: package names/versions, the `live-build` distro backend
   (`debian` → `devuan`), the GNOME build (Devuan patches GNOME for elogind — you inherit
   their patch set and its bit-rot), the installer target defaults, and your whole package
   list pinning. **It is a fork, not a configuration.**

### 4.3 — Devuan-base migration cost estimate

Rough order of magnitude, for a maintainer who already knows this tree:

| Work item | Estimate |
|---|---|
| Re-base `live-build` on Devuan, fix package lists | 1–3 days |
| Resolve GNOME-on-OpenRC/elogind regressions across 48.x | **1–4 weeks** (upstream-moving target) |
| Calamares OpenRC/displaymanager module + target-config bridging | 3–7 days |
| Replace all `systemctl` calls in hooks 010/040 + `windos-de-setup.sh` | 2–4 days |
| Re-test the entire installer + all 6 DE editions | 1–2 weeks |
| Ongoing: tracking Devuan's patch set + Debian rebases | **permanent, recurring** |

**Total: roughly 3–7 weeks to a working equivalent, plus permanent maintenance** — to solve
a problem the measurements above say does not exist.

### 4.4 — Recommendation

**Keep systemd. Spend the same 3–7 weeks on §1.4 + §2.2 + §1.1, which are worth
~20–30 s of boot and ~500 MB of RAM on the measured image** — i.e. an order of magnitude
more user-visible benefit, at a fraction of the risk, with no fork to maintain.

If a smaller init is genuinely a project goal, the **correct** sequencing is: land all of §1
and §2 first, re-measure, and only then revisit. The honest expectation is that the boot
will already be good enough that the question closes itself.

---

## 5. KERNEL: 6.12 LTS vs 7.x

**Recommendation: stay on Debian's 6.12 LTS. Do not backport 7.x for this hardware class.**

### 5.1 — What 7.x actually delivers

| Feature | Version | Real benefit for potato hardware |
|---|---|---|
| **Cache-aware scheduling** (`CONFIG_SCHED_CACHE`) | 7.2 | **~0.** Published gains (hackbench +30 %, schbench p99 wakeup −38 %, ChaCha20 +44 %) are on **multi-LLC server CPUs** (Xeon Sapphire Rapids, AMD Genoa) with dozens of cores and split last-level caches. A 2–4 core box with one shared L3 has nothing to place away from — the optimization has no degrees of freedom. |
| Redesigned hybrid task scheduler | 7.0 | Intel Nova Lake (Arrow Lake successor). Irrelevant — that is new silicon, the opposite of this target. |
| exFAT via iomap | 7.2 | "Up to 87 % faster on SD cards and USB drives." Only relevant if the medium is exFAT — this ISO is ISO9660/squashfs and is **read-only**. No benefit. |
| Btrfs large folios (+15 % sequential writes) | 7.2 | Btrfs is not used. |
| NTSYNC improvements, Rust-in-core, XFS self-healing | 7.0/7.x | No effect on a squashfs live image. |
| General driver maturity | — | **Mixed.** 7.x *adds* support for very new hardware and **removes/complicates support for some old hardware**. For a 2008–2015 vintage target this is a net risk, not a gain. |

### 5.2 — What 7.x will NOT fix

Every bottleneck measured in §0 is **outside the kernel's control**:

- `dev-sr0` / `dev-loop0` — media speed
- 264 MiB initramfs, 198 MiB of it useless firmware — **build configuration**
- `plymouth-quit-wait` 20.7 s — **unit design**
- `ldconfig` 6.3 s — **a shell script doing real work**
- `gnome-shell` 372 MB — **GNOME's design**
- `gnome-software` 141 MB, Tracker 72 MB — **package selection**
- Software rendering — **GPU**, not kernel

A newer kernel makes **none** of these faster. If you shipped 7.x tomorrow, `systemd-analyze`
would report essentially the same numbers.

### 5.3 — The real kernel-side wins (all available on 6.12 today)

If the goal is better behavior on old hardware, these are the levers — **none require a
newer kernel**:

1. **Initramfs firmware pruning** (§1.1) — the dominant initramfs cost.
2. **`CONFIG_*` review of the Debian kernel** — verify `CONFIG_ZRAM=m` is built (it is) and
   consider `zram` as a module loaded earlier.
3. **Firmware quality** — for genuinely old hardware, *newer firmware blobs on the old
   kernel* is the win. The tree already ships 37 firmware packages; the gain from a 7.x
   kernel is dwarfed by shipping the right firmware for the actual target NIC/GPU.

### 5.4 — Cost of switching

- Debian stable ships 6.12 as `linux-image-amd64`. A 7.x kernel means carrying
  `linux-image` from trixie-backports/sid or building it — **you become the kernel
  maintainer** for a project whose stated goal is being lightweight.
- Old-hardware regressions in mainline (recent kernels have dropped several legacy
  platforms outright) would surface on exactly the machines this distro targets.
- The measured boot is dominated by I/O and userspace; a kernel swap buys ~0 s.

---

## 6. RANKED ACTION LIST (by gain ÷ risk)

| # | Action | Gain | Risk | Where |
|---|---|---|---|---|
| 1 | Remove `haveged` (obsolete since kernel 5.6) | ~1 MB + boot | LOW | `20-zen-extras.list.chroot` |
| 2 | Fix `min_free_kbytes` → let kernel scale | ~10 MB RAM | LOW | `99-windos.conf:29` |
| 3 | Mask live-useless units (NM-wait-online, cron, e2scrub, apt timers, fwupd) | 3–5 s + ~50–230 MB | LOW | `010` hook `:21-31` |
| 4 | Drop GNOME Software + PackageKit | ~185 MB RSS | MED | `10-gnome.list.chroot:8` |
| 5 | Disable Tracker/localsearch | ~72 MB RSS + I/O | LOW | `010` hook |
| 6 | Drop gnome-clocks + evolution-data-server | ~168 MB RSS | LOW-MED | `10-gnome.list.chroot` |
| 7 | Squashfs: xz → **zstd -19**, keep `-b 131072` | ISO ~−8 %, big interactive-latency win | LOW | `config/common` (`LB_SQUASHFS_OPTIONS`) |
| 8 | `plymouth-quit-wait` — drop plymouth or fix the stall | **up to ~20 s** | LOW (brand cost) | `00-minimal:32-33`, `020` hook `:28` |
| 9 | Initramfs firmware pruning | 100–180 MiB, 2–6 s | MED | new `initramfs-tools/hooks/windos-slim-initramfs` |
| 10 | Dedupe `vmlinuz`/`initrd` in ISO | −290 MiB (15 % of ISO) | LOW-MED | binary hook `025-windos-dedup-payload.hook` |
| 11 | Raise `vm.swappiness` 10 → 60–100 (with zram) | zram actually engages | LOW | `99-windos.conf:10` |
| 12 | earlyoom: add `--avoid '(gnome-shell\|systemd)'`, retune `-m`/`-s` | correctness | LOW | `010` hook `:12-17` |
| 13 | Trim rootfs `/usr/lib/firmware` (851 MB) | −300–400 MB ISO | MED | package list / hook |
| 14 | `blur-my-shell` auto-off without hardware GL | **frame rate** | LOW / brand | `windos-gnome.dconf`, `040` hook |
| 15 | logind `HandleLidSwitch=ignore` (live only) | support-quality | LOW | new `logind.conf.d/99-windos-live.conf` |
| 16 | `bfq` opt-in for HDD installs | 2–5× HDD latency | LOW-MED | `windos-de-setup.sh` |
| 17 | Verify BBR actually loaded | correctness | LOW | `/etc/modules-load.d/bbr.conf` |
| 18 | `MODULES=dep` | 34.8 MiB | **MED-HIGH** | only after #9, and test on real hw |
| 19 | Squashfs `-b` 64 K vs 128 K A/B | latency vs size | LOW | `config/common` |
| 20 | Kernel 6.12 → 7.x | **~0** | HIGH (fork) | **don't** |
| 21 | Replace systemd PID 1 | **~0, likely negative** | **VERY HIGH** (3–7 wks) | **don't** |

### Suggested order of work

**Phase 1 (afternoon, ~zero risk):** items 1, 2, 3, 11, 12, 17. Rebuild, re-measure.
**Phase 2 (day, low risk):** items 4, 5, 6, 7. This is where most of the RAM comes back.
**Phase 3 (decision required):** items 8 and 14 — both trade the "Modern Glassmorphic"
brand identity for performance. **These are product calls for the owner.**
**Phase 4 (careful, needs real-hardware testing):** items 9, 10, 13, 16, 18, 19.
**Never:** items 20, 21.

### Re-measurement checklist after each phase

```bash
systemd-analyze                            # compare "Startup finished" total
systemd-analyze critical-chain              # is the chain still plymouth/ldconfig?
ps -eo rss,comm --sort=-rss | head -20     # compare RSS column
free -m                                     # idle "used"
cat /proc/sys/vm/min_free_kbytes            # expect ~4096 at 1 GB, not 16384
cat /sys/block/zram0/mm_stat                # orig vs compr size
systemctl --failed                          # MUST stay empty
```

Keep the VM config fixed (`-m 1024 -smp 2`) and take **3 runs per configuration** — variance
is ±1–2 s, so treat anything under 3 s as noise.