#!/usr/bin/env bash
#
# apply-gnome.sh — apply the windOS Zen GNOME glassmorphic preset.
# Run as the target USER (e.g. from Calamares shellprocess / first boot).
#
set -e

PRESET="/usr/share/windos/gnome/windos-gnome-dconf.conf"

if command -v dconf >/dev/null 2>&1; then
    dconf load / < "$PRESET"
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.shell enabled-extensions \
        "['dash-to-dock@micxgx.gmail.com','blur-my-shell@aunetx','appindicatorsupport@rgcjonas.gmail.com','user-theme@gnome-shell-extensions.gcampax.github.com']" \
        2>/dev/null || true
fi

echo "windOS Zen GNOME preset applied."
