#!/usr/bin/env bash
# ===========================================================================
#  windOS Zen — LXQt edition post-install (Module 5)
#  Runs as root in-target from Calamares when the LXQt edition is selected.
#  Installs the LXQt stack and writes /etc/skel Openbox + LXQt defaults:
#    Arc-Dark widgets, Papirus-Dark icons, windOS wallpaper.
#  Idempotent: safe to run twice (apt is a no-op, skel files overwritten).
# ===========================================================================
set -euo pipefail

TARGET="${1:-/}"
SKEL="${TARGET}/etc/skel"
WALLPAPER="/usr/share/wallpapers/windos-zen-1920x1080.png"

if [ "$(id -u)" -ne 0 ]; then
  echo "[windos-lxqt] ERROR: must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "[windos-lxqt] installing LXQt edition packages..."
apt-get update -qq || true
apt-get install -y --no-install-recommends \
  lxqt-core openbox qterminal arc-theme papirus-icon-theme

echo "[windos-lxqt] writing Openbox defaults to ${SKEL}/.config/openbox/rc.xml..."
mkdir -p "${SKEL}/.config/openbox" \
         "${SKEL}/.config/lxqt" \
         "${SKEL}/.config/pcmanfm-qt/lxqt"

# Openbox rc.xml. Mod4 (Super) is the windOS key; bindings mirror
# modules/03-fluxbox/skel/.fluxbox/keys where they make sense on LXQt
# (qterminal instead of alacritty, lxqt-runner instead of rofi).
cat > "${SKEL}/.config/openbox/rc.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!-- windOS Zen — Openbox defaults for the LXQt edition.
     Mod4 (Super) is the windOS key. Mirrors the fluxbox keys file. -->
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>
  <theme>
    <name>Arc-Dark</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow">
      <name>Cantarell</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Cantarell</name>
      <size>10</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
  </theme>
  <desktops>
    <number>2</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>one</name>
      <name>two</name>
    </names>
    <popupTime>875</popupTime>
  </desktops>
  <keyboard>
    <!-- launchers -->
    <keybind key="W-Return">
      <action name="Execute"><command>qterminal</command></action>
    </keybind>
    <keybind key="W-t">
      <action name="Execute"><command>qterminal</command></action>
    </keybind>
    <keybind key="W-d">
      <action name="Execute"><command>lxqt-runner</command></action>
    </keybind>
    <keybind key="W-r">
      <action name="Execute"><command>lxqt-runner</command></action>
    </keybind>
    <keybind key="W-w">
      <action name="Execute"><command>firefox-esr</command></action>
    </keybind>
    <keybind key="W-e">
      <action name="Execute"><command>pcmanfm-qt</command></action>
    </keybind>
    <!-- window management -->
    <keybind key="W-q">
      <action name="Close"/>
    </keybind>
    <keybind key="W-f">
      <action name="ToggleFullscreen"/>
    </keybind>
    <keybind key="W-m">
      <action name="ToggleMaximize"/>
    </keybind>
    <keybind key="W-i">
      <action name="Iconify"/>
    </keybind>
    <keybind key="W-s">
      <action name="ToggleDecorations"/>
    </keybind>
    <keybind key="W-Tab">
      <action name="NextWindow"><dialog>none</dialog></action>
    </keybind>
    <keybind key="W-S-Tab">
      <action name="PreviousWindow"><dialog>none</dialog></action>
    </keybind>
    <!-- workspaces -->
    <keybind key="W-1">
      <action name="GoToDesktop"><to>1</to></action>
    </keybind>
    <keybind key="W-2">
      <action name="GoToDesktop"><to>2</to></action>
    </keybind>
    <keybind key="W-F1">
      <action name="SendToDesktop"><to>1</to></action>
    </keybind>
    <keybind key="W-F2">
      <action name="SendToDesktop"><to>2</to></action>
    </keybind>
    <!-- desktop -->
    <keybind key="W-F11">
      <action name="ToggleShowDesktop"/>
    </keybind>
    <keybind key="W-l">
      <action name="Execute"><command>loginctl lock-session</command></action>
    </keybind>
    <keybind key="W-Space">
      <action name="ShowMenu"><menu>root-menu</menu></action>
    </keybind>
    <!-- media keys -->
    <keybind key="XF86AudioRaiseVolume">
      <action name="Execute"><command>amixer -q sset Master 5%+ unmute</command></action>
    </keybind>
    <keybind key="XF86AudioLowerVolume">
      <action name="Execute"><command>amixer -q sset Master 5%- unmute</command></action>
    </keybind>
    <keybind key="XF86AudioMute">
      <action name="Execute"><command>amixer -q sset Master toggle</command></action>
    </keybind>
    <keybind key="XF86MonBrightnessUp">
      <action name="Execute"><command>brightnessctl set +10%</command></action>
    </keybind>
    <keybind key="XF86MonBrightnessDown">
      <action name="Execute"><command>brightnessctl set 10%-</command></action>
    </keybind>
  </keyboard>
  <mouse>
    <context name="Frame">
      <mousebind button="A-Left" action="Press">
        <action name="Focus"/>
        <action name="Raise"/>
      </mousebind>
      <mousebind button="A-Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="A-Right" action="Drag">
        <action name="Resize"/>
      </mousebind>
    </context>
  </mouse>
  <menu>
    <file>menu.xml</file>
    <hideDelay>200</hideDelay>
  </menu>
</openbox_config>
EOF

echo "[windos-lxqt] writing LXQt session defaults..."
cat > "${SKEL}/.config/lxqt/session.conf" <<'EOF'
# windOS Zen — LXQt session defaults (Arc-Dark / Papirus-Dark, Openbox WM)
[General]
__userfile__=true
leave_confirmation=false
lock_command=loginctl lock-session
window_manager=openbox
EOF

cat > "${SKEL}/.config/lxqt/lxqt.conf" <<'EOF'
# windOS Zen — LXQt appearance defaults
[General]
__userfile__=true
icon_theme=Papirus-Dark
theme=Arc-Dark
single_click_activate=false
tool_button_style=ToolButtonTextBesideIcon
EOF

echo "[windos-lxqt] wiring pcmanfm-qt desktop wallpaper..."
cat > "${SKEL}/.config/pcmanfm-qt/lxqt/settings.conf" <<EOF
# windOS Zen — pcmanfm-qt desktop (draws the LXQt wallpaper)
[Desktop]
Wallpaper=${WALLPAPER}
WallpaperMode=fill
ShowWmMenu=true
EOF

echo "[windos-lxqt] done. Wallpaper: ${WALLPAPER}"
