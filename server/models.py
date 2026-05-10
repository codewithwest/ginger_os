import os
import time
from config.constants import LOG_DIR


class BuildStep:
    def __init__(self, id: str, name: str, command: str, phase: str = "General"):
        self.id = id
        self.name = name
        self.command = command
        self.phase = phase
        self.status = "pending"  # pending, running, completed, failed
        self.start_time = None
        self.end_time = None
        self.log_file = os.path.join(LOG_DIR, f"{id}.log")
        self.packages_completed = []  # List of (name, duration)

    def duration(self):
        if self.start_time and self.end_time:
            return self.end_time - self.start_time
        if self.start_time:
            return time.time() - self.start_time
        return 0

    @property
    def progress(self):
        if self.status == "completed":
            return 100
        if self.status == "running" and self.start_time:
            return 50  # indeterminate — midpoint until package-level tracking is wired
        return 0
