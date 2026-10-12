#!/usr/bin/env bash
# ===========================================================================
#  windOS Zen — DE dispatcher (Module 4)
#  modules/04-calamares/windos-de-setup.sh
#
#  Runs IN THE INSTALLED TARGET as root via shellprocess@windos-de (after
#  netinstall, before luksbootkeyfile/umount). Reads the packagechooser@de
#  selection, installs the edition's package list via apt-get, then runs the
#  matching per-edition post-install script:
#    fluxbox -> 03-fluxbox/install-fluxbox-edition.sh (+ packages-fluxbox.list)
#    gnome   -> 05-gnome/install-gnome-edition.sh     (+ packages-gnome.list)
#               (falls back to install-gnome-extras.sh if install-gnome-
#               edition.sh is not staged yet)
#    xfce/kde/lxqt/tiling -> 05-gnome/install-<id>-edition.sh
#                            (+ packages-<id>.list)
#
#  Edition discovery order (first valid value wins):
#    1. CLI arg:  windos-de-setup.sh [edition]
#    2. Env:      WINDOS_EDITION=<id>  (shellprocess-de.conf feeds this from
#       Calamares GlobalStorage via environment: ["WINDOS_EDITION=
#       '${gs[packagechooser_de]}'"]; empty/unset is ignored, invalid values
#       are logged and skipped)
#    3. State file: /etc/windos-edition (single word; written by a
#       live-session hook or manual runs: `echo xfce > /etc/windos-edition`)
#    4. Written state in /etc/calamares/packagechooser-de.conf: a line such
#       as `selected: gnome`, `selected_edition=xfce` or
#       `# WINDOS_SELECTED_EDITION=kde` in the in-target copy. (The pristine
#       chooser config carries no such marker, so it simply falls through.)
#    5. Default: gnome
#  Only an invalid CLI arg is fatal (exit 2); invalid env/file values fall
#  through with a warning so a plumbing glitch can never abort an install.
#
#  Staging (live-build): this script -> /usr/local/bin/windos-de-setup.sh in
#  the target; per-edition install-*-edition.sh + packages-*.list ->
#  /usr/local/share/windos/. Extra lookup dirs below cover manual runs.
#
#  Idempotent: per-edition stamp /var/lib/windos/de-setup.<id>.done
#  short-circuits re-runs (override with WINDOS_FORCE=1); apt-get install is
#  itself naturally idempotent. Logs to /var/log/windos-de-setup.log.
#  Per-edition scripts run in-target with / as root; invoke with no args.
# ===========================================================================
set -euo pipefail

VALID_EDITIONS="fluxbox gnome xfce kde lxqt tiling"
DEFAULT_EDITION="gnome"
LOG_FILE="${WINDOS_LOG:-/var/log/windos-de-setup.log}"
STATE_FILE="${WINDOS_STATE_FILE:-/etc/windos-edition}"
CHOOSER_STATE="${WINDOS_CHOOSER_STATE:-/etc/calamares/packagechooser-de.conf}"
STAMP_DIR="${WINDOS_STAMP_DIR:-/var/lib/windos}"

if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/tmp/windos-de-setup.log"
fi
exec > >(tee -a "$LOG_FILE") 2>&1 || true

log() { printf '[windos-de-setup] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'; }

