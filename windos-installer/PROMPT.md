# windOS Zen — native installer design brief

This file is the prompt handed to a large code-generation model to build the
native Python + PySide6 installer that replaces Calamares. Kept here so the work
is reproducible.

---

**PROMPT — Build `windOS Zen` native OS installer (Python + PySide6)**

You are to implement a complete, production-quality **native GUI installer** for
the `windOS Zen` Linux distribution. It must replace Calamares. Do NOT use a web
browser / Electron / webview — it must be a real native Qt (PySide6) desktop
application so it is fast and has zero browser lag.

### Project context
- `windOS Zen` is an Arch Linux derivative built with `archiso`. The live ISO
  boots to an XFCE desktop and runs the installer.
- At install time the live system has the target root filesystem squashfs
  mounted at `/run/archiso/bootmnt/arch/x86_64/airootfs.sfs`.
- **Branding reference:** The official project site is
  **https://windos.nn1kk00.ru/** — fetch it and use it as the authoritative
  reference for the windOS visual identity (logo, color palette, typography,
  tone, taglines, mascot). The installer's theme, titles, and copy must
  visually match that site.

### Host / target system environment (verified)
- OS: Arch Linux x86_64, kernel `7.1.6-zen1-1-zen`.
- Required CLI tools are ALL present: `parted`, `grub-install` (GRUB 2),
  `unsquashfs` (squashfs-tools), `arch-chroot` + `genfstab`
  (arch-install-scripts), `mkinitcpio`, `pacstrap`.
- Python **3.14.6** with **PySide6 6.11.1** already installed — use that.
  Not PyQt, not PyQt5.
- Target firmware is **UEFI** (`/sys/firmware/efi` present). Installer must
  install UEFI GRUB via `--target=x86_64-efi --efi-directory=/boot/efi
  --bootloader-id=windOS_Zen`. (BIOS is a secondary/optional path.)
- Live ISO volume label is `WINDOS_ZEN`.

### Application flow (wizard, pages in order)
1. **Welcome** — branded title + subtitle (matching windos.nn1kk00.ru style),
   and a prominent **"Dry-run (simulate only — writes nothing)"** checkbox,
   checked by default.
2. **Disk selection** — list real disks via
   `lsblk -d -n -o NAME,SIZE,TYPE --exclude 7` (filter `TYPE=="disk"`).
   User picks one target disk. Show a clear warning that this disk will be erased.
3. **User** — inputs for hostname, username, password.
4. **Summary** — read-only recap of disk / host / user / mode
   (DRY-RUN vs REAL INSTALL).
5. **Progress** — a `QProgressBar` + a scrolling log `QTextEdit`.
   Installation runs in a `QThread` (never block the UI).
6. **Finish** — success/failure dialog; offer reboot (only in real mode).

Navigation: a fixed bottom bar with Back / Next (Next becomes "Install" on the
Summary page, then disabled during install).

### Backend — exact operations (implement each as a method; all commands logged to the UI)
Target disk = chosen device (e.g. `/dev/sda` or `/dev/nvme0n1`). Derive
partitions safely:
- if device ends with a digit use `p` suffix (nvme), else none (sda).
  `esp = dev+"1"`, `root = dev+"2"`.
- `parted -s <dev> mklabel gpt`
- `parted -s <dev> mkpart ESP fat32 1MiB 513MiB`
- `parted -s <dev> set 1 esp on`
- `parted -s <dev> mkpart primary ext4 513MiB 100%`
- `mkfs.fat -F32 <esp>` ; `mkfs.ext4 -F <root>`
- `mount <root> /mnt` ; `mkdir -p /mnt/boot/efi` ; `mount <esp> /mnt/boot/efi`
- `unsquashfs -f -d /mnt <squashfs>` (path `/run/archiso/bootmnt/arch/x86_64/airootfs.sfs`)
- `genfstab -U /mnt > /mnt/etc/fstab`
- configure inside `arch-chroot /mnt`:
  - write `/etc/hostname`
  - `useradd -m -G wheel,storage,optical,network,video,audio,power,autologin -s /bin/bash <user>`
  - set passwords for root and user (`chpasswd`)
  - `mkinitcpio -P`
  - `systemctl enable lightdm NetworkManager`
- bootloader: `grub-install --target=x86_64-efi --efi-directory=/boot/efi
  --bootloader-id=windOS_Zen` then `grub-mkconfig -o /boot/grub/grub.cfg`
- `umount -R /mnt`

### Safety — Dry-run mode (critical)
When Dry-run is enabled, **every** backend step must ONLY print the exact
command it would run (e.g. `$ parted -s /dev/sda mklabel gpt`) and return
success — never execute, never touch disks. This makes the whole app safe to
open on a real machine for preview. Real execution only happens when the
checkbox is unchecked.

### Branding / theme
- Match the visual identity of **https://windos.nn1kk00.ru/** (fetch it for
  logo, palette, typography, tone). Keep the "Lighter Than Air" / zen feeling.
- Apply a dark Qt stylesheet consistent with that site (deep navy background,
  indigo accent, rounded cards, soft buttons). Title text: **windOS Zen**.
- Use a `QLabel` title + subtitle (load the site's logo if a local asset is
  provided; otherwise render the styled title).

### Code structure (suggested)
```
windos-installer/
  main.py            # QApplication, MainWindow, page wiring, nav
  ui/
    pages.py         # WelcomePage, DiskPage, UserPage, SummaryPage, ProgressPage
    theme.py         # CSS string (matched to windos.nn1kk00.ru)
  backend/
    installer.py     # Installer class (partition/mount/unpack/fstab/configure/bootloader/finish)
    worker.py        # QThread wrapper emitting log/progress/finished signals
  requirements.txt   # PySide6
```
Make `main.py` executable and runnable with `python -m windos-installer` or directly.

### Acceptance criteria
- Runs with `python main.py` (no errors). Shows all 6 pages with working Back/Next.
- In Dry-run mode it walks the whole flow and prints the exact commands, touching nothing.
- In Real mode (only when explicitly unchecked) it performs a genuine install to
  the chosen disk using the exact commands above.
- UI never freezes during install (work is off the GUI thread).
- Visual style matches https://windos.nn1kk00.ru/.
- Code is clean, typed where reasonable, and commented for the non-obvious shell commands.

Implement the full thing now, returning the complete file contents.
