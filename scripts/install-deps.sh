#!/usr/bin/env bash
#
# install-deps.sh — install the host packages needed to build windOS Zen.
# Run on an Arch Linux build machine (not inside the ISO).
#
set -e
sudo pacman -S --needed \
    archiso \
    grub \
    libisoburn \
    squashfs-tools \
    edk2-ovmf \
    librsvg \
    imagemagick \
    curl \
    git
echo "Host build dependencies installed."
