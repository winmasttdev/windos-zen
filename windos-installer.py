#!/usr/bin/env python3
"""windOS Zen installer — minimal native (PySide6) OS installer.

Drives the same tools Calamares uses (parted, unsquashfs, genfstab,
arch-chroot, grub) but behind a small, fast Qt UI. Dry-run mode (default)
only logs the commands it would run, so it is safe to open on a real machine.
"""
import os
import sys
import shlex
import subprocess

from PySide6.QtCore import Qt, QThread, Signal, QObject
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QFrame, QHBoxLayout, QLabel,
    QLineEdit, QListWidget, QMainWindow, QMessageBox, QProgressBar,
    QPushButton, QSizePolicy, QSpacerItem, QStackedWidget, QTextEdit,
    QVBoxLayout, QWidget,
)

SQUASHFS = "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
BRAND = "windOS Zen"
ACCENT = "#5b6bff"

CSS = f"""
QWidget {{
    color: #d7e0f4;
    background-color: #0b0f1a;
    font-family: "Noto Sans", "DejaVu Sans", sans-serif;
    font-size: 11pt;
}}
QLabel#title {{ color: #ffffff; font-size: 22pt; font-weight: bold; }}
QLabel#sub {{ color: #8a93a8; font-size: 11pt; }}
QFrame#card {{
    background-color: #111726;
    border: 1px solid #232b3d;
    border-radius: 12px;
}}
QPushButton {{
    background-color: #161d31; color: #d7e0f4;
    border: 1px solid #2b3550; border-radius: 8px;
    padding: 9px 16px;
}}
QPushButton:hover {{ background-color: {ACCENT}; color: #fff; border-color: #5b6bff; }}
QPushButton:disabled {{ background-color: #11162a; color: #4a5572; }}
QPushButton#primary {{ background-color: {ACCENT}; color: #fff; font-weight: bold; }}
QComboBox, QLineEdit, QListWidget {{
    background-color: #070b16; color: #d7e0f4;
    border: 1px solid #2b3550; border-radius: 6px; padding: 6px;
}}
QListWidget::item:selected {{ background-color: {ACCENT}; color: #fff; }}
QProgressBar {{
    background-color: #070b16; border: 1px solid #232b3d;
    border-radius: 6px; text-align: center; color: #b9c2ff; height: 16px;
}}
QProgressBar::chunk {{
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #5b6bff,stop:1 #8b8cff);
    border-radius: 5px;
}}
QTextEdit {{ background-color: #070b16; border: 1px solid #232b3d; border-radius: 8px; }}
"""


def list_disks():
    """Return block devices that look like real disks (not partitions)."""
    try:
        out = subprocess.run(
            ["lsblk", "-d", "-n", "-o", "NAME,SIZE,TYPE", "--exclude", "7"],
            capture_output=True, text=True,
        ).stdout
    except FileNotFoundError:
        return []
    disks = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == "disk":
            disks.append(f"/dev/{parts[0]}  ({parts[1]})")
    return disks


