#!/usr/bin/env bash
# windOS Zen — KDE Plasma post-install (Module 5)
# Runs in-target from Calamares when the KDE Plasma edition is selected.
# Installs the Plasma desktop set, masks telemetry-adjacent daemons, and
# seeds /etc/skel + /etc/xdg defaults (dark Breeze palette, Papirus-Dark,
# panel-only KWin blur, windOS wallpaper). Safe to run twice.
set -euo pipefail
TARGET="${1:-/}"

echo "[windos-kde] installing Plasma desktop set..."
apt-get update -qq || true
apt-get install -y --no-install-recommends \
  kde-plasma-desktop dolphin konsole \
  arc-theme arc-kde papirus-icon-theme || true
# plasma-browser-integration reports browser activity back to Plasma and has
# no systemd unit, so it is neutralized by removal, not by masking.
apt-get purge -y plasma-browser-integration 2>/dev/null || true

echo "[windos-kde] masking background telemetry..."
# geoclue.service: freedesktop location broker; Plasma geolocation feeds off
# it. Real systemd unit in Trixie. Masked so nothing can start it on demand.
systemctl mask geoclue.service 2>/dev/null || true
# NOTE — intentionally NOT masked, and why (no real Trixie units involved):
# - Baloo file indexer: ships no systemd unit in Trixie (D-Bus/autostart
#   daemon); neutralized via baloofilerc below instead of a fake mask.
# - kactivitymanagerd: ships no systemd unit in Trixie; runs on-demand over
#   D-Bus, stores activity data locally only, performs no network I/O, so it
#   is left installed but idle (masking a nonexistent unit would just leave a
#   stray symlink and imply a guarantee we cannot keep).
# - ModemManager.service is a real unit but is left alone: masking it would
#   break mobile broadband with no telemetry benefit on machines that need it.

echo "[windos-kde] writing skel defaults..."
SKEL="$TARGET/etc/skel/.config"
mkdir -p "$SKEL"

# Dark Breeze-derived palette + Papirus-Dark icons for every new user.
cat > "$SKEL/kdeglobals" <<'EOF'
[General]
ColorScheme=BreezeDark
Name=BreezeDark
[Icons]
Theme=Papirus-Dark
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
EOF

# Baloo: content indexing off (the actual "file indexer phones home" surface
# is local CPU/IO churn plus indexed metadata; keep search, drop indexing).
cat > "$SKEL/baloofilerc" <<'EOF'
[Basic Settings]
Indexing-Enabled=false
EOF

# KWin: Blur plugin on, but scoped down. No translucency overrides are set
# anywhere, so only surfaces that explicitly request blur (panels, docks,
# tooltips) get it — plain windows stay opaque. Strength kept modest.
cat > "$SKEL/kwinrc" <<'EOF'
[Plugins]
blurEnabled=true
contrastEnabled=false
[Effect-Blur]
BlurStrength=5
NoiseStrength=0
EOF

# Plasma shell: windOS wallpaper on the default containment. Appended only
# once (idempotency marker) so re-runs never duplicate the section.
APPLETS="$SKEL/plasma-org.kde.plasma.desktop-appletsrc"
touch "$APPLETS"
if ! grep -q "windos-zen-1920x1080" "$APPLETS" 2>/dev/null; then
  cat >> "$APPLETS" <<'EOF'

[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/windos-zen-1920x1080.png
EOF
fi

echo "[windos-kde] done."
