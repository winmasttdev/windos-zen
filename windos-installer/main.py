#!/usr/bin/env python3
"""windOS Zen native graphical installer (PySide6).

Single-file application window that drives a 5-step install flow:
    Welcome -> Disk -> User -> Summary -> Progress -> Finish

It is SAFE BY DEFAULT: it boots in dry-run (preview) mode and never
touches a disk unless the user explicitly enables real installation
inside the Welcome screen. In dry-run mode the backend only logs the
exact commands it would run.

Run:
    python main.py
    python -m windos_installer
"""
import os
import sys
import subprocess

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QStackedWidget, QLabel,
    QPushButton, QFrame, QVBoxLayout, QHBoxLayout, QSizePolicy,
)
from PySide6.QtCore import Qt, QSize
from PySide6.QtGui import QIcon

from ui.theme import WINDOS_STYLESHEET
from ui.icons import (
    icon_windos, icon_disk, icon_user, icon_summary,
    icon_install, icon_check, icon_warn,
)
from ui.pages import (
    WelcomePage, DiskPage, UserPage, SummaryPage, ProgressPage, FinishPage,
)
from backend.installer import InstallerConfig, list_system_disks
from backend.worker import InstallerWorker


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = InstallerConfig()
        self.worker: InstallerWorker | None = None
        self._setup_window()
        self._init_ui()
        self._connect_signals()
        self.update_nav_state()
        self.resize(960, 660)

    # ------------------------------------------------------------------ #
    def _setup_window(self):
        self.setWindowTitle("windOS Zen Installer")
        self.setMinimumSize(820, 560)
        icon = icon_windos(64)
        if not icon.isNull():
            self.setWindowIcon(icon)

    def _init_ui(self):
        root = QWidget()
        self.setCentralWidget(root)
        outer = QVBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # ---- header ---- #
        header = QFrame()
        header.setObjectName("Header")
        hb = QHBoxLayout(header)
        hb.setContentsMargins(18, 12, 18, 12)
        self.lbl_logo = QLabel()
        self.lbl_logo.setPixmap(icon_windos(26).pixmap(26, 26))
        hb.addWidget(self.lbl_logo)
        self.lbl_title = QLabel("windOS Zen")
        self.lbl_title.setObjectName("HeaderTitle")
        hb.addWidget(self.lbl_title)
        hb.addStretch(1)
        self.lbl_mode = QLabel()
        self.lbl_mode.setObjectName("ModeBadge")
        hb.addWidget(self.lbl_mode)
        outer.addWidget(header)

        # ---- body ---- #
        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        # sidebar (stepper)
        self.sidebar = QFrame()
        self.sidebar.setObjectName("Sidebar")
        sb = QVBoxLayout(self.sidebar)
        sb.setContentsMargins(16, 22, 16, 22)
        sb.setSpacing(6)
        self.steps = []
        for i, (txt, ic) in enumerate([
            ("Welcome", icon_windos(18)),
            ("Disk", icon_disk(18)),
            ("User", icon_user(18)),
            ("Summary", icon_summary(18)),
            ("Install", icon_install(18)),
        ]):
            row = QHBoxLayout()
            row.setSpacing(10)
            step_ic = QLabel()
            step_ic.setPixmap(ic.pixmap(18, 18))
            step_ic.setFixedSize(22, 22)
            step_lbl = QLabel(txt)
            step_lbl.setObjectName("StepLabel")
            row.addWidget(step_ic)
            row.addWidget(step_lbl)
            row.addStretch(1)
            wrap = QWidget()
            wrap.setLayout(row)
            wrap.setObjectName("StepItem")
            sb.addWidget(wrap)
            self.steps.append((wrap, step_ic, step_lbl))
        sb.addStretch(1)
        body.addWidget(self.sidebar)

        # stack of pages
        self.stack = QStackedWidget()
        self.page_welcome = WelcomePage()
        self.page_disk = DiskPage()
        self.page_user = UserPage()
        self.page_summary = SummaryPage()
        self.page_progress = ProgressPage()
        self.page_finish = FinishPage()
        self.stack.addWidget(self.page_welcome)
        self.stack.addWidget(self.page_disk)
        self.stack.addWidget(self.page_user)
        self.stack.addWidget(self.page_summary)
        self.stack.addWidget(self.page_progress)
        body.addWidget(self.stack, 1)
        outer.addLayout(body, 1)

        # ---- nav bar ---- #
        self.nav_bar = QFrame()
        self.nav_bar.setObjectName("NavBar")
        nb = QHBoxLayout(self.nav_bar)
        nb.setContentsMargins(18, 12, 18, 12)
        self.btn_back = QPushButton("Back")
        self.btn_back.setObjectName("GhostButton")
        self.btn_next = QPushButton("Next")
        self.btn_next.setObjectName("PrimaryButton")
        nb.addWidget(self.btn_back)
        nb.addStretch(1)
        nb.addWidget(self.btn_next)
        outer.addWidget(self.nav_bar)

        self.page_disk.populate_disks()

    def _connect_signals(self):
        self.btn_back.clicked.connect(self.go_back)
        self.btn_next.clicked.connect(self.go_next)
        self.page_welcome.dry_run_changed.connect(self._on_dry_run_changed)
        self.page_user.validation_changed.connect(self._on_user_validation_changed)

    # ------------------------------------------------------------------ #
    def _on_dry_run_changed(self, dry):
        self.config.dry_run = dry  # checked = preview / dry-run
        self.update_nav_state()

    def _on_user_validation_changed(self, valid):
        if self.stack.currentIndex() == 2:
            self.btn_next.setEnabled(valid)

    def update_nav_state(self):
        idx = self.stack.currentIndex()
        for i, (wrap, ic, lbl) in enumerate(self.steps):
            state = "done" if i < idx else ("active" if i == idx else "idle")
            wrap.setProperty("state", state)
            lbl.setProperty("state", state)
            wrap.style().unpolish(wrap)
            wrap.style().polish(wrap)
            lbl.style().unpolish(lbl)
            lbl.style().polish(lbl)

        self.btn_back.setVisible(idx > 0 and idx != 4 and idx != 5)
        self.btn_back.setEnabled(idx > 0)

        if idx == 0:
            self.btn_next.setText("Next")
            self.btn_next.setObjectName("PrimaryButton")
            self.btn_next.setStyleSheet("")
            self.btn_next.setEnabled(True)
        elif idx == 1:
            self.btn_next.setText("Next")
            self.btn_next.setObjectName("PrimaryButton")
            self.btn_next.setStyleSheet("")
            self.btn_next.setEnabled(True)
        elif idx == 2:
            self.btn_next.setText("Next")
            self.btn_next.setObjectName("PrimaryButton")
            self.btn_next.setStyleSheet("")
            self.btn_next.setEnabled(self.page_user.validate())
        elif idx == 3:
            self.btn_next.setText("Install windOS Zen ")
            if self.config.dry_run:
                self.btn_next.setObjectName("PrimaryButton")
            else:
                self.btn_next.setObjectName("DangerButton")
            self.btn_next.setStyleSheet("")
        elif idx == 4:
            self.btn_back.setVisible(False)
            self.btn_next.setVisible(False)
        elif idx == 5:
            self.btn_back.setVisible(False)

        self.lbl_mode.setText("PREVIEW" if self.config.dry_run else "LIVE")
        self.lbl_mode.setProperty("live", not self.config.dry_run)
        self.lbl_mode.style().unpolish(self.lbl_mode)
        self.lbl_mode.style().polish(self.lbl_mode)

    def go_back(self):
        idx = self.stack.currentIndex()
        if idx == 3:
            self.stack.setCurrentIndex(2)
        elif idx in (1, 2):
            self.stack.setCurrentIndex(idx - 1)
        self.update_nav_state()

    def go_next(self):
        idx = self.stack.currentIndex()
        if idx == 0:
            self.config.dry_run = self.page_welcome.is_dry_run()
            self.stack.setCurrentIndex(1)
        elif idx == 1:
            dev = self.page_disk.get_selected_device()
            if dev:
                self.config.target_disk = dev
            self.stack.setCurrentIndex(2)
        elif idx == 2:
            if not self.page_user.validate():
                self.page_user.show_error()
                return
            u = self.page_user.get_user_data()
            self.config.username = u["username"]
            self.config.password = u["password"]
            self.config.hostname = u["hostname"]
            self.page_summary.update_summary(self.config)
            self.stack.setCurrentIndex(3)
        elif idx == 3:
            self.begin_install()
        self.update_nav_state()

    # ------------------------------------------------------------------ #
    def begin_install(self):
        self.stack.setCurrentIndex(4)
        self.update_nav_state()
        self.page_progress.reset()
        user = self.page_user.get_user_data()
        self.config.username = user["username"]
        self.config.password = user["password"]
        self.config.hostname = user["hostname"]
        dev = self.page_disk.get_selected_device()
        if dev:
            self.config.target_disk = dev
        self.worker = InstallerWorker(self.config)
        self.worker.log_line.connect(self.page_progress.append_log)
        self.worker.progress.connect(self.page_progress.set_progress)
        self.worker.finished.connect(self._on_install_finished)
        self.worker.start()

    def _on_install_finished(self, success, message):
        self.page_finish.set_result(success, message, self.config.dry_run)
        self.stack.setCurrentIndex(5)
        self.update_nav_state()

    def closeEvent(self, event):
        if self.worker is not None and self.worker.isRunning():
            self.worker.quit()
            self.worker.wait(2000)
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("windOS Zen Installer")
    app.setStyleSheet(WINDOS_STYLESHEET)
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
