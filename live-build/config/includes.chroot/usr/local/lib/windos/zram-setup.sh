#!/bin/sh
# ============================================================================
#  windOS Zen — zram swap setup (zstd), invoked by windos-zram.service
#
#  Why not systemd-zram-generator? It isn't in Debian main and we refuse to
#  carry out-of-distro packages. 60 lines of POSIX sh beats a dependency.
#
#  Sizing: min(50% of RAM, 2 GiB) virtual, zstd level 3. On a 1 GB box that
#  is 512 MB of zram which compresses ~3:1 for browser-y anonymous memory —
#  effectively tripling the usable RAM of a potato.
# ============================================================================
set -e

ZRAM_DEV=/dev/zram0
ALG=zstd
LEVEL=3

ram_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
size_kb=$(( ram_kb / 2 ))
max_kb=$(( 2 * 1024 * 1024 ))
[ "$size_kb" -gt "$max_kb" ] && size_kb=$max_kb
min_kb=$(( 256 * 1024 ))
[ "$size_kb" -lt "$min_kb" ] && size_kb=$min_kb
size_bytes=$(( size_kb * 1024 ))

case "$1" in
start)
    modprobe zram || true
    [ -b "$ZRAM_DEV" ] || exit 0

    # reset if something is already on it (reboot races)
    if grep -q ' 1$' /sys/block/zram0/initstate 2>/dev/null; then
        swapoff "$ZRAM_DEV" 2>/dev/null || true
        echo 1 > /sys/block/zram0/reset
    fi

    echo "$ALG" > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lzo-rle > /sys/block/zram0/comp_algorithm
    if [ -w /sys/block/zram0/compression_level ]; then
        echo "$LEVEL" > /sys/block/zram0/compression_level || true
    fi
    echo "$size_bytes" > /sys/block/zram0/disksize

    mkswap -L windos-zram "$ZRAM_DEV" >/dev/null
    swapon -p 100 "$ZRAM_DEV"
    ;;
stop)
    swapoff "$ZRAM_DEV" 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    ;;
*)
    echo "usage: $0 {start|stop}" >&2; exit 2
    ;;
esac
exit 0
