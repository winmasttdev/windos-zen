#!/usr/bin/env bash
#
# windOS Zen — archiso profile definition
# Base: Arch Linux (rolling, lean). Boot: GRUB for both Legacy BIOS + UEFI.
# Kernel: linux-zen (low-latency). Boot splash: Plymouth "windos-zen".
#
# https://wiki.archlinux.org/title/Archiso

iso_name="windos-zen"
iso_label="WINDOS_ZEN"
iso_publisher="windOS: Lighter Than Air <https://windos.nn1kk00.ru/>"
iso_application="windOS Zen — Ultra-light Linux for legacy hardware"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')

# Legacy BIOS (syslinux) + UEFI (grub) — both from a single grub.cfg for UEFI.
bootmodes=(
    'bios.syslinux'
    'uefi.grub'
)

arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')

# GPG signing (optional). Leave empty to skip signing.
# iso_gpg_key=""

file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/usr/local/bin/windfetch"]="0:0:755"
    ["/usr/local/bin/windos-post-install.sh"]="0:0:755"
)
