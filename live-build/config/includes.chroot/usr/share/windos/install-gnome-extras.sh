#!/usr/bin/env bash
# windOS Zen — GNOME post-install (Module 5)
# Runs in-target from Calamares when the GNOME edition is selected.
# Enables extensions, loads the dconf profile, masks telemetry-adjacent daemons.
set -euo pipefail
TARGET="${1:-/}"
DCONF_SRC="$(dirname "$0")/windos-gnome.dconf"
echo "[windos-gnome] applying dconf profile..."
if [ -f "$DCONF_SRC" ]; then
  sudo -u "$SUDO_USER" dbus-launch dconf load / < "$DCONF_SRC" 2>/dev/null || \
    dconf load / < "$DCONF_SRC" 2>/dev/null || true
fi
echo "[windos-gnome] enabling extensions..."
for ext in dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com user-theme@gnome-shell-extensions.gcampax.github.com; do
  gnome-extensions enable "$ext" 2>/dev/null || true
done
echo "[windos-gnome] masking background telemetry..."
for svc in geoclue.service gnome-remote-desktop.service; do
  systemctl mask "$svc" 2>/dev/null || true
done
echo "[windos-gnome] done."
