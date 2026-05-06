"""
Telemetry and logging management for GingerOS builds.
"""

import os
import json
import shutil
from datetime import datetime
from .constants import LOG_DIR, MASTER_LOG, STATE_DIR, GINGER_ROOT


class TelemetryManager:
    """
    Handles build telemetry, logging rotation, and session data.
    """

    def __init__(self, engine):
        self.engine = engine
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.telemetry_file = os.path.join(STATE_DIR, "telemetry.json")

    def rotate_logs(self):
        """Clean up old logs or rotate master log if too big."""
        if os.path.exists(MASTER_LOG):
            if os.path.getsize(MASTER_LOG) > 50 * 1024 * 1024:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                shutil.move(MASTER_LOG, f"{MASTER_LOG}.{timestamp}.bak")
                with open(MASTER_LOG, "w") as f:
                    f.write(f"--- GingerOS Master Log Rotated at {timestamp} ---\n")

        all_logs = sorted(
            [
                os.path.join(LOG_DIR, f)
                for f in os.listdir(LOG_DIR)
                if f.endswith(".log")
            ]
        )
        if len(all_logs) > 50:
            for old_log in all_logs[:-50]:
                try:
                    os.remove(old_log)
                except:
                    pass

    def log(self, message, style=None):
        """Log a message with timestamp and style."""
        # Filter ANSI and non-printables
        message = self.engine.ansi_escape.sub("", message)
        message = self.engine.non_printable.sub("", message)

        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.engine.logs.append((log_entry, style))
        if len(self.engine.logs) > self.engine.max_logs:
            self.engine.logs.pop(0)

        # Broadcast to Web UI
        for callback in self.engine.on_log_callbacks:
            try:
                callback(log_entry, style)
            except:
                pass

        with open(MASTER_LOG, "a") as f:
            f.write(log_entry + "\n")

    def save_telemetry(self):
        """
        Record build session data to a persistent JSON file.
        Includes durations for all completed packages and steps.
        """
        try:
            data = {}
            if os.path.exists(self.telemetry_file):
                with open(self.telemetry_file, "r") as f:
                    data = json.load(f)

            if self.session_id not in data:
                data[self.session_id] = {
                    "start_time": datetime.now().isoformat(),
                    "steps": {},
                }

            for step in self.engine.steps:
                if step.status != "pending":
                    data[self.session_id]["steps"][step.id] = {
                        "name": step.name,
                        "status": step.status,
                        "duration": step.duration(),
                        "packages": {pkg: dur for pkg, dur in step.packages_completed},
                    }

            with open(self.telemetry_file, "w") as f:
                json.dump(data, f, indent=4)
        except Exception as e:
            self.log(f"WARN: Failed to save telemetry: {str(e)}", "yellow")

    def download_missing_source(self, url):
        """Download a missing source file on behalf of the chroot environment."""
        import threading
        import subprocess

        def download_worker():
            try:
                filename = os.path.basename(url)
                self.log(
                    f"HOST_DOWNLOAD: Requesting {filename} on behalf of chroot...",
                    "bold yellow",
                )

                # Using wget on host for maximum reliability
                cmd = [
                    "wget",
                    "-4",
                    "--continue",
                    "--progress=bar:force:noscroll",
                    "-O",
                    os.path.join(self.engine.sources_dir, filename),
                    url,
                ]

                # Execute download
                subprocess.run(cmd, capture_output=True)
                self.log(f"HOST_DOWNLOAD: Succeeded for {filename}", "bold green")
            except Exception as e:
                self.log(f"HOST_DOWNLOAD: Failed: {str(e)}", "bold red")

        # Launch background downloader
        threading.Thread(target=download_worker, daemon=True).start()
