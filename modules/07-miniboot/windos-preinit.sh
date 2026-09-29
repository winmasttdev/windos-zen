#!/bin/busybox sh
# ===========================================================================
#  windOS Zen — MiniBoot preinit (Module 7)
#  rdinit=/windos-preinit.sh
#
#  MiniBoot upstream (github.com/winmasttdev/miniboot) boots with
#  rdinit=/miniswitch.sh and relies on the *kernel's built-in* drivers for
#  storage (Arch kernels ship ext4/virtio/nvme built-in). Debian kernels do
#  not: ext4, xfs, btrfs, ahci, nvme, virtio_blk are modules. So windOS Zen
#  inserts this 20-line preinit: mount the pseudo-filesystems, insmod the
#  curated storage set (two passes = dependency order without depmod), let
#  mdev populate /dev, then hand over to upstream miniswitch.sh UNMODIFIED.
#
#  Upstream stays pristine. That is the deal we made with winmastt.
# ===========================================================================

mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs -o mode=0755 dev /dev
mount -t devpts   devpts   /dev/pts   2>/dev/null
mkdir -p /run /tmp /mnt
mdev -s 2>/dev/null

# --- storage + filesystems: two insmod passes resolve deps by brute force ---
_pass=1
while [ "$_pass" -le 2 ]; do
    for _ko in /lib/modules/ko/*.ko; do
        [ -e "$_ko" ] || break
        insmod "$_ko" 2>/dev/null || :
    done
    _pass=$((_pass + 1))
done
unset _pass _ko

mdev -s 2>/dev/null
sleep 1   # let virtio/usb/nvme settle before the TUI goes looking for disks

exec /miniswitch.sh
