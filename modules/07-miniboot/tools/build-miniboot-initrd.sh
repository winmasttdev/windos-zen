#!/usr/bin/env bash
# ===========================================================================
#  windOS Zen — Module 7: MiniBoot initrd builder (Debian-flavoured)
#
#  winmasttdev/miniboot is Arch-shaped: mkinitcpio install hooks, pacman
#  kernel hooks. Debian has neither in the repos, and we refuse to carry
#  foreign packaging. Instead we assemble the same 6-MB-class initramfs by
#  hand: busybox-static + kexec(+libs) + upstream scripts + a curated
#  storage-module set, packed with cpio|gzip. No mkinitcpio, no dracut.
#
#  Rules honoured from miniboot/AGENTS.md:
#    * upstream sources are copied, never edited (branding lives elsewhere)
#    * kexec --initrd takes ONE file: microcode bundling stays the caller's
#      job (`cat microcode.img initrd.img > bundle.img`)
#    * busybox applet availability is verified here, not assumed
#
#  Usage:
#    tools/build-miniboot-initrd.sh [OUT.img]
#  Env:
#    MINIBOOT_SRC   upstream checkout      (default /home/user/miniboot)
#    MODROOT        dir holding lib/modules/<kver>  (default auto-detect)
#    KVER           kernel version to pack modules from
# ===========================================================================
set -euo pipefail

ZEN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MINIBOOT_SRC="${MINIBOOT_SRC:-/home/user/miniboot}"
OUT="${1:-$ZEN/build/miniboot-windos.img}"
STAGE="$ZEN/build/.miniboot-stage"

[ -d "$MINIBOOT_SRC/scripts" ] || { echo "ERROR: MINIBOOT_SRC=$MINIBOOT_SRC lacks scripts/" >&2; exit 1; }

# --- locate kernel modules root ------------------------------------------------
if [[ -z "${MODROOT:-}" ]]; then
    if [[ -d /lib/modules && -n "$(ls /lib/modules 2>/dev/null)" ]]; then
        MODROOT=/
    else
        MODROOT="$ZEN/build/kernel"
    fi
fi
KVER="${KVER:-$(ls "$MODROOT/lib/modules" 2>/dev/null | head -1)}"
[[ -n "$KVER" ]] || { echo "ERROR: no lib/modules/<kver> under $MODROOT" >&2; exit 1; }
echo "== MiniBoot initrd for kernel $KVER =="

rm -rf "$STAGE"; mkdir -p "$STAGE"/{bin,sbin,lib/modules/ko,proc,sys,dev,run,etc,mnt,tmp}

# --- busybox: static, full applet symlink forest -------------------------------
BB=$(command -v busybox)
file "$BB" | grep -q 'statically linked' || { echo "ERROR: $BB is not static (apt install busybox-static)" >&2; exit 1; }
install -m0755 "$BB" "$STAGE/bin/busybox"
for applet in $($BB --list); do
    case "$applet" in
        busybox|sh) ;;
        *) ln -sf /bin/busybox "$STAGE/bin/$applet" ;;
    esac
done
ln -sf /bin/busybox "$STAGE/bin/sh"

# applets miniswitch.sh/detect-root.sh actually touch — fail loudly if absent
for need in sh sed awk grep cut printf uname mount umount insmod lsmod mdev \
            blkid lsblk? cat sleep read dd kexec? halt reboot poweroff; do
    case "$need" in *\?) continue;; esac
    "$STAGE/bin/busybox" "$need" --help >/dev/null 2>&1 \
        || echo "WARN: busybox applet '$need' missing (script may degrade)"
done

# --- kexec: the whole reason this initrd exists --------------------------------
KEXEC=$(command -v kexec)
install -m0755 "$KEXEC" "$STAGE/sbin/kexec"
mkdir -p "$STAGE/lib"
ldd "$KEXEC" | awk '/=> \//{print $3} /ld-linux/{print $1}' | sort -u | while read -r lib; do
    [[ -e "$lib" ]] || continue
    dest="$STAGE/lib/$(basename "$lib")"
    [[ -e "$dest" ]] || cp "$lib" "$dest"
done
# kexec needs /sbin in PATH inside the initrd
ln -sf /sbin/kexec "$STAGE/bin/kexec"

# --- upstream scripts, VERBATIM -------------------------------------------------
install -m0755 "$MINIBOOT_SRC/scripts/detect-root.sh" "$STAGE/detect-root.sh"
install -m0755 "$MINIBOOT_SRC/scripts/miniswitch.sh"  "$STAGE/miniswitch.sh"
# windOS preinit: module loading hand-off (Debian kernels modularise storage)
install -m0755 "$ZEN/modules/07-miniboot/windos-preinit.sh" "$STAGE/windos-preinit.sh"

# --- curated storage modules (insmod order handled by preinit's 2 passes) ------
MODSRC="$MODROOT/lib/modules/$KVER/kernel"
want=(
  drivers/scsi/scsi_mod.ko drivers/scsi/sd_mod.ko
  drivers/ata/libata.ko drivers/ata/libahci.ko drivers/ata/ahci.ko
  drivers/virtio/virtio_pci.ko drivers/block/virtio_blk.ko
  drivers/nvme/host/nvme-core.ko drivers/nvme/host/nvme.ko
  drivers/usb/storage/usb-storage.ko
  fs/ext4/ext4.ko fs/mbcache.ko fs/jbd2/jbd2.ko
  fs/xfs/xfs.ko fs/btrfs/btrfs.ko
  fs/fat/fat.ko fs/fat/vfat.ko fs/nls/nls_iso8859-1.ko fs/nls/nls_utf8.ko
)
packed=0
for rel in "${want[@]}"; do
    src=$(find "$MODSRC" -path "*${rel##*/}" -print -quit 2>/dev/null)
    [[ -n "$src" && -f "$src" ]] || src=$(find "$MODROOT/lib/modules/$KVER" -name "${rel##*/}" -print -quit 2>/dev/null)
    if [[ -n "$src" && -f "$src" ]]; then
        cp "$src" "$STAGE/lib/modules/ko/"
        packed=$((packed+1))
    fi
done
echo "   packed $packed/${#want[@]} storage modules"

# --- pack ------------------------------------------------------------------------
mkdir -p "$(dirname "$OUT")"
( cd "$STAGE" && find . -print0 | LC_ALL=C sort -z | cpio --null -o -H newc --quiet ) \
    | gzip -9 > "$OUT"
echo "   $(du -h "$OUT" | cut -f1)  $OUT"
echo "   contents: $( (cd "$STAGE" && find . | wc -l) ) nodes"
rm -rf "$STAGE"
echo "== done =="
