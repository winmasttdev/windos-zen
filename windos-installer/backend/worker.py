"""Background worker that runs the installer without freezing the UI."""
from PySide6.QtCore import QThread, Signal

from .installer import Installer


class InstallerWorker(QThread):
    log_line = Signal(str)
    progress = Signal(int)
    finished = Signal(bool, str)

    # approximate progress weights per step (sums to ~100)
    _STEPS = [
        ("step_partition_disk", 10),
        ("step_format_partitions", 10),
        ("step_mount_target", 5),
        ("step_pacstrap", 45),
        ("step_generate_fstab", 5),
        ("step_configure_system", 15),
        ("step_install_bootloader", 10),
        ("step_unmount", 0),
    ]

    def __init__(self, config):
        super().__init__()
        self.config = config
        self._installer = Installer(config, log_fn=self.log_line.emit)

    def run(self):
        try:
            done = 0
            for name, weight in self._STEPS:
                getattr(self._installer, name)()
                done += weight
                self.progress.emit(min(done, 100))
            mode = "PREVIEW" if self.config.dry_run else "install"
            self.finished.emit(True, f"windOS Zen {mode} sequence finished.")
        except Exception as e:  # noqa: BLE001
            self.log_line.emit(f"!! Error: {e}")
            if not self.config.dry_run:
                try:
                    self._installer.step_unmount()
                except Exception:
                    pass
            self.finished.emit(False, str(e))