class Installer(QObject):
    log = Signal(str)
    progress = Signal(int)
    finished = Signal(bool, str)

    def __init__(self, target, hostname, username, password, dry_run):
        super().__init__()
        self.target = target
        self.hostname = hostname
        self.username = username
        self.password = password
        self.dry_run = dry_run

    # ----- command runner -----
    def _run(self, cmd, chroot=None, check=True):
        if isinstance(cmd, str):
            cmd = shlex.split(cmd)
        label = " ".join(shlex.quote(c) for c in cmd)
        if chroot:
            label = f"[chroot {chroot}] {label}"
        self.log.emit(f"$ {label}")
        if self.dry_run:
            self.log.emit("   (dry-run — skipped)")
            return 0
        if chroot:
            full = ["arch-chroot", chroot] + cmd
        else:
            full = cmd
        try:
            r = subprocess.run(full, capture_output=True, text=True)
        except Exception as e:  # noqa: BLE001
            self.log.emit(f"   ERROR: {e}")
            if check:
                raise
            return 1
        if r.stdout:
            self.log.emit(r.stdout.strip())
        if r.returncode != 0:
            self.log.emit(f"   exited {r.returncode}: {r.stderr.strip()}")
            if check:
                raise RuntimeError(f"{label} failed")
        return r.returncode

    # ----- steps -----
    def partition(self):
        d = self.target
        self._run(f"parted -s {d} mklabel gpt")
        self._run(f"parted -s {d} mkpart ESP fat32 1MiB 513MiB")
        self._run(f"parted -s {d} set 1 esp on")
        self._run(f"parted -s {d} mkpart primary ext4 513MiB 100%")
        # derive partition paths (handles /dev/sda vs /dev/nvme0n1)
        base = d if d[-1].isdigit() else d
        suf = "p" if d[-1].isdigit() else ""
        esp = f"{base}{suf}1"
        root = f"{base}{suf}2"
        self._run(f"mkfs.fat -F32 {esp}")
        self._run(f"mkfs.ext4 -F {root}")
        self.esp, self.root = esp, root

    def mount(self):
        self._run("mount %s /mnt" % self.root)
        self._run("mkdir -p /mnt/boot/efi")
        self._run("mount %s /mnt/boot/efi" % self.esp)

    def unpack(self):
        if not os.path.exists(SQUASHFS):
            raise RuntimeError(f"squashfs not found at {SQUASHFS} (run from live media)")
        self._run(f"unsquashfs -f -d /mnt {SQUASHFS}")

    def fstab(self):
        self._run("genfstab -U /mnt > /mnt/etc/fstab")

    def configure(self):
        c = self.username
        self._run(f"echo {self.hostname} > /mnt/etc/hostname", check=False)
        self._run(f"echo 'root:{self.password}' | chpasswd -R /mnt", check=False)
        self._run(
            f"useradd -m -G wheel,storage,optical,network,video,audio,power,autologin "
            f"-s /bin/bash {c}", check=False)
        self._run(f"echo '{c}:{self.password}' | chroot /mnt chpasswd", check=False)
        self._run("arch-chroot /mnt mkinitcpio -P", check=False)
        self._run("arch-chroot /mnt systemctl enable lightdm NetworkManager", check=False)

    def bootloader(self):
        self._run("arch-chroot /mnt grub-install --target=x86_64-efi "
                  "--efi-directory=/boot/efi --bootloader-id=windOS_Zen", check=False)
        self._run("arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg", check=False)

    def finish(self):
        self._run("umount -R /mnt", check=False)

    def run(self):
        steps = [
            ("Partitioning", self.partition),
            ("Mounting", self.mount),
            ("Unpacking image", self.unpack),
            ("Writing fstab", self.fstab),
            ("Configuring system", self.configure),
            ("Installing bootloader", self.bootloader),
            ("Finalizing", self.finish),
        ]
        try:
            for i, (name, fn) in enumerate(steps, 1):
                self.log.emit(f"== {name} ==")
                fn()
                self.progress.emit(int(100 * i / len(steps)))
            self.finished.emit(True, "Installation complete.")
        except Exception as e:  # noqa: BLE001
            self.log.emit(f"INSTALL FAILED: {e}")
            self.finished.emit(False, str(e))


class Worker(QThread):
    def __init__(self, installer):
        super().__init__()
        self.installer = installer

    def run(self):
        self.installer.run()


