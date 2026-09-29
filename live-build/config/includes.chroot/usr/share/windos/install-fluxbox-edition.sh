#!/usr/bin/env bash
# ===========================================================================
#  windOS Zen — Fluxbox edition post-install (Module 3)
#  Runs as root inside the installed target (Calamares shellprocess/chroot).
#  Installs the Fluxbox session packages, deploys the skel dotfiles to
#  /etc/skel (filling them into already-created users without clobbering),
#  installs the windos-zen style system-wide, and makes fluxbox the default
#  GDM/X session. Idempotent: safe to run twice.
#  windos-zram + sysctl are owned by module 06 — NOT touched here.
# ===========================================================================
set -euo pipefail

TARGET="${1:-/}"
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKEL_SRC="$MODULE_DIR/skel"
STYLE_SRC="$MODULE_DIR/styles/windos-zen"
PKG_LIST="$MODULE_DIR/packages-fluxbox.list"

log() { echo "[windos-fluxbox] $*"; }

# Run a command inside the target (plain exec when TARGET=/, else chroot).
in_target() {
    if [ "$TARGET" = "/" ]; then
        "$@"
    else
        chroot "$TARGET" "$@"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: must run as root" >&2
    exit 1
fi
[ -d "$SKEL_SRC" ] || { log "ERROR: skel source missing: $SKEL_SRC" >&2; exit 1; }
[ -f "$STYLE_SRC/theme.cfg" ] || { log "ERROR: style missing: $STYLE_SRC/theme.cfg" >&2; exit 1; }

# --- 1. packages -----------------------------------------------------------
if [ -f "$PKG_LIST" ]; then
    mapfile -t PKGS < <(grep -vE '^[[:space:]]*(#|$)' "$PKG_LIST" | awk '{print $1}')
    if [ "${#PKGS[@]}" -gt 0 ]; then
        log "installing ${#PKGS[@]} packages..."
        in_target env DEBIAN_FRONTEND=noninteractive apt-get update
        in_target env DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
    fi
else
    log "WARNING: package list not found ($PKG_LIST), skipping apt"
fi

# --- 2. skel -> /etc/skel --------------------------------------------------
log "deploying skel to $TARGET/etc/skel..."
mkdir -p "$TARGET/etc/skel"
cp -Rf "$SKEL_SRC/." "$TARGET/etc/skel/"
# init points at ~/.fluxbox/styles/windos-zen/theme.cfg, which is not part of
# the skel tree, so plant it there for every new user...
mkdir -p "$TARGET/etc/skel/.fluxbox/styles/windos-zen"
cp -f "$STYLE_SRC/theme.cfg" "$TARGET/etc/skel/.fluxbox/styles/windos-zen/theme.cfg"
# ...and mark fluxbox as the default session for GDM (reads ~/.dmrc).
printf '[Desktop]\nSession=fluxbox\n' > "$TARGET/etc/skel/.dmrc"
chmod 644 "$TARGET/etc/skel/.dmrc"
chmod 755 "$TARGET/etc/skel/.fluxbox/startup" "$TARGET/etc/skel/.xsession"
# Trixie has no neofetch (replaced by fastfetch) — fix the deployed copy only,
# the skel source stays pristine for the live ISO.
if grep -q 'neofetch' "$TARGET/etc/skel/.fluxbox/menu" 2>/dev/null; then
    sed -i 's/neofetch/fastfetch/g' "$TARGET/etc/skel/.fluxbox/menu"
fi
chown -R root:root "$TARGET/etc/skel"
log "skel deployed."

# --- 3. system-wide fluxbox style ------------------------------------------
# /etc/skel covers new users, but the style must also be visible to existing
# accounts and the root-menu fallback: install it where fluxbox looks first.
STYLE_DST="$TARGET/usr/share/fluxbox/styles/windos-zen"
log "installing system style to $STYLE_DST..."
mkdir -p "$STYLE_DST"
cp -f "$STYLE_SRC/theme.cfg" "$STYLE_DST/theme.cfg"
chmod 644 "$STYLE_DST/theme.cfg"
chown -R root:root "$STYLE_DST"
log "system style installed."

# --- 4. already-created users: fill, never overwrite -----------------------
# If Calamares created the user before this hook ran, /etc/skel did not apply.
# Copy each windos-managed dotfile only when the user has no version of it.
while IFS=: read -r user _ uid gid _ home shell; do
    case "$uid" in ''|*[!0-9]*) continue ;; esac
    [ "$uid" -ge 1000 ] || continue
    case "${shell:-}" in *nologin|*false) continue ;; esac
    thome="$TARGET$home"
    [ -d "$thome" ] || continue
    log "filling dotfiles for $user ($home)..."
    for dot in .fluxbox .xsession .dmrc; do
        if [ ! -e "$thome/$dot" ] && [ -e "$TARGET/etc/skel/$dot" ]; then
            cp -R "$TARGET/etc/skel/$dot" "$thome/$dot"
        fi
    done
    for cfg in picom conky nitrogen; do
        if [ ! -e "$thome/.config/$cfg" ] && [ -e "$TARGET/etc/skel/.config/$cfg" ]; then
            mkdir -p "$thome/.config"
            cp -R "$TARGET/etc/skel/.config/$cfg" "$thome/.config/$cfg"
        fi
    done
    if [ ! -e "$thome/.fluxbox/styles/windos-zen/theme.cfg" ]; then
        mkdir -p "$thome/.fluxbox/styles/windos-zen"
        cp -f "$STYLE_SRC/theme.cfg" "$thome/.fluxbox/styles/windos-zen/theme.cfg"
    fi
    if grep -q 'neofetch' "$thome/.fluxbox/menu" 2>/dev/null; then
        sed -i 's/neofetch/fastfetch/g' "$thome/.fluxbox/menu"
    fi
    chown -R "$uid:$gid" "$thome/.fluxbox" "$thome/.xsession" "$thome/.dmrc" \
        "$thome/.config/picom" "$thome/.config/conky" "$thome/.config/nitrogen" 2>/dev/null || true
done < "$TARGET/etc/passwd"

# --- 5. default session ----------------------------------------------------
# The fluxbox package ships /usr/share/xsessions/fluxbox.desktop; point the
# Debian x-session-manager alternative at it so GDM/startx land in fluxbox.
if ! in_target test -f /usr/share/xsessions/fluxbox.desktop; then
    log "WARNING: /usr/share/xsessions/fluxbox.desktop missing — fluxbox package may have failed"
fi
if in_target test -x /usr/bin/startfluxbox; then
    in_target update-alternatives --set x-session-manager /usr/bin/startfluxbox 2>/dev/null \
        || in_target update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/bin/startfluxbox 50 2>/dev/null \
        || true
    log "default x-session-manager -> startfluxbox"
else
    log "WARNING: /usr/bin/startfluxbox missing, skipping update-alternatives"
fi

log "done."
