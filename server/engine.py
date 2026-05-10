"""
Core build engine for GingerOS LFS builds.
"""

import os
import time
import threading
import subprocess
import re
import signal
import json

from config.constants import (
    GINGER_ROOT,
    STATE_DIR,
    SOURCES_DIR,
    LFS_MOUNT,
)
from server.build_steps import get_build_steps
from server.process_monitor import ProcessMonitor
from server.storage_monitor import StorageMonitor
from server.mount_manager import MountManager
from server.snapshot_manager import SnapshotManager
from server.telemetry import TelemetryManager


class GingerEngine:
    """
    Core build engine for GingerOS.

    Manages the execution of build steps, process monitoring, logging,
    and user interaction via a keyboard listener.
    """

    def __init__(self, dry_run: bool = False):
        """
        Initialize the build engine with defined steps and state.
        """
        self.dry_run = dry_run
        self.ginger_root = GINGER_ROOT
        self.sources_dir = SOURCES_DIR

        # Build steps
        self.steps = get_build_steps()

        # State tracking
        self.current_step_idx = 0
        self.current_pkg = ""
        self.current_pkg_idx = 0
        self.total_pkg_count = 0
        self.pkg_start_time = None
        self.phase_start_time = None
        self.overall_start_time = None
        self.logs = []
        self.max_logs = 100
        self.is_running = False
        self.aborted = False
        self.error_msg = ""
        self.paused_for_error = False

        # Package stepping
        self.package_stepping = False
        self.paused_for_package = False
        self.current_process = None
        self.on_log_callbacks = []

        # Regex patterns
        self.ansi_escape = re.compile(
            r"(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]")
        self.non_printable = re.compile(r"[^\x20-\x7E\n\t]")

        # Initialize managers
        self.telemetry = TelemetryManager(self)
        self.storage_monitor = StorageMonitor(self)
        self.mount_manager = MountManager(self)
        self.snapshot_manager = SnapshotManager(self)
        self.process_monitor = ProcessMonitor(self)

        # Log rotation
        self.telemetry.rotate_logs()

        # Keep sudo alive (skip if dry_run)
        if not self.dry_run:
            self.sudo_thread = threading.Thread(
                target=self._sudo_keepalive, daemon=True
            )
            self.sudo_thread.start()

    def _sudo_keepalive(self):
        """Keep sudo credentials alive."""
        while not self.aborted:
            if not self.dry_run:
                subprocess.run(["sudo", "-v"], capture_output=True)
            time.sleep(60)

    def log(self, message: str, style: str | None):
        """Log a message."""
        self.telemetry.log(message, style)

    def _update_storage(self):
        """Update storage statistics."""
        self.storage_monitor.update_storage()

    @property
    def storage_stats(self):
        """Get current storage statistics."""
        return self.storage_monitor.storage_stats

    def _ensure_lfs_mounted(self):
        """Ensure LFS is mounted."""
        return self.mount_manager.ensure_lfs_mounted()

    def _verify_chroot_ready(self):
        """Verify chroot environment is ready."""
        return self.mount_manager.verify_chroot_ready()

    def _should_skip(self, step):
        """
        Determines if a build step should be skipped based on markers or filesystem state.
        """
        # 1. CRITICAL: Source Integrity Check (HOST SIDE)
        if step.id == "04_setup_downloads":
            sources_dir = os.path.join(GINGER_ROOT, "sources")
            if not os.path.exists(sources_dir) or len(os.listdir(sources_dir)) < 5:
                # Force re-download by removing the marker if it exists
                marker_path = os.path.join(STATE_DIR, f"{step.id}.built")
                if os.path.exists(marker_path):
                    try:
                        os.remove(marker_path)
                    except:
                        pass
                return False

        # 1.5. Failsafe Mount Checks
        if step.id == "01_create_qemu_img":
            try:
                if (
                    subprocess.run(
                        ["mountpoint", "-q", LFS_MOUNT], capture_output=True, timeout=5
                    ).returncode
                    != 0
                ):
                    return False
            except:
                return False

        if step.id == "09_chroot_mounts":
            try:
                # Check for proc mount inside LFS as a proxy for all chroot mounts
                if (
                    subprocess.run(
                        ["grep", "-q", f"{LFS_MOUNT}/proc", "/proc/mounts"],
                        capture_output=True,
                        timeout=5,
                    ).returncode
                    == 0
                ):
                    return True
            except:
                pass

        # 2. Direct marker check in the central state dir
        central_marker = os.path.join(STATE_DIR, f"{step.id}.built")
        if os.path.exists(central_marker):
            return True

        # 2.5. Check LFS state dir ONLY if it is actually mounted (prevents FPs)
        try:
            if subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True).returncode == 0:
                lfs_marker = os.path.join(LFS_MOUNT, "var/lib/ginger", f"{step.id}.built")
                if os.path.exists(lfs_marker):
                    return True
        except:
            pass

        # 3. Smart checks for major phases (checks all constituent packages)
        if step.id == "07_phase1_tools":
            return self._check_phase_complete("phase1-tools")
        if step.id == "08_phase2_tools":
            return self._check_phase_complete("phase2-tools")
        if step.id == "10_phase3_system":
            return self._check_phase_complete("phase3-system")
        if step.id == "11_kernel":
            return self._check_phase_complete("phase4-boot")

        # 4. Return false if not completed
        return False

    def _check_phase_complete(self, script_subdir):
        """Helper to check if all scripts in a directory have corresponding central markers."""
        scripts_dir = os.path.join(self.ginger_root, "lfs", script_subdir)
        if not os.path.exists(scripts_dir):
            return False

        scripts = sorted([f for f in os.listdir(
            scripts_dir) if f.endswith(".sh")])
        if not scripts:
            return False

        for script in scripts:
            script_path = os.path.join(scripts_dir, script)
            pkg_name = self._get_script_pkg_name(script_path)
            file_name = script.replace(".sh", "")
            marker_names = [file_name]

            # For all phases, file names often have prefixes like 01-
            if "-" in file_name:
                stripped_name = "-".join(file_name.split("-")[1:])
                if stripped_name != file_name:
                    marker_names.append(stripped_name)

            # Prioritize the central host marker as the single source of truth
            possible_marker_names = []
            for name in marker_names:
                possible_marker_names.extend(
                    [f"{name}.built", f"{name}-temp.built"])
            if pkg_name:
                possible_marker_names.extend(
                    [f"{pkg_name}.built", f"{pkg_name}-temp.built"]
                )

            found = False
            # Check host state dir
            for m in possible_marker_names:
                if os.path.exists(os.path.join(STATE_DIR, m)):
                    found = True
                    break

            # Check LFS state dir if not found on host, but only if mounted
            if not found:
                try:
                    if subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True).returncode == 0:
                        lfs_state_dir = os.path.join(LFS_MOUNT, "var/lib/ginger")
                        if os.path.exists(lfs_state_dir):
                            for m in possible_marker_names:
                                if os.path.exists(os.path.join(lfs_state_dir, m)):
                                    found = True
                                    break
                except:
                    pass

            if not found:
                return False
        return True

    def _get_script_pkg_name(self, script_path):
        """Peeks into a script to find its PKG_NAME definition."""
        try:
            with open(script_path, "r") as f:
                content = f.read()
                match = re.search(r'^PKG_NAME=["\'](.*)["\']', content, re.M)
                if match:
                    return match.group(1)
        except:
            pass
        return None

    def _execute_step(self, step):
        """
        Execute a single build step.
        """
        # --- NEW: Dependency Enforcement ---
        # Ensure all previous steps are completed before running the current one
        all_steps = self.steps
        try:
            current_idx = all_steps.index(step)
            for i in range(current_idx):
                prev_step = all_steps[i]
                if not self._should_skip(prev_step):
                    self.log(
                        f"ERROR: Cannot run {step.name} because {prev_step.name} is not completed.",
                        "bold red",
                    )
                    self.log(
                        f"Please complete {prev_step.name} first.", "yellow")
                    step.status = "failed"
                    return
        except ValueError:
            pass  # Step not in list (should not happen)
        # -----------------------------------

        # Verify mount and chroot for dependent phases
        try:
            step_num = int(step.id.split("_")[0])
            if step_num >= 2 and step_num <= 15:
                if not self._ensure_lfs_mounted():
                    self.log(
                        f"ERROR: Step {step.name} cannot proceed without LFS mount.",
                        "bold red",
                    )
                    step.status = "failed"
                    return
        except (ValueError, IndexError):
            pass  # Non-standard step ID, skip auto-mount check

        # Verify chroot for system phases
        if step.id in ["10_phase3_system", "11_kernel"]:
            if not self._verify_chroot_ready():
                self.log("WARN: Chroot environments are NOT mounted!", "yellow")
                self.log("Attempting automated chroot recovery...", "bold cyan")

                # Find the "chroot-mounts" step
                mount_step = next(
                    (s for s in self.steps if s.id == "09_chroot_mounts"), None
                )
                if mount_step:
                    # Run it once
                    proc = subprocess.run(
                        mount_step.command,
                        shell=True,
                        cwd=GINGER_ROOT,
                        capture_output=True,
                        text=True,
                    )
                    if proc.returncode == 0:
                        self.log("✅ Chroot recovered successfully.",
                                 "bold green")
                    else:
                        self.log(
                            f"❌ Chroot recovery failed: {proc.stderr}", "bold red"
                        )
                        step.status = "failed"
                        return

                # Re-verify after attempt
                if not self._verify_chroot_ready():
                    self.log(
                        "ERROR: Chroot still not ready. Please run 'Mount Chroot' step manually.",
                        "bold red",
                    )
                    step.status = "failed"
                    return

        # Execute the step
        return_code = self.process_monitor.execute_step(step)

        # Handle completion
        if return_code == 0:
            step.status = "completed"
            self.log(f"✅ Step completed: {step.name}", "bold green")
        else:
            step.status = "failed"
            self.log(f"❌ Step failed: {step.name}", "bold red")

        # Save telemetry
        self.telemetry.save_telemetry()

    def resume_package(self):
        """Resume from a paused package."""
        if not self.current_pkg:
            self.log("Cannot resume package: Unknown current package", "bold red")
            return

        self.log(f"RESUMING PACKAGE: {self.current_pkg}...", "bold yellow")
        marker_paths = [
            f"{LFS_MOUNT}/var/lib/ginger/{self.current_pkg}.built",
            f"/var/lib/ginger/{self.current_pkg}.built",
        ]
        for path in marker_paths:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except:
                    pass
        self.paused_for_package = False

    def abort(self):
        """Abort the current build process and stop background tasks."""
        self.log("SYSTEM_SHUTDOWN :: Terminating all active processes...", "bold red")
        self.aborted = True
        self.paused_for_package = False
        if self.current_process:
            try:
                # Kill the entire process group to catch sub-processes (tail, etc.)
                pgid = os.getpgid(self.current_process.pid)
                os.killpg(pgid, signal.SIGTERM)
                self.current_process.wait(timeout=2)
            except:
                try:
                    self.current_process.kill()
                except:
                    pass
            self.current_process = None

    def list_snapshots(self):
        """List available snapshots."""
        return self.snapshot_manager.list_snapshots()

    def take_snapshot(self, label):
        """Take a snapshot."""
        return self.snapshot_manager.take_snapshot(label)

    def restore_snapshot(self, snap_name):
        """Restore a snapshot."""
        return self.snapshot_manager.restore_snapshot(snap_name)

    def rescue_downloads(self):
        """Execute the rescue downloads script."""
        rescue_script = os.path.join(
            self.ginger_root, "lfs/host/rescue-downloads.sh")
        if not os.path.exists(rescue_script):
            self.log(
                f"ERROR: Rescue script not found at {rescue_script}", "bold red")
            return

        self.log("🚀 INITIATING DOWNLOAD RESCUE SEQUENCE...", "bold cyan")

        # We'll use a temporary "pseudo-step" to run this so it shows up in logs
        from ui.web.models import BuildStep
        rescue_step = BuildStep(
            "99_rescue_downloads",
            "Rescue Downloads",
            f"bash {rescue_script}",
            "Maintenance"
        )

        # Run it through the process monitor
        self.execute_step(rescue_step)

    def _download_missing_source(self, url):
        """Download a missing source file."""
        self.telemetry.download_missing_source(url)