class Page(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(40, 32, 40, 32)
        self.layout.setSpacing(16)


class WelcomePage(Page):
    def __init__(self, app):
        super().__init__(app)
        card = QFrame(objectName="card")
        v = QVBoxLayout(card)
        v.setContentsMargins(32, 32, 32, 32)
        v.setSpacing(14)
        t = QLabel(BRAND, objectName="title")
        t.setAlignment(Qt.AlignCenter)
        s = QLabel("Lighter Than Air — native installer", objectName="sub")
        s.setAlignment(Qt.AlignCenter)
        v.addWidget(t)
        v.addWidget(s)
        self.app.dry = QCheckBox("Dry-run (simulate only — safe preview, writes nothing)")
        self.app.dry.setChecked(True)
        self.app.dry.setStyleSheet("padding:6px;")
        v.addItem(QSpacerItem(0, 10, QSizePolicy.Minimum, QSizePolicy.Expanding))
        v.addWidget(self.app.dry)
        self.layout.addWidget(card)


class DiskPage(Page):
    def __init__(self, app):
        super().__init__(app)
        self.list = QListWidget()
        self.list.addItems(list_disks() or ["(no disks found)"])
        self.layout.addWidget(QLabel("Target disk", objectName="title"))
        self.layout.addWidget(self.list)
        self.layout.addItem(QSpacerItem(0, 0, QSizePolicy.Minimum, QSizePolicy.Expanding))


class UserPage(Page):
    def __init__(self, app):
        super().__init__(app)
        self.host = QLineEdit("windos")
        self.user = QLineEdit("user")
        self.pw = QLineEdit("user"); self.pw.setEchoMode(QLineEdit.Password)
        for w, lbl in [(self.host, "Hostname"), (self.user, "Username"), (self.pw, "Password")]:
            self.layout.addWidget(QLabel(lbl))
            self.layout.addWidget(w)
        self.layout.addItem(QSpacerItem(0, 0, QSizePolicy.Minimum, QSizePolicy.Expanding))


class SummaryPage(Page):
    def __init__(self, app):
        super().__init__(app)
        self.txt = QTextEdit()
        self.txt.setReadOnly(True)
        self.layout.addWidget(QLabel("Summary", objectName="title"))
        self.layout.addWidget(self.txt)

    def refresh(self):
        d = self.app.disk()
        self.txt.setText(
            f"Disk:    {d}\n"
            f"Host:    {self.app.host.text()}\n"
            f"User:    {self.app.user.text()}\n"
            f"Mode:    {'DRY-RUN (no changes)' if self.app.dry.isChecked() else 'REAL INSTALL'}"
        )


class ProgressPage(Page):
    def __init__(self, app):
        super().__init__(app)
        self.bar = QProgressBar()
        self.bar.setValue(0)
        self.log = QTextEdit()
        self.log.setReadOnly(True)
        self.layout.addWidget(QLabel("Installing…", objectName="title"))
        self.layout.addWidget(self.bar)
        self.layout.addWidget(self.log, 1)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(BRAND + " Installer")
        self.resize(720, 540)
        self.stack = QStackedWidget()
        self.setCentralWidget(self.stack)

        self.welcome = WelcomePage(self)
        self.disk = DiskPage(self)
        self.user = UserPage(self)
        self.summary = SummaryPage(self)
        self.progress = ProgressPage(self)
        for p in [self.welcome, self.disk, self.user, self.summary, self.progress]:
            self.stack.addWidget(p)

        self.nav = QHBoxLayout()
        self.back = QPushButton("Back"); self.back.setEnabled(False)
        self.next = QPushButton("Next", objectName="primary")
        self.nav.addItem(QSpacerItem(0, 0, QSizePolicy.Expanding, QSizePolicy.Minimum))
        self.nav.addWidget(self.back)
        self.nav.addWidget(self.next)
        wrap = QWidget()
        wrap.setLayout(self.nav)
        self.stack.currentWidget().layout.addWidget(wrap) if False else None
        # place nav at bottom of each page by adding to a container
        self._idx = 0
        self.pages = [self.welcome, self.disk, self.user, self.summary, self.progress]
        self._add_nav(self.welcome); self._add_nav(self.disk)
        self._add_nav(self.user); self._add_nav(self.summary)
        self._add_nav(self.progress)
        self.back.clicked.connect(self.go_back)
        self.next.clicked.connect(self.go_next)
        self.next.setText("Next")

    def _add_nav(self, page):
        page.layout.addWidget(wrap_nav(self))

    def disk(self):
        item = self.disk.list.currentItem()
        return item.text().split()[0] if item else ""

    @property
    def host(self): return self.user.host
    @property
    def user(self): return self.user  # alias used by SummaryPage via app.user

    def go_back(self):
        if self._idx > 0:
            self._idx -= 1
            self.stack.setCurrentIndex(self._idx)
            self.back.setEnabled(self._idx > 0)
            self.next.setText("Next")

    def go_next(self):
        if self._idx < 3:
            if self._idx == 2:
                self.summary.refresh()
            self._idx += 1
            self.stack.setCurrentIndex(self._idx)
            self.back.setEnabled(True)
            if self._idx == 3:
                self.next.setText("Install")
            elif self._idx == 4:
                self.start_install()
        elif self._idx == 3:
            self.start_install()

    def start_install(self):
        self.next.setEnabled(False)
        self.back.setEnabled(False)
        inst = Installer(
            target=self.disk(),
            hostname=self.user.host.text(),
            username=self.user.user.text(),
            password=self.user.pw.text(),
            dry_run=self.welcome.dry.isChecked(),
        )
        inst.log.connect(lambda m: self.progress.log.append(m))
        inst.progress.connect(self.progress.bar.setValue)
        inst.finished.connect(self.on_done)
        self.worker = Worker(inst)
        self.worker.start()
        self.stack.setCurrentIndex(4)

    def on_done(self, ok, msg):
        QMessageBox.information(self, BRAND, msg)
        self.next.setText("Close")
        self.next.setEnabled(True)
        self.next.clicked.disconnect()
        self.next.clicked.connect(self.close)


def wrap_nav(app):
    """Build the bottom nav bar (shared layout, new widget per page)."""
    nav = QHBoxLayout()
    nav.addItem(QSpacerItem(0, 0, QSizePolicy.Expanding, QSizePolicy.Minimum))
    nav.addWidget(app.back)
    nav.addWidget(app.next)
    w = QWidget(); w.setLayout(nav)
    return w


def main():
    app = QApplication(sys.argv)
    app.setStyleSheet(CSS)
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
