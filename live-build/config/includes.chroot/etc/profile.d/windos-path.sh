# windOS Zen — sbin on PATH for the live user (swapon, modprobe, fdisk…)
# Debian keeps /usr/sbin out of non-root PATH; our live session is hands-on.
if ! echo "$PATH" | grep -q "/usr/sbin"; then
    export PATH="$PATH:/usr/sbin:/sbin"
fi
