# FAQ

## Is it Debian?

Yes. windOS Zen is built from **Debian 13 "Trixie"** with live-build, uses
the Debian archive and `apt`, and identifies as Debian (`ID=debian` in
`/etc/os-release`). Almost every Debian guide and package applies
unchanged.

## Does it replace GRUB?

No. windOS Boot only **adds** a boot entry, placed first in the boot
order. Your existing GRUB (or other bootloaders) stay untouched behind it
as fallback.

## Does Secure Boot work?

Not out of the box — turn Secure Boot **off**, or enroll your own keys
and sign the binaries yourself.

## Is there a 32-bit version?

No. Only **64-bit (amd64)** is built and supported.

## How light is it, really?

The live GNOME session idles around **1 GB**. An installed **Fluxbox**
edition idles **under 200 MB**; LXQt ~220 MB, XFCE ~350 MB, KDE ~600 MB,
GNOME ~900 MB (see [Installing](install.md) for the full table).

## Where's the source?

In this repository — including the `live-build/` tree that builds the
ISO — plus the upstream
[MiniBoot](https://github.com/winmastt/miniboot) project that windOS Boot
is ported from.
