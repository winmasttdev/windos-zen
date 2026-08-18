#!/usr/bin/env bash
#
# windOS Zen — chroot customization for the LIVE environment.
# Executed by mkarchiso inside the airootfs during the build.
#
set -e

echo "==> windOS Zen: configuring live environment"

# --- Plymouth default theme (also packed into the initramfs by the
#     plymouth mkinitcpio hook, reading /etc/plymouth/plymouthd.conf). ---
if command -v plymouth-set-default-theme >/dev/null; then
    plymouth-set-default-theme -R windos-zen || true
fi

# --- Accounts -------------------------------------------------------------
groupadd -r autologin 2>/dev/null || true
if ! id liveuser &>/dev/null; then
    useradd -m -G wheel,storage,optical,network,video,audio,power,autologin \
        -s /bin/bash liveuser
fi
echo 'liveuser:liveuser' | chpasswd
echo 'root:root'         | chpasswd

# Passwordless sudo for the live user (convenience; removed on install).
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# --- Hostname / basics ----------------------------------------------------
echo 'windos-zen' > /etc/hostname

# --- Services -------------------------------------------------------------
systemctl enable NetworkManager.service || true
# LightDM (graphical login) — wire it up manually: `systemctl enable` is
# unreliable inside the build chroot, so create the symlinks explicitly.
mkdir -p /etc/systemd/system/display-manager.target.wants
ln -sf /usr/lib/systemd/system/lightdm.service \
       /etc/systemd/system/display-manager.target.wants/lightdm.service 2>/dev/null || true
systemctl enable lightdm.service 2>/dev/null || true
# PipeWire runs as a per-user service (socket-activated); enable it globally
# so every session gets audio without a manual start.
systemctl --global enable pipewire.service pipewire-pulse.service 2>/dev/null || true
# zram-generator (package renamed from systemd-zram-generator) reads
# /etc/systemd/zram-generator.conf (shipped in overlay) and creates the
# swap device at boot via its generator/service.
for u in systemd-zram-generator.service zram-generator.service; do
    systemctl enable "$u" 2>/dev/null && break
done

# --- Rebuild initramfs with all hooks present -----------------------------
# During pacstrap the linux-zen mkinitcpio run can fire before the archiso
# package (which provides the archiso_* hooks) is installed, producing a
# broken initramfs. Rebuilding here guarantees archiso + plymouth hooks land.
if command -v mkinitcpio >/dev/null; then
    echo "==> windOS Zen: rebuilding initramfs"
    mkinitcpio -P || true
fi

# --- Serial console & COM debugging ---------------------------------------
# The kernel cmdline sets console=ttyS0 so early boot + the journal stream
# to the serial line. Enable a getty on ttyS0 so we can log in over the
# serial line (e.g. QEMU -serial telnet) for debugging.
systemctl unmask serial-getty@ttyS0.service 2>/dev/null || true
systemctl enable serial-getty@ttyS0.service 2>/dev/null || true

# --- Default SHELL = zsh (windOS requirement) -----------------------------
if command -v zsh >/dev/null; then
    chsh -s /bin/zsh root     2>/dev/null || true
    chsh -s /bin/zsh liveuser 2>/dev/null || true
    # propagate skel configs to root so the console is consistent
    cp -f /etc/skel/.zshrc /root/.zshrc
    cp -rf /etc/skel/.config  /root/.config
fi

# --- Module 6: disable unneeded daemons on the live image -----------------
for svc in bluetooth.service cups.service avahi-daemon.service \
           snapd.service lvm2-monitor.service; do
    systemctl disable "$svc" 2>/dev/null || true
done
# periodic TRIM for SSDs
systemctl enable fstrim.timer 2>/dev/null || true
# early OOM protection for very low-RAM machines
if command -v earlyoom >/dev/null; then
    systemctl enable earlyoom.service 2>/dev/null || true
fi

# --- Placeholder wallpaper dir (real assets land in Module 3) -------------
mkdir -p /usr/share/backgrounds/windos-zen

# --- Installer: Calamares (built from AUR on the host, injected as a local
#     package because the live chroot has no network during this script) ----
# Use a minimal pacman.conf: the chroot's space check can't resolve the mount
# point under arch-chroot ("could not determine root mount point /"), so
# CheckSpace is disabled; SigLevel=Never because the injected package is
# unsigned and the live chroot has no keyring (mkarchiso uses pacstrap -G).
cat > /tmp/pacman-cal.conf <<'EOF'
[options]
Architecture = auto
SigLevel = Never
EOF
for f in /root/calamares-*.pkg.tar.zst; do
    if [ -e "$f" ]; then
        echo "==> windOS Zen: installing injected Calamares package $(basename "$f")"
        pacman --config /tmp/pacman-cal.conf -U --noconfirm "$f"
        rm -f "$f"
    fi
done

# --- Prevent interactive "Initial Setup" on live boot ----------------------
# The image ships /etc/machine-id as the literal "uninitialized", which makes
# systemd treat every boot as first boot and run systemd-firstboot, prompting
# interactively for timezone/root password (blocking the desktop). Give it a
# real id and mask the service so the live session starts cleanly.
rm -f /etc/machine-id
systemd-machine-id-setup 2>/dev/null || \
    echo "$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')" > /etc/machine-id
systemctl mask systemd-firstboot.service 2>/dev/null || true

# --- Initialize the pacman keyring ---------------------------------------
# archiso normally does this at first boot via pacman-init.service, but we
# set a fixed machine-id (to suppress the interactive firstboot prompt),
# which disables first-boot-conditioned services. Without an initialized
# keyring, `pacman` (and Calamares' netinstall) fails signature checks.
if command -v pacman-key >/dev/null; then
    pacman-key --init 2>/dev/null || true
    pacman-key --populate archlinux 2>/dev/null || true
fi

# --- Live autologin to XFCE ------------------------------------------------
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/autologin.conf <<'EOF'
[Seat:*]
autologin-user=liveuser
autologin-session=xfce
EOF

# --- Boot to the graphical target so LightDM (and the Fluxbox desktop)
#     actually starts instead of dropping to a multi-user text console.
#     Create the symlink explicitly (set-default can be flaky in chroot).
ln -sf /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

echo "==> windOS Zen: live environment configured"
