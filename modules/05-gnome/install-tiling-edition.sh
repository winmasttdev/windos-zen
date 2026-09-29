#!/usr/bin/env bash
# ===========================================================================
#  windOS Zen — tiling/minimalist extras post-install (Module 5)
#  Runs as root in-target from Calamares when the tiling extras are selected.
#  Installs openbox + i3 + sway + labwc tooling and writes /etc/skel
#  dotfile skeletons for all three tilers sharing the windOS wallpaper.
#  Idempotent: safe to run twice (apt is a no-op, skel files overwritten).
# ===========================================================================
set -euo pipefail

TARGET="${1:-/}"
SKEL="${TARGET}/etc/skel"
WALLPAPER="/usr/share/wallpapers/windos-zen-1920x1080.png"

if [ "$(id -u)" -ne 0 ]; then
  echo "[windos-tiling] ERROR: must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "[windos-tiling] installing tiling extras packages..."
apt-get update -qq || true
apt-get install -y --no-install-recommends \
  openbox i3-wm i3status sway swaybg labwc foot rofi feh

mkdir -p "${SKEL}/.config/i3" \
         "${SKEL}/.config/i3status" \
         "${SKEL}/.config/sway" \
         "${SKEL}/.config/labwc"

echo "[windos-tiling] writing i3 skeleton..."
cat > "${SKEL}/.config/i3/config" <<EOF
# ===========================================================================
#  windOS Zen — i3 skeleton. Mod4 (Super) is the windOS key.
#  Mirrors modules/03-fluxbox/skel/.fluxbox/keys where sensible.
# ===========================================================================
set \$mod Mod4

# terminal + launcher
bindsym \$mod+Return exec foot
bindsym \$mod+t exec foot
bindsym \$mod+d exec rofi -show drun -show-icons
bindsym \$mod+r exec rofi -show run
bindsym \$mod+w exec firefox-esr
bindsym \$mod+e exec pcmanfm

# window management (fluxbox-flavoured)
bindsym \$mod+q kill
bindsym \$mod+f fullscreen toggle
bindsym \$mod+m floating toggle
bindsym \$mod+i focus parent
bindsym \$mod+Tab focus right
bindsym \$mod+Shift+Tab focus left
bindsym \$mod+h split h
bindsym \$mod+v split v
bindsym \$mod+s layout stacking
bindsym \$mod+Shift+s layout tabbed
bindsym \$mod+space focus mode_toggle

# workspaces 1..4 (+ move)
bindsym \$mod+1 workspace number 1
bindsym \$mod+2 workspace number 2
bindsym \$mod+3 workspace number 3
bindsym \$mod+4 workspace number 4
bindsym \$mod+Shift+1 move container to workspace number 1
bindsym \$mod+Shift+2 move container to workspace number 2
bindsym \$mod+Shift+3 move container to workspace number 3
bindsym \$mod+Shift+4 move container to workspace number 4

# session
bindsym \$mod+l exec loginctl lock-session
bindsym \$mod+Shift+e exec i3-msg exit
bindsym \$mod+Shift+r restart
bindsym \$mod+Shift+c reload

# media keys
bindsym XF86AudioRaiseVolume exec --no-startup-id amixer -q sset Master 5%+ unmute
bindsym XF86AudioLowerVolume exec --no-startup-id amixer -q sset Master 5%- unmute
bindsym XF86AudioMute exec --no-startup-id amixer -q sset Master toggle
bindsym XF86MonBrightnessUp exec --no-startup-id brightnessctl set +10%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 10%-

# windOS wallpaper (feh on X11; swaybg handles Wayland sessions)
exec --no-startup-id sh -c 'command -v feh >/dev/null && feh --bg-fill ${WALLPAPER} || true'

# status bar
bar {
    status_command i3status
    position bottom
    font pango:Cantarell 10
    colors {
        background #1e1e2e
        statusline #cdd6f4
        focused_workspace  #89dceb #89dceb #11111b
        active_workspace   #313244 #313244 #cdd6f4
        inactive_workspace #1e1e2e #1e1e2e #bac2de
    }
}
EOF

cat > "${SKEL}/.config/i3status/config" <<'EOF'
# windOS Zen — minimal i3status for the i3 bar
general {
    colors = true
    interval = 5
}
order += "cpu_usage"
order += "load"
order += "memory"
order += "wireless _first_"
order += "ethernet _first_"
order += "battery all"
order += "tztime local"

