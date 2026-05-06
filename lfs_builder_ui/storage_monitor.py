"""
Storage monitoring and emergency cleanup for GingerOS builds.
"""

import os
import shutil
import subprocess
from .constants import GINGER_ROOT, STATE_DIR


class StorageMonitor:
    """
    Monitors storage usage and handles emergency cleanup.
    """

    def __init__(self, engine):
        self.engine = engine
        self.storage_stats = {"host": 0, "lfs": 0}

    def update_storage(self):
        """Update storage usage percentages."""
        paths = {"host": "/", "lfs": "/mnt/lfs"}
        for key, path in paths.items():
            try:
                if os.path.exists(path):
                    st = os.statvfs(path)
                    used = st.f_blocks - st.f_bfree
                    total = st.f_blocks
                    if total > 0:
                        percent = (used / total) * 100
                        self.storage_stats[key] = percent

                        # Emergency cleanup for host disk
                        if key == "host" and percent > 95:
                            self._emergency_cleanup()
                else:
                    self.storage_stats[key] = 0
            except:
                self.storage_stats[key] = 0

    def _emergency_cleanup(self):
        """Perform emergency cleanup when host disk is full."""
        # Only cleanup host sources if we are already in Phase 3 or 4
        # because at that point, sources are already copied to LFS
        if self.engine.current_step_idx >= 12:  # Phase 3 System or later
            host_sources = os.path.join(GINGER_ROOT, "sources")
            if os.path.exists(host_sources):
                self.engine.log(
                    "CRITICAL: Host disk full! Purging host sources to survive...",
                    "bold red",
                )
                try:
                    # We don't delete the dir, just the contents
                    for f in os.listdir(host_sources):
                        fpath = os.path.join(host_sources, f)
                        if os.path.isfile(fpath):
                            os.remove(fpath)
                        elif os.path.isdir(fpath):
                            shutil.rmtree(fpath)
                    self.engine.log(
                        "Emergency cleanup finished. Build will attempt to continue.",
                        "green",
                    )
                except Exception as e:
                    self.engine.log(
                        f"Emergency cleanup failed: {str(e)}",
                        "bold red",
                    )
