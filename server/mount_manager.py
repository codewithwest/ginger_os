"""
Mount and chroot management for LFS builds.
"""

import os
import subprocess
from config.constants import LFS_MOUNT, GINGER_ROOT, BUILD_TYPE


class MountManager:
    """
    Handles mounting and unmounting of LFS filesystems and chroot environments.
    """

    def __init__(self, engine):
        self.engine = engine

    def ensure_lfs_mounted(self):
        """
        Verify that LFS_MOUNT is mounted. If not, automatically run
        the idempotent prepare-image step to recover the environment.

        Returns:
            bool: True if mounted (or successfully re-mounted), False otherwise.
        """
        if self.engine.dry_run:
            return True

        try:
            result = subprocess.run(
                ["mountpoint", "-q", LFS_MOUNT], capture_output=True, timeout=5
            )
            if result.returncode == 0:
                return self._setup_bind_mounts()

            if self.engine.dry_run:
                return True

            # Mount lost! Behavior depends on BUILD_TYPE
            if BUILD_TYPE == "native":
                self.engine.log(
                    f"CRITICAL: LFS partition ({LFS_MOUNT}) is NOT mounted!", "bold red"
                )
                self.engine.log(
                    "On native servers, please mount your partition manually.", "yellow"
                )
                return False

            # Image recovery
            return self._attempt_mount_recovery()

        except Exception as e:
            self.engine.log(
                f"!!! Error during mount check: {str(e)}", "bold red")
            return False

    def _setup_bind_mounts(self):
        """Setup bind mounts for the LFS environment."""
        try:
            # Bind mount ginger_os directory
            bind_dir = os.path.join(LFS_MOUNT, "ginger_os")
            if not os.path.exists(bind_dir):
                subprocess.run(["sudo", "mkdir", "-p", bind_dir],
                               capture_output=True)

            if (
                subprocess.run(
                    ["mountpoint", "-q", bind_dir], capture_output=True
                ).returncode
                != 0
            ):
                r = subprocess.run(
                    ["sudo", "mount", "--bind", GINGER_ROOT, bind_dir],
                    capture_output=True,
                )
                if r.returncode != 0:
                    self.engine.log(
                        f"ERROR: Failed to bind-mount repo into chroot: {r.stderr}",
                        "bold red",
                    )
                    return False

            # Mount /proc for phase 1/2 builds
            proc_mount = os.path.join(LFS_MOUNT, "proc")
            if not os.path.exists(proc_mount):
                subprocess.run(
                    ["sudo", "mkdir", "-p", proc_mount], capture_output=True)

            if (
                subprocess.run(
                    ["mountpoint", "-q", proc_mount], capture_output=True
                ).returncode
                != 0
            ):
                subprocess.run(
                    ["sudo", "mount", "-vt", "proc", "proc", proc_mount],
                    capture_output=True,
                )

            return True
        except Exception as e:
            self.engine.log(
                f"Error setting up bind mounts: {str(e)}", "bold red")
            return False

    def _attempt_mount_recovery(self):
        """Attempt to recover lost mount using prepare-image script."""
        self.engine.log(
            f"WARN: LFS partition ({LFS_MOUNT}) is NOT mounted!", "yellow")
        self.engine.log("Attempting automated mount recovery...", "bold cyan")

        # Find the prepare step
        prepare_step = next(
            (s for s in self.engine.steps if s.id == "01_create_qemu_img"), None
        )
        if not prepare_step:
            self.engine.log(
                "ERROR: Could not find Recovery Step (01_create_qemu_img)!",
                "bold red",
            )
            return False

        # Run the idempotent script with timeout
        try:
            proc = subprocess.run(
                prepare_step.command,
                shell=True,
                cwd=GINGER_ROOT,
                capture_output=True,
                text=True,
                timeout=30,
            )
            if proc.returncode == 0:
                self.engine.log(
                    "✅ Mount recovered successfully.", "bold green")
                return True
            else:
                self.engine.log(
                    f"❌ Automated recovery failed: {proc.stderr}", "bold red"
                )
                return False
        except subprocess.TimeoutExpired:
            self.engine.log(
                "❌ Automated recovery TIMED OUT (likely waiting for sudo).",
                "bold red",
            )
            return False

    def verify_chroot_ready(self):
        """Verify chroot filesystems are mounted."""
        if self.engine.dry_run:
            return True

        mounts = [f"{LFS_MOUNT}/proc", f"{LFS_MOUNT}/sys", f"{LFS_MOUNT}/dev"]
        try:
            with open("/proc/mounts", "r") as f:
                content = f.read()
                for m in mounts:
                    if m not in content:
                        self.engine.log(
                            f"CRITICAL: {m} is NOT mounted!", "bold red")
                        return False
            return True
        except:
            return False

    def attempt_chroot_recovery(self):
        """Attempt to recover chroot mounts."""
        self.engine.log("Attempting automated chroot recovery...", "bold cyan")

        # Find the chroot-mounts step
        mount_step = next(
            (s for s in self.engine.steps if s.id == "09_chroot_mounts"), None
        )
        if mount_step:
            proc = subprocess.run(
                mount_step.command,
                shell=True,
                cwd=GINGER_ROOT,
                capture_output=True,
                text=True,
            )
            if proc.returncode == 0:
                self.engine.log(
                    "✅ Chroot recovered successfully.", "bold green")
                return True
            else:
                self.engine.log(
                    f"❌ Chroot recovery failed: {proc.stderr}", "bold red")

        return False
