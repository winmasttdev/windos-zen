"""windOS Zen installer backend.

Pure-Python implementation of the install procedure. It is SAFE BY
DEFAULT: when `dry_run` is True (the default used by the UI unless the
user opts into live mode) no external command is executed - every
command is only logged so the user can review exactly what would run.

The flow mirrors a classic Arch install:
    partition -> format -> mount -> pacstrap -> fstab -> chroot config
    -> bootloader -> cleanup
"""
import os
import subprocess

MNT = "/mnt"
ESP_SIZE_MB = 512


class InstallerConfig:
    def __init__(self, dry_run: bool = True):
        self.dry_run = dry_run
        self.target_disk: str = "/dev/sda"
        self.hostname: str = "windos-zen"
        self.username: str = "user"
        self.password: str = "changeme"

    @property
    def partitions(self):
        # nvme/virtio disks ending in a digit need a "p" separator,
        # e.g. /dev/nvme0n1 -> /dev/nvme0n1p1, /dev/sda -> /dev/sda1
        suffix = "p" if self.target_disk[-1].isdigit() else ""
        esp = f"{self.target_disk}{suffix}1"
        root = f"{self.target_disk}{suffix}2"
        return esp, root


def list_system_disks() -> list[dict]:
    """Return block devices that look like real disks.

    Excludes memory-backed / virtual devices that are not valid install
    targets: zram, loop, ram and rom devices.
    """
    skip_prefixes = ("zram", "loop", "ram", "rom")
    try:
        out = subprocess.check_output(
            ["lsblk", "-d", "-n", "-p", "-o", "NAME,SIZE,MODEL,TYPE",
             "--exclude", "7"],  # exclude loop devices
            text=True,
        ).strip()
        disks = []
        for line in out.splitlines():
            parts = line.split(maxsplit=3)
            if len(parts) < 3:
                continue
            name, size, devtype = parts[0], parts[1], parts[2]
            model = parts[3] if len(parts) > 3 else ""
            if devtype != "disk":
                continue
            base = name.rsplit("/", 1)[-1]
            if base.startswith(skip_prefixes):
                continue
            disks.append({"device": name, "size": size, "model": model.strip()})
        return disks
    except Exception:
        return []


