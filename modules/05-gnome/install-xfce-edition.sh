#!/usr/bin/env bash
# windOS Zen — XFCE edition post-install (Module 5)
# Runs in-target as root from Calamares when the XFCE edition is selected.
# Idempotent: safe to run twice (apt install + full-file overwrites only,
# no appends, mkdir -p everywhere).
set -euo pipefail

TARGET="${1:-/}"
SKEL_DIR="${TARGET}/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
WALLPAPER="/usr/share/wallpapers/windos-zen-1920x1080.png"

export DEBIAN_FRONTEND=noninteractive

echo "[windos-xfce] installing packages..."
apt-get update
apt-get install -y xfce4 xfce4-whiskermenu-plugin xfce4-terminal arc-theme papirus-icon-theme

echo "[windos-xfce] writing /etc/skel XFCE defaults..."
mkdir -p "$SKEL_DIR"

cat > "${SKEL_DIR}/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="FontName" type="string" value="Plus Jakarta Sans 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Plus Jakarta Sans 10"/>
    <property name="MonospaceFontName" type="string" value="JetBrains Mono 10"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuImages" type="bool" value="true"/>
  </property>
</channel>
EOF

cat > "${SKEL_DIR}/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Plus Jakarta Sans Bold 10"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="show_dock_shadow" type="bool" value="true"/>
    <property name="show_popup_shadow" type="bool" value="true"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="100"/>
    <property name="move_opacity" type="int" value="100"/>
    <property name="resize_opacity" type="int" value="100"/>
    <property name="zoom_desktop" type="bool" value="false"/>
  </property>
</channel>
EOF

cat > "${SKEL_DIR}/xfce4-panel.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="mode" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator"/>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="clock"/>
    <property name="plugin-6" type="string" value="actions"/>
  </property>
</channel>
EOF

cat > "${SKEL_DIR}/xfce4-desktop.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="image-path" type="string" value="${WALLPAPER}"/>
          <property name="image-show" type="bool" value="true"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

chmod 644 "${SKEL_DIR}/xsettings.xml" "${SKEL_DIR}/xfwm4.xml" \
  "${SKEL_DIR}/xfce4-panel.xml" "${SKEL_DIR}/xfce4-desktop.xml"

echo "[windos-xfce] done."
