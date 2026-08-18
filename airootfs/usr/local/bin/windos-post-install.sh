#!/usr/bin/env bash
#
# windos-post-install.sh — final optimization pass (Module 6)
# Runs once on first boot of an installed windOS Zen system.
# Safe to re-run.
#
set -e

echo "==> windOS Zen: applying post-install optimizations"

# --- 1. Virtual memory ----------------------------------------------------
# sysctl values are shipped via /etc/sysctl.d/99-windos.conf; just reload.
sysctl --system >/dev/null 2>&1 || true

# --- 2. ZRAM (zram-generator; formerly systemd-zram-generator) -----------
# Config lives in /etc/systemd/zram-generator.conf; enable its generator.
if command -v systemctl >/dev/null; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    for u in systemd-zram-generator.service zram-generator.service; do
        systemctl enable "$u" 2>/dev/null && break
    done
fi

# --- 3. Disable unneeded daemons -----------------------------------------
for svc in bluetooth.service cups.service cups.socket avahi-daemon.service \
           snapd.service lvm2-monitor.service ModemManager.service; do
    systemctl disable "$svc" 2>/dev/null || true
done

# --- 4. SSD trim ----------------------------------------------------------
systemctl enable fstrim.timer 2>/dev/null || true

# --- 5. Early OOM for very low-RAM machines ------------------------------
if command -v earlyoom >/dev/null; then
    systemctl enable earlyoom.service 2>/dev/null || true
fi

# --- 6. Default shell = zsh for any newly created users ------------------
if command -v zsh >/dev/null && grep -qx '/bin/zsh' /etc/shells; then
    useradd -D --shell /bin/zsh 2>/dev/null || true
fi

# --- 7. Welcome fetch on login (already in /etc/skel/.zshrc) -------------
# Place a one-line MOTD noting the distro.
echo "Welcome to windOS Zen — Lighter Than Air." > /etc/motd

# --- 8. Mark done ---------------------------------------------------------
touch /var/lib/windos-post-install.done
echo "==> windOS Zen: post-install optimizations applied"