cpu_usage { format = "cpu %usage" }
load { format = "load %1min" }
memory { format = "mem %used/%total" }
tztime local { format = "%Y-%m-%d %H:%M" }
battery all { format = "%status %percentage" }
EOF

echo "[windos-tiling] writing sway skeleton..."
cat > "${SKEL}/.config/sway/config" <<EOF
# ===========================================================================
#  windOS Zen — sway skeleton. Mod4 (Super) is the windOS key.
#  Same bindings as the i3 skeleton, Wayland-native wallpaper + terminal.
# ===========================================================================
set \$mod Mod4

# terminal + launcher
bindsym \$mod+Return exec foot
bindsym \$mod+t exec foot
bindsym \$mod+d exec rofi -show drun -show-icons
bindsym \$mod+r exec rofi -show run
bindsym \$mod+w exec firefox-esr

# window management
bindsym \$mod+q kill
bindsym \$mod+f fullscreen toggle
bindsym \$mod+m floating toggle
bindsym \$mod+Tab focus right
bindsym \$mod+Shift+Tab focus left
bindsym \$mod+h split h
bindsym \$mod+v split v
bindsym \$mod+space focus mode_toggle

# workspaces 1..4 (+ move)
bindsym \$mod+1 workspace number 1
bindsym \$mod+2 workspace number 2
bindsym \$mod+3 workspace number 3
bindsym \$mod+4 workspace number 4
bindsym \$mod+Shift+1 move container to workspace number 1
bindsym \$mod+Shift+2 move container to workspace number 2
bindsym \$mod+Shift+3 move container to workspace number 3
bindsym \$mod+Shift+4 move container to workspace number 4

# session
bindsym \$mod+l exec loginctl lock-session
bindsym \$mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'

# media keys
bindsym XF86AudioRaiseVolume exec amixer -q sset Master 5%+ unmute
bindsym XF86AudioLowerVolume exec amixer -q sset Master 5%- unmute
bindsym XF86AudioMute exec amixer -q sset Master toggle
bindsym XF86MonBrightnessUp exec brightnessctl set +10%
bindsym XF86MonBrightnessDown exec brightnessctl set 10%-

# windOS wallpaper on every output
output * bg ${WALLPAPER} fill
exec swaybg -i ${WALLPAPER} -m fill

# terminal colours: cyan accent on dark
output * scale_filter smart

bar {
    status_command i3status
    position bottom
    font pango:Cantarell 10
    colors {
        background #1e1e2e
        statusline #cdd6f4
        focused_workspace  #89dceb #89dceb #11111b
        active_workspace   #313244 #313244 #cdd6f4
        inactive_workspace #1e1e2e #1e1e2e #bac2de
    }
}
EOF

echo "[windos-tiling] writing labwc skeleton..."
cat > "${SKEL}/.config/labwc/rc.xml" <<'EOF'
<?xml version="1.0"?>
<!-- windOS Zen — minimal labwc config. Mod4 (Super) is the windOS key. -->
<labwc_config>
  <theme>
    <name>Arc-Dark</name>
    <icon> Papirus-Dark </icon>
    <font place="ActiveWindow">
      <name>Cantarell</name>
      <size>10</size>
    </font>
    <font place="InactiveWindow">
      <name>Cantarell</name>
      <size>10</size>
    </font>
  </theme>
  <keyboard>
    <keybind key="W-Return">
      <action name="Execute"><command>foot</command></action>
    </keybind>
    <keybind key="W-t">
      <action name="Execute"><command>foot</command></action>
    </keybind>
    <keybind key="W-d">
      <action name="Execute"><command>rofi -show drun -show-icons</command></action>
    </keybind>
    <keybind key="W-r">
      <action name="Execute"><command>rofi -show run</command></action>
    </keybind>
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
    <keybind key="W-Tab">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="W-1">
      <action name="GoToDesktop"><to>1</to></action>
    </keybind>
    <keybind key="W-2">
      <action name="GoToDesktop"><to>2</to></action>
    </keybind>
    <keybind key="W-l">
      <action name="Execute"><command>loginctl lock-session</command></action>
    </keybind>
  </keyboard>
</labwc_config>
EOF

cat > "${SKEL}/.config/labwc/autostart" <<EOF
# windOS Zen — labwc autostart: paint the shared wallpaper, then idle.
swaybg -i ${WALLPAPER} -m fill &
EOF
chmod 755 "${SKEL}/.config/labwc/autostart"

echo "[windos-tiling] done. Wallpaper shared: ${WALLPAPER}"
