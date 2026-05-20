"""
Snapshot management for GingerOS builds.
"""

import os
import shutil
import subprocess
from datetime import datetime
from config.constants import GINGER_ROOT, SNAPSHOTS_DIR, STATE_DIR, IMAGE_NAME


class SnapshotManager:
    """
    Handles creation and restoration of build snapshots.
    """

    def __init__(self, engine):
        self.engine = engine

    def list_snapshots(self):
        """List available snapshots."""
        if not os.path.exists(SNAPSHOTS_DIR):
            return []

        snaps = []
        for f in os.listdir(SNAPSHOTS_DIR):
            if f.endswith(".img"):
                path = os.path.join(SNAPSHOTS_DIR, f)
                stat = os.stat(path)
                snaps.append(
                    {
                        "name": f,
                        "size": stat.st_size,
                        "mtime": stat.st_mtime,
                        "date": datetime.fromtimestamp(stat.st_mtime).strftime(
                            "%Y-%m-%d %H:%M:%S"
                        ),
                    }
                )

        return sorted(snaps, key=lambda x: x["mtime"], reverse=True)

    def take_snapshot(self, label):
        """
        Create a snapshot of the current build state.

        Args:
            label: Descriptive label for the snapshot

        Returns:
            bool: True if successful, False otherwise
        """
        img_path = os.path.join(GINGER_ROOT, IMAGE_NAME)

        if not os.path.exists(img_path):
            self.engine.log("SNAPSHOT: No image found to snapshot.", "yellow")
            return False

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        snap_name = f"{timestamp}_{label}.img"
        snap_path = os.path.join(SNAPSHOTS_DIR, snap_name)

        self.engine.log(
            f"SNAPSHOT: Creating checkpoint '{label}'...", "bold cyan")
        self.engine.log(f"SNAPSHOT: Destination: {snap_path}", "dim")

        try:
            # Try reflink first (instant on btrfs/xfs), fall back to regular copy
            result = subprocess.run(
                ["cp", "--reflink=auto", img_path, snap_path],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                self.engine.log(
                    f"SNAPSHOT: ❌ Failed: {result.stderr}", "bold red")
                return False

            size_gb = os.path.getsize(snap_path) / (1024**3)
            self.engine.log(
                f"SNAPSHOT: ✅ '{label}' saved ({size_gb:.1f}GB)", "bold green"
            )

            # Also snapshot the .build_state markers if they exist
            state_snap = snap_path.replace(".img", ".state")
            if os.path.exists(STATE_DIR):
                shutil.copytree(STATE_DIR, state_snap, dirs_exist_ok=True)
                self.engine.log("SNAPSHOT: Build state snapshot saved.", "dim")
            else:
                self.engine.log(
                    "SNAPSHOT: No build state found to snapshot.", "dim")

            return True
        except Exception as e:
            self.engine.log(f"SNAPSHOT: ❌ Exception: {str(e)}", "bold red")
            return False

    def restore_snapshot(self, snap_name):
        """
        Restore a snapshot by replacing the current image and state.

        Args:
            snap_name: Name of the snapshot to restore

        Returns:
            bool: True if successful, False otherwise
        """
        snap_path = os.path.join(SNAPSHOTS_DIR, snap_name)
        img_path = os.path.join(GINGER_ROOT, IMAGE_NAME)

        if not os.path.exists(snap_path):
            self.engine.log(
                f"RESTORE: Snapshot '{snap_name}' not found.", "bold red")
            return False

        self.engine.log(
            f"RESTORE: Restoring from '{snap_name}'...", "bold yellow")

        # Step 1: Teardown current mounts
        self.engine.log("RESTORE: Unmounting current image...", "cyan")
        subprocess.run(
            ["bash", "lfs/image/13-teardown.sh"], cwd=GINGER_ROOT, capture_output=True
        )

        # Step 2: Replace the image
        self.engine.log("RESTORE: Replacing image file...", "cyan")
        result = subprocess.run(
            ["cp", "--reflink=auto", snap_path, img_path],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            self.engine.log(
                f"RESTORE: ❌ Failed to copy snapshot: {result.stderr}", "bold red"
            )
            return False

        # Step 3: Restore build state markers
        state_snap = snap_path.replace(".img", ".state")
        if os.path.exists(state_snap):
            if os.path.exists(STATE_DIR):
                shutil.rmtree(STATE_DIR)
            shutil.copytree(state_snap, STATE_DIR)
            self.engine.log("RESTORE: Build state markers restored.", "cyan")

        # Step 4: Remount
        self.engine.log("RESTORE: Remounting image...", "cyan")
        result = subprocess.run(
            ["bash", "lfs/image/01-prepare-image.sh"],
            cwd=GINGER_ROOT,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            self.engine.log(
                f"RESTORE: ✅ Restored to '{snap_name}' successfully.", "bold green"
            )
            # Reset step statuses
            for step in self.engine.steps:
                step.status = "pending"
                step.start_time = None
                step.end_time = None
            return True
        else:
            self.engine.log(
                f"RESTORE: ❌ Remount failed: {result.stderr}", "bold red")
            return False