is_valid() {
    case " $VALID_EDITIONS " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Print the single-word state file value, or nothing.
read_state_file() {
    [ -r "$STATE_FILE" ] || return 0
    head -n 1 "$STATE_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]"'"'"';' || true
}

# Print the selection marker from the in-target chooser copy, or nothing.
# Accepts (case-insensitive): selected[:=]<id>, selected_edition[:=]<id>,
# windos[_-][selected[_-]edition|edition][:=]<id>, optionally '#'/'-' prefixed.
# Lines like `packages: [ windos-edition-gnome ]` or `select: single` do NOT
# match: the key must start the line.
read_chooser_state() {
    [ -r "$CHOOSER_STATE" ] || return 0
    grep -Ei '^[[:space:]#*-]*(selected([_-]?edition)?|windos([_-]?(selected([_-]?edition)?|edition)))[[:space:]]*[:=]' \
        "$CHOOSER_STATE" 2>/dev/null \
        | tail -n 1 \
        | sed -E 's/.*[:=][[:space:]]*"?([^"[:space:]#;]+).*/\1/' \
        | tr '[:upper:]' '[:lower:]' \
        | tr -d '[:space:]' || true
}

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SEARCH_DIRS=("$SELF_DIR" /usr/local/share/windos /usr/share/windos /opt/windos /root/windos .)

find_asset() {
    local name="$1" d
    for d in "${SEARCH_DIRS[@]}"; do
        if [ -f "$d/$name" ]; then printf '%s' "$d/$name"; return 0; fi
    done
    return 1
}

log "starting (args: $*)"

EDITION=""
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
    EDITION="$(norm "$1")"
    if ! is_valid "$EDITION"; then
        printf 'Usage: %s [edition]\n  edition: %s (default: %s)\n' "$0" "$VALID_EDITIONS" "$DEFAULT_EDITION" >&2
        log "ERROR: invalid edition '$1'"
        exit 2
    fi
    log "edition '$EDITION' from argv"
fi

if [ -z "$EDITION" ] && [ -n "${WINDOS_EDITION:-}" ]; then
    CAND="$(norm "$WINDOS_EDITION")"
    if is_valid "$CAND"; then
        EDITION="$CAND"; log "edition '$EDITION' from WINDOS_EDITION"
    else
        log "WARN: ignoring invalid WINDOS_EDITION='${WINDOS_EDITION}'"
    fi
fi

if [ -z "$EDITION" ]; then
    CAND="$(read_state_file)"
    if [ -n "$CAND" ]; then
        if is_valid "$CAND"; then
            EDITION="$CAND"; log "edition '$EDITION' from $STATE_FILE"
        else
            log "WARN: ignoring invalid value '$CAND' in $STATE_FILE"
        fi
    fi
fi

if [ -z "$EDITION" ]; then
    CAND="$(read_chooser_state)"
    if [ -n "$CAND" ]; then
        if is_valid "$CAND"; then
            EDITION="$CAND"; log "edition '$EDITION' from $CHOOSER_STATE"
        else
            log "WARN: ignoring invalid marker '$CAND' in $CHOOSER_STATE"
        fi
    fi
fi

if [ -z "$EDITION" ]; then
    EDITION="$DEFAULT_EDITION"
    log "no selection found; defaulting to '$EDITION'"
fi

STAMP="$STAMP_DIR/de-setup.$EDITION.done"
if [ -f "$STAMP" ] && [ -z "${WINDOS_FORCE:-}" ]; then
    log "stamp $STAMP exists; already applied, skipping"
    exit 0
fi

case "$EDITION" in
    fluxbox) CAND_SCRIPTS="install-fluxbox-edition.sh" ;;
    gnome)   CAND_SCRIPTS="install-gnome-edition.sh install-gnome-extras.sh" ;;
    *)       CAND_SCRIPTS="install-${EDITION}-edition.sh" ;;
esac

SCRIPT=""
for s in $CAND_SCRIPTS; do
    if SCRIPT="$(find_asset "$s")"; then break; else SCRIPT=""; fi
done
[ -n "$SCRIPT" ] || die "no post-install script staged for edition '$EDITION' (looked for: $CAND_SCRIPTS in ${SEARCH_DIRS[*]})"
log "post-install script: $SCRIPT"

LIST="$(find_asset "packages-${EDITION}.list" || true)"
if [ -n "$LIST" ]; then
    log "package list: $LIST"
else
    log "WARN: packages-${EDITION}.list not staged; skipping apt step"
fi

if [ -n "$LIST" ]; then
    PKGS="$(grep -vE '^[[:space:]]*(#|$)' "$LIST" | tr '\n' ' ' || true)"
    PKGS="$(printf '%s' "$PKGS" | tr -s ' ' | sed -e 's/^ *//;s/ *$//')"
    if [ -n "$PKGS" ]; then
        [ "$(id -u)" -eq 0 ] || die "apt-get install requires root"
        export DEBIAN_FRONTEND=noninteractive
        log "apt-get update..."
        apt-get update || log "WARN: apt-get update failed; trying install with cached indexes"
        log "apt-get install -y $PKGS"
        # shellcheck disable=SC2086
        apt-get install -y $PKGS
    else
        log "package list empty after filtering; skipping apt step"
    fi
fi

log "running $SCRIPT..."
bash "$SCRIPT"
log "post-install script finished"

mkdir -p "$STAMP_DIR"
printf '%s edition=%s script=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$EDITION" "$SCRIPT" > "$STAMP"
log "done (stamp: $STAMP)"
