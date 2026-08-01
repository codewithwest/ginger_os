"""
Storage monitoring and emergency cleanup for GingerOS builds.
"""

import os
import shutil
from config.constants import GINGER_ROOT


class StorageMonitor:
    """
    Monitors storage usage and handles emergency cleanup.
    """

    def __init__(self, engine):
        self.engine = engine
        self.storage_stats = {
            "host": {"percent": 0, "used_gb": 0, "total_gb": 0},
            "lfs": {"percent": 0, "used_gb": 0, "total_gb": 0},
        }

    def update_storage(self):
        """Update storage usage percentages."""
        from config.constants import LFS_MOUNT

        paths = {"host": "/", "lfs": LFS_MOUNT}
        for key, path in paths.items():
            try:
                if os.path.exists(path):
                    st = os.statvfs(path)
                    used = st.f_blocks - st.f_bfree
                    total = st.f_blocks
                    if total > 0:
                        percent = (used / total) * 100
                        used_gb = used * st.f_frsize / (1024**3)
                        total_gb = total * st.f_frsize / (1024**3)

                        self.storage_stats[key] = {
                            "percent": percent,
                            "used_gb": used_gb,
                            "total_gb": total_gb,
                        }

                        # Emergency cleanup for host disk
                        if key == "host" and percent > 95:
                            self._emergency_cleanup()
                else:
                    self.storage_stats[key] = {
                        "percent": 0,
                        "used_gb": 0,
                        "total_gb": 0,
                    }
            except:
                self.storage_stats[key] = {"percent": 0, "used_gb": 0, "total_gb": 0}

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
