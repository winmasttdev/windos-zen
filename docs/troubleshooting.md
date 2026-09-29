# Troubleshooting

## Installer won't start

- Wait 30 seconds after the desktop appears — the installer needs the
  live session to finish settling.
- Try launching it from the terminal to see the error:
  `sudo calamares`. A missing window usually means a broken download —
  re-check the ISO checksum and re-flash the stick.
- On very old GPUs, boot with basic graphics (nomodeset via the boot
  menu) and retry.

## No boot splash

If you get text instead of the Plymouth splash, graphics drivers probably
haven't loaded yet at splash time. The system still boots normally. On
NVIDIA, installing the proprietary driver usually restores the graphical
splash.

## Adwaita instead of the windOS theme

If GNOME falls back to stock Adwaita, the windOS dconf profile didn't
apply. Re-apply it:

```sh
dconf update
```

then log out and back in. If it persists, check that the profile file
exists under `/etc/dconf/db/local.d/` and that no extension is
overriding the theme.

## Login loop (typed right password, back to login)

- You may be logging in as the wrong user — the live user (`live`) only
  exists on the ISO, not on your installed system. Use the username you
  created in the installer.
- A full home partition or disk also causes loops: switch to a console
  (Ctrl+Alt+F3), log in, and check with `df -h`.

## Slow USB writes

`dd` to cheap sticks can take 10+ minutes with no visible progress — use
`status=progress` and be patient. Ventoy sticks with a nearly-full drive
also write slowly. Verify the ISO checksum before assuming the stick is
broken.

## Secure Boot

windOS Boot is **not** signed with Microsoft keys, so Secure Boot must be
**off** (or enroll your own keys and sign the binaries yourself). Symptoms
of Secure Boot interference: the windOS Boot entry silently skipped, or a
red "Secure Boot violation" screen. Disable it in your firmware settings.

## EFI vs Legacy

- If the stick doesn't appear in the boot menu, try the other mode:
  enable CSM/Legacy or UEFI explicitly in firmware settings.
- Systems installed in UEFI mode need an EFI system partition and won't
  boot if you later switch the firmware to Legacy-only, and vice versa.
  Pick one mode and keep it for install and every boot after.