class Installer:
    def __init__(self, config: InstallerConfig, log_fn=print):
        self.config = config
        self.log = log_fn

    # -- command runner ------------------------------------------------ #
    def _run_cmd(self, cmd, *, as_root=True, check=True):
        if isinstance(cmd, list):
            rendered = " ".join(cmd)
        else:
            rendered = cmd
        if self.config.dry_run:
            self.log(f"[dry-run] $ {rendered}")
            return 0
        self.log(f"$ {rendered}")
        proc = subprocess.Popen(
            cmd, shell=isinstance(cmd, str),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            self.log(line.rstrip("\n"))
        return proc.wait()

    # -- steps --------------------------------------------------------- #
    def step_partition_disk(self):
        disk = self.config.target_disk
        self.log(f"==> Partitioning {disk}")
        self._run_cmd([
            "parted", "-s", disk, "mklabel", "gpt",
            "mkpart", "ESP", "fat32", "1MiB", f"{ESP_SIZE_MB}MiB",
            "set", "1", "esp", "on",
            "mkpart", "root", "ext4", f"{ESP_SIZE_MB}MiB", "100%",
        ])
        # ensure kernel sees the new table
        self._run_cmd(["partprobe", disk])

    def step_format_partitions(self):
        esp, root = self.config.partitions
        self.log(f"==> Formatting {esp} (FAT32) and {root} (ext4)")
        self._run_cmd(["mkfs.fat", "-F32", esp])
        self._run_cmd(["mkfs.ext4", "-F", root])

    def step_mount_target(self):
        esp, root = self.config.partitions
        self.log(f"==> Mounting {root} -> {MNT} and {esp} -> {MNT}/boot/efi")
        if not self.config.dry_run:
            os.makedirs(os.path.join(MNT, "boot/efi"), exist_ok=True)
        self._run_cmd(["mount", root, MNT])
        self._run_cmd(["mount", esp, os.path.join(MNT, "boot/efi")])

    def step_pacstrap(self):
        self.log("==> Installing base system (pacstrap)")
        self._run_cmd([
            "pacstrap", MNT, "base", "linux", "linux-firmware",
            "base-devel", "grub", "efibootmgr", "networkmanager",
            "xfce4", "xfce4-goodies", "lightdm", "lightdm-gtk-greeter",
            "plymouth", "zsh", "sudo",
        ])

    def step_generate_fstab(self):
        self.log("==> Generating fstab")
        if self.config.dry_run:
            self.log("[dry-run] $ genfstab -U " + MNT)
            return
        out = subprocess.check_output(["genfstab", "-U", MNT], text=True)
        with open(os.path.join(MNT, "etc/fstab"), "w") as f:
            f.write(out)

    def step_configure_system(self):
        self.log("==> Configuring installed system")
        c = self.config
        hostname = c.hostname
        user = c.username
        pw = c.password
        self._run_cmd(
            f'echo "{hostname}" > {MNT}/etc/hostname', as_root=True
        )
        self._run_cmd(
            "ln -sf /usr/share/zoneinfo/UTC " + MNT + "/etc/localtime"
        )
        self._run_cmd(f"echo 'en_US.UTF-8 UTF-8' >> {MNT}/etc/locale.gen")
        self._run_cmd(["arch-chroot", MNT, "locale-gen"])
        self._run_cmd(
            "echo 'LANG=en_US.UTF-8' > " + MNT + "/etc/locale.conf"
        )
        # users
        self._run_cmd(["arch-chroot", MNT, "useradd", "-mG", "wheel", user])
        self._run_cmd(
            f"echo 'root:{pw}' | chpasswd", as_root=True
        )
        self._run_cmd(
            f"echo '{user}:{pw}' | arch-chroot {MNT} chpasswd"
        )
        self._run_cmd(
            "echo '%wheel ALL=(ALL:ALL) ALL' > "
            + MNT + "/etc/sudoers.d/wheel"
        )
        # enable services
        self._run_cmd(
            ["arch-chroot", MNT, "systemctl", "enable", "NetworkManager"]
        )
        self._run_cmd(
            ["arch-chroot", MNT, "systemctl", "enable", "lightdm"]
        )
        self._run_cmd(
            ["arch-chroot", MNT, "systemctl", "enable", "plymouth"]
        )

    def step_install_bootloader(self):
        self.log("==> Installing GRUB (UEFI) bootloader")
        c = self.config
        self._run_cmd([
            "arch-chroot", MNT, "grub-install", "--target=x86_64-efi",
            "--efi-directory=/boot/efi", "--bootloader-id=windOS_Zen",
            "--removable",
        ])
        self._run_cmd([
            "arch-chroot", MNT, "grub-mkconfig", "-o",
            "/boot/grub/grub.cfg",
        ])

    def step_unmount(self):
        self.log("==> Unmounting target")
        self._run_cmd(["umount", "-R", MNT], check=False)

    # -- orchestration ------------------------------------------------ #
    def run_all(self):
        try:
            self.step_partition_disk()
            self.step_format_partitions()
            self.step_mount_target()
            self.step_pacstrap()
            self.step_generate_fstab()
            self.step_configure_system()
            self.step_install_bootloader()
            self.step_unmount()
            mode = "PREVIEW" if self.config.dry_run else "install"
            self.log(f"==> windOS Zen {mode} complete.")
            return True, "All steps finished successfully."
        except Exception as e:  # noqa: BLE001
            self.log(f"!! Error: {e}")
            if not self.config.dry_run:
                self.step_unmount()
            return False, str(e)
