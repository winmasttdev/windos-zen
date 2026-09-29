#!/bin/sh
# miniboot-refresh.sh — Debian port of scripts/miniboot-refresh.sh.
# Rebuilds the MiniBoot initrd for one kernel version and redeploys it.
# Called with the version by /etc/kernel/postinst.d/zz-miniboot on every
# kernel install (the pacman-hook equivalent); safe to run by hand.
# Kernel pinning (upstream AGENTS.md): the ESP kernel MUST match the modules
# inside this image — preinit insmods them into the running kernel. This
# script always copies the pair together, never one without the other.
set -e
CONF="${MINIBOOT_CONF:-/etc/miniboot/miniboot.conf}"
[ -r "$CONF" ] && . "$CONF"
KVER="${1:-}"
if [ -z "$KVER" ]; then
	KVER="$(ls /lib/modules 2>/dev/null | sort -V | tail -1)"
fi
[ -n "$KVER" ] || { echo "miniboot-refresh: no kernel version found" >&2; exit 1; }
[ -d "/lib/modules/$KVER" ] || { echo "miniboot-refresh: no modules for $KVER" >&2; exit 1; }
ESP="${MINIBOOT_ESP:-/boot/efi}"

mkinitramfs -d /etc/miniboot/initramfs-tools \
	-o /boot/miniboot-switch.img "$KVER"

mkdir -p "$ESP/EFI/miniboot"
cp "/boot/vmlinuz-$KVER" "$ESP/EFI/miniboot/vmlinuz-miniboot"
cp /boot/miniboot-switch.img "$ESP/EFI/miniboot/miniboot-switch.img"
echo "miniboot-refresh: $KVER deployed to $ESP/EFI/miniboot/"
