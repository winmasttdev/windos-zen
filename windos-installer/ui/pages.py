"""Page widgets for the windOS Zen installer wizard."""
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFrame,
    QLineEdit, QComboBox, QTextEdit, QProgressBar, QSpacerItem,
    QSizePolicy, QRadioButton, QButtonGroup,
)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QPixmap

from ui.icons import (
    icon_windos, icon_disk, icon_user, icon_summary,
    icon_install, icon_check, icon_warn,
)
from backend.installer import InstallerConfig, list_system_disks


class _Card(QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("Card")
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(26, 24, 26, 24)
        self._layout.setSpacing(14)


def _title(subtitle: str) -> QVBoxLayout:
    box = QVBoxLayout()
    t = QLabel("windOS Zen")
    t.setObjectName("PageTitle")
    s = QLabel(subtitle)
    s.setObjectName("PageSub")
    box.addWidget(t)
    box.addWidget(s)
    return box


class WelcomePage(QWidget):
    dry_run_changed = Signal(bool)

    def __init__(self):
        super().__init__()
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(20)

        title_row = QHBoxLayout()
        logo = QLabel()
        logo.setPixmap(icon_windos(54).pixmap(54, 54))
        title_row.addWidget(logo)
        title_col = QVBoxLayout()
        h = QLabel("Install windOS Zen")
        h.setObjectName("PageTitle")
        p = QLabel("A breathtakingly fast Arch Linux experience.")
        p.setObjectName("PageSub")
        title_col.addWidget(h)
        title_col.addWidget(p)
        title_row.addLayout(title_col)
        title_row.addStretch(1)
        root.addLayout(title_row)

        card = _Card()
        blurb = QLabel(
            "windOS Zen is a clean, minimal Arch Linux build with a neon "
            "glass aesthetic, Plymouth splash, ZSH and the XFCE desktop. "
            "This installer will set up a full EFI system for you."
        )
        blurb.setWordWrap(True)
        blurb.setObjectName("PageSub")
        card._layout.addWidget(blurb)

        # dry-run toggle
        self.dry_run_card = QFrame()
        self.dry_run_card.setObjectName("Card")
        drb = QVBoxLayout(self.dry_run_card)
        drb.setContentsMargins(20, 16, 20, 16)
        self.dry_toggle = QRadioButton(
            "Preview mode (dry-run) - do NOT touch my disks"
        )
        self.dry_toggle.setChecked(True)
        self.dry_toggle.toggled.connect(self._on_toggled)
        live = QLabel(
            "Preview logs every command it would run. Uncheck only when you "
            "are ready to write to the selected disk for real."
        )
        live.setObjectName("PageSub")
        live.setWordWrap(True)
        drb.addWidget(self.dry_toggle)
        drb.addWidget(live)
        card._layout.addWidget(self.dry_run_card)

        root.addWidget(card)
        root.addStretch(1)

    def _on_toggled(self, checked):
        # checked == preview == dry-run
        if checked:
            self.dry_run_card.setStyleSheet("border:1px solid #3B82F6;")
        else:
            self.dry_run_card.setStyleSheet("border:1px solid #EF4444;")
        self.dry_run_changed.emit(checked)

    def is_dry_run(self) -> bool:
        return self.dry_toggle.isChecked()


class DiskPage(QWidget):
    def __init__(self):
        super().__init__()
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(18)
        root.addLayout(_title("Choose where to install windOS Zen"))

        card = _Card()
        lbl = QLabel("Target disk")
        lbl.setObjectName("FieldLabel")
        card._layout.addWidget(lbl)
        self.combo = QComboBox()
        self.combo.setMinimumHeight(40)
        card._layout.addWidget(self.combo)

        self.bp = QLabel()
        self.bp.setObjectName("PageSub")
        self.bp.setWordWrap(True)
        self.bp_desc = QLabel()
        self.bp_desc.setObjectName("PageSub")
        self.bp_desc.setWordWrap(True)
        card._layout.addWidget(self.bp)
        card._layout.addWidget(self.bp_desc)
        root.addWidget(card)
        root.addStretch(1)

        self.combo.currentIndexChanged.connect(self._on_disk_selected)

    def populate_disks(self):
        self.combo.blockSignals(True)
        self.combo.clear()
        disks = list_system_disks()
        if not disks:
            disks = [{"device": "/dev/sda", "size": "—", "model": "No disks detected (simulated)"}]
        for d in disks:
            label = f"{d['device']}  -  {d['size']}  -  {d.get('model','')}"
            self.combo.addItem(label, d["device"])
        self.block_signals = False
        self.combo.blockSignals(False)
        self._on_disk_selected()

    def _on_disk_selected(self):
        idx = self.combo.currentIndex()
        if idx < 0:
            return
        dev = self.combo.itemData(idx)
        self.bp.setText(f"Selected: <b>{dev}</b>")
        self.bp_desc.setText(
            f"The disk <b>{dev}</b> will be completely erased and repartitioned "
            "with a 512M EFI system partition and a ZSTD-compressed root "
            "partition. All existing data will be lost."
        )

    def get_selected_device(self) -> str:
        idx = self.combo.currentIndex()
        if idx >= 0 and self.combo.itemData(idx):
            return self.combo.itemData(idx)
        return "/dev/sda"


class UserPage(QWidget):
    validation_changed = Signal(bool)

    def __init__(self):
        super().__init__()
        self._valid = False
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(18)
        root.addLayout(_title("Create your user account"))

        card = _Card()
        for name, key in [("Username", "username"), ("Hostname", "hostname"),
                          ("Password", "password"), ("Confirm password", "confirm")]:
            lab = QLabel(name)
            lab.setObjectName("FieldLabel")
            card._layout.addWidget(lab)
            le = QLineEdit()
            le.setMinimumHeight(40)
            if key in ("password", "confirm"):
                le.setEchoMode(QLineEdit.Password)
            le.textChanged.connect(self._validate)
            setattr(self, f"le_{key}", le)
            card._layout.addWidget(le)

        self.err = QLabel("")
        self.err.setObjectName("PageSub")
        self.err.setStyleSheet("color:#F43F5E;")
        card._layout.addWidget(self.err)
        root.addWidget(card)
        root.addStretch(1)

        self.le_username.setText("user")
        self.le_hostname.setText("windos-zen")
        self._validate()

    def _validate(self):
        u = self.le_username.text().strip()
        h = self.le_hostname.text().strip()
        p = self.le_password.text()
        c = self.le_confirm.text()
        ok = True
        msg = ""
        import re
        if not re.match(r"^[a-z_][a-z0-9_-]*$", u):
            ok = False
            msg = "Username must be lowercase, start with a letter/underscore."
        elif not re.match(r"^[a-zA-Z0-9-]+$", h):
            ok = False
            msg = "Hostname may only contain letters, numbers and dashes."
        elif len(p) < 4:
            ok = False
            msg = "Password must be at least 4 characters."
        elif p != c:
            ok = False
            msg = "Passwords do not match."
        self._valid = ok and bool(u and h and p)
        self.le_username.setProperty("invalid", not ok)
        self.le_username.style().unpolish(self.le_username)
        self.le_username.style().polish(self.le_username)
        self.err.setText(msg)
        self.validation_changed.emit(self._valid)

    def validate(self) -> bool:
        return self._valid

    def show_error(self):
        self.err.setText("Please fix the highlighted fields before continuing.")

    def get_user_data(self) -> dict:
        return {
            "username": self.le_username.text().strip(),
            "hostname": self.le_hostname.text().strip(),
            "password": self.le_password.text(),
        }


class SummaryPage(QWidget):
    def __init__(self):
        super().__init__()
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(18)
        root.addLayout(_title("Review before installing"))

        self.card = _Card()
        root.addWidget(self.card, 1)
        root.addStretch(1)

    def update_summary(self, config: InstallerConfig):
        # clear
        while self.card._layout.count():
            w = self.card._layout.takeAt(0).widget()
            if w:
                w.deleteLater()
        rows = [
            ("Mode", "PREVIEW (dry-run)" if config.dry_run else "LIVE (writes to disk)"),
            ("Target disk", config.target_disk),
            ("Hostname", config.hostname),
            ("Username", config.username),
            ("Partitions", "EFI 512M (FAT32) + root (ZSTD, remaining space)"),
            ("Bootloader", "GRUB (UEFI) -> windOS_Zen"),
            ("Desktop", "XFCE + LightDM"),
        ]
        for k, v in rows:
            row = QHBoxLayout()
            kk = QLabel(k)
            kk.setObjectName("FieldLabel")
            vv = QLabel(str(v))
            vv.setWordWrap(True)
            row.addWidget(kk)
            row.addWidget(vv, 1)
            wrap = QWidget()
            wrap.setLayout(row)
            self.card._layout.addWidget(wrap)
        if not config.dry_run:
            warn = QLabel("WARNING: LIVE mode will ERASE all data on "
                          f"{config.target_disk}.")
            warn.setStyleSheet("color:#F43F5E; font-weight:700;")
            warn.setWordWrap(True)
            self.card._layout.addWidget(warn)


class ProgressPage(QWidget):
    def __init__(self):
        super().__init__()
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(18)
        root.addLayout(_title("Installing windOS Zen..."))

        self.log = QTextEdit()
        self.log.setObjectName("Log")
        self.log.setReadOnly(True)
        root.addWidget(self.log, 1)

        self.bar = QProgressBar()
        self.bar.setValue(0)
        root.addWidget(self.bar)

    def reset(self):
        self.log.clear()
        self.bar.setValue(0)

    def append_log(self, line: str):
        self.log.append(line)
        self.log.verticalScrollBar().setValue(self.log.verticalScrollBar().maximum())

    def set_progress(self, value: int):
        self.bar.setValue(value)


class FinishPage(QWidget):
    def __init__(self):
        super().__init__()
        root = QVBoxLayout(self)
        root.setContentsMargins(36, 30, 36, 30)
        root.setSpacing(20)
        root.addStretch(1)

        self.icon = QLabel()
        self.icon.setAlignment(Qt.AlignCenter)
        root.addWidget(self.icon)

        self.title = QLabel("")
        self.title.setObjectName("PageTitle")
        self.title.setAlignment(Qt.AlignCenter)
        root.addWidget(self.title)

        self.msg = QLabel("")
        self.msg.setObjectName("PageSub")
        self.msg.setAlignment(Qt.AlignCenter)
        self.msg.setWordWrap(True)
        root.addWidget(self.msg)

        self.reboot_btn = QPushButton("Reboot now")
        self.reboot_btn.setObjectName("PrimaryButton")
        self.reboot_btn.clicked.connect(self._reboot)
        root.addWidget(self.reboot_btn, alignment=Qt.AlignCenter)
        root.addStretch(1)

    def set_result(self, success: bool, message: str, dry: bool):
        if success:
            self.icon.setPixmap(icon_check(72).pixmap(72, 72))
            self.title.setText("Installation complete")
            self.msg.setText(
                (f"Preview finished. No disks were touched.\n{message}")
                if dry else
                (f"windOS Zen was installed successfully.\n{message}\n\n"
                 "Remove the installation media and reboot.")
            )
        else:
            self.icon.setPixmap(icon_warn(72).pixmap(72, 72))
            self.title.setText("Installation failed")
            self.msg.setText(message)

    def _reboot(self):
        import subprocess
        try:
            subprocess.run(["systemctl", "reboot"], check=False)
        except Exception:
            pass
