import os
import sys
import time
import subprocess
import threading
import signal
import re
import shutil
import termios
import tty
from datetime import datetime
from .constants import MASTER_LOG, LOG_DIR, GINGER_ROOT
from .models import BuildStep

class GingerEngine:
    def __init__(self):
        self.steps = [
            # Preparation Phase
            BuildStep("01_fix_repo", "Fix Repo Ownership", "sudo chown -R $(logname):$(logname) .git || true", "Preparation"),
            BuildStep("02_host_reqs", "Host Requirements", "bash ./scripts/host/host-requirements-install.sh", "Preparation"),
            BuildStep("03_version_check", "Version Check", "bash ./scripts/host/version-check.sh", "Preparation"),
            BuildStep("04_prepare_image", "Prepare Image", "bash ./scripts/image/prepare-image.sh", "Preparation"),
            BuildStep("05_download_sources", "Download Sources", "bash ./scripts/host/download.sh", "Preparation"),
            # BuildStep("06_fix_source_perms", "Fix Source Perms", "sudo chown -R lfs:lfs /mnt/lfs/sources && sudo chmod -R 775 /mnt/lfs/sources", "Preparation"),
            BuildStep("07_host_setup", "Host Setup", "bash ./scripts/host/setup-host.sh", "Preparation"),
            BuildStep("08_update_dir", "Update Directories", "bash ./scripts/host/update-dir.sh", "Preparation"),
            
            # Host Tools Phase
            BuildStep("09_setup_lfs_env", "Setup LFS Environment", "bash scripts/host/run-as-lfs.sh ./scripts/phases/setup-lfs-user-env.sh", "Host Tools"),
            
            # Phase 1 Toolchain
            BuildStep("10_phase1_toolchain", "Toolchain Build", "bash scripts/host/run-as-lfs.sh ./scripts/phases/build-phase1.sh", "Phase 1 Toolchain"),
            
            # Phase 2 Cross Tools
            BuildStep("11_phase2_toolchain", "Cross Tools Build", "bash scripts/host/run-as-lfs.sh ./scripts/phases/build-phase2.sh", "Phase 2 Cross Tools"),
            
            # Phase 3 System
            BuildStep("12_chroot_mounts", "Mount Chroot", "bash chroot.sh", "Phase 3 System"),
            BuildStep("13_phase3_system", "System Build", "sudo chroot /mnt/lfs /bin/bash -c 'bash scripts/phases/build-phase3.sh'", "Phase 3 System"),
            
            # Kernel & Boot
            BuildStep("14_kernel", "Kernel Build", "sudo chroot /mnt/lfs /bin/bash -c 'bash scripts/phases/build-phase4.sh'", "Kernel & Boot"),
            BuildStep("15_grub", "Grub Setup", "bash scripts/phase4-boot/02-grub.sh", "Kernel & Boot"),
            BuildStep("16_teardown", "Teardown", "bash scripts/image/teardown.sh", "Kernel & Boot")
        ]
        self.current_step_idx = 0
        self.current_pkg = ""
        self.pkg_start_time = None
        self.phase_start_time = None
        self.overall_start_time = None
        self.logs = []
        self.max_logs = 100
        self.is_running = False
        self.aborted = False
        self.error_msg = ""
        self.paused_for_error = False
        
        # Regex for ANSI filtering
        self.ansi_escape = re.compile(r'(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]')
        
        # Log rotation
        self._rotate_logs()
        
        # Keep sudo alive
        self.sudo_thread = threading.Thread(target=self._sudo_keepalive, daemon=True)
        
        # Keyboard listener
        self.kb_thread = threading.Thread(target=self._kb_listener, daemon=True)

    def _kb_listener(self):
        """Listen for R and P keys when paused."""
        # Note: We use a non-blocking way to avoid terminal resource fighting
        while not self.aborted:
            if self.paused_for_error:
                # Only try to read if we are actually paused
                # This minimizes the window for terminal conflicts
                fd = sys.stdin.fileno()
                try:
                    old_settings = termios.tcgetattr(fd)
                    tty.setraw(fd)
                    # Small timeout read
                    char = sys.stdin.read(1).lower()
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                    
                    if char == 'r':
                        self.restart_phase()
                    elif char == 'p':
                        self.restart_package()
                    elif char == '\x03': # Ctrl+C
                        self.abort()
                        break
                except:
                    pass
            time.sleep(0.5)

    def _rotate_logs(self):
        """Clean up old logs or rotate master log if too big."""
        if os.path.exists(MASTER_LOG):
            if os.path.getsize(MASTER_LOG) > 50 * 1024 * 1024:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                shutil.move(MASTER_LOG, f"{MASTER_LOG}.{timestamp}.bak")
                with open(MASTER_LOG, "w") as f:
                    f.write(f"--- GingerOS Master Log Rotated at {timestamp} ---\n")
        
        all_logs = sorted([os.path.join(LOG_DIR, f) for f in os.listdir(LOG_DIR) if f.endswith(".log")])
        if len(all_logs) > 50:
            for old_log in all_logs[:-50]:
                try:
                    os.remove(old_log)
                except: pass

    def restart_phase(self):
        self.log("RESTARTING PHASE...", "bold yellow")
        self.paused_for_error = False

    def restart_package(self):
        if not self.current_pkg:
            self.log("Cannot restart package: Unknown current package", "bold red")
            return
            
        self.log(f"RESTARTING PACKAGE: {self.current_pkg}...", "bold yellow")
        marker_paths = [
            f"/mnt/lfs/var/lib/ginger/{self.current_pkg}.built",
            f"/var/lib/ginger/{self.current_pkg}.built"
        ]
        for path in marker_paths:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except: pass
        self.paused_for_error = False

    def _sudo_keepalive(self):
        while True:
            subprocess.run(["sudo", "-v"], capture_output=True)
            time.sleep(60)

    def log(self, message, style=None):
        message = self.ansi_escape.sub('', message)
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.logs.append((log_entry, style))
        if len(self.logs) > self.max_logs:
            self.logs.pop(0)
        with open(MASTER_LOG, "a") as f:
            f.write(log_entry + "\n")

    def run(self):
        # State should already be set by caller, but we'll ensure it here
        self.is_running = True
        self.overall_start_time = time.time()
        self.sudo_thread.start()
        self.kb_thread.start()
        self.log("Starting GingerOS Build Engine...", "bold green")
        
        while self.current_step_idx < len(self.steps):
            if self.aborted: break
            step = self.steps[self.current_step_idx]
            step.status = "running"
            step.start_time = time.time()
            self.phase_start_time = step.start_time
            self.current_pkg = ""
            self.pkg_start_time = None
            step.packages_completed = []
            
            self.log(f"Phase {step.phase}: Starting {step.name}...", "cyan")
            
            try:
                with open(step.log_file, "w") as f:
                    f.write(f"--- GingerOS Step Log: {step.name} ---\n")
                
                process = subprocess.Popen(
                    step.command,
                    shell=True,
                    cwd=GINGER_ROOT,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    env=os.environ.copy()
                )
                
                for line in iter(process.stdout.readline, ""):
                    if self.aborted:
                        process.terminate()
                        break
                    if line:
                        stripped = line.strip()
                        clean_line = self.ansi_escape.sub('', stripped)
                        if clean_line.startswith("GINGER_PKG:"):
                            if self.current_pkg and self.pkg_start_time:
                                duration = time.time() - self.pkg_start_time
                                step.packages_completed.append((self.current_pkg, duration))
                            self.current_pkg = clean_line.replace("GINGER_PKG:", "").strip()
                            self.pkg_start_time = time.time()
                            self.log(f"Building: {self.current_pkg}", "bold cyan")
                        
                        with open(step.log_file, "a") as f:
                            f.write(line)
                        
                        if any(kw in clean_line.lower() for kw in ["error", "warning", "installing", "building", "configuring", "checking"]):
                            if not clean_line.startswith("GINGER_PKG:"):
                                self.log(f"  {clean_line[:80]}", "dim")
                
                process.wait()
                step.end_time = time.time()
                if self.current_pkg and self.pkg_start_time:
                    duration = time.time() - self.pkg_start_time
                    step.packages_completed.append((self.current_pkg, duration))
                
                if self.aborted:
                    step.status = "failed"
                    break
                
                if process.returncode == 0:
                    step.status = "completed"
                    self.current_step_idx += 1
                else:
                    step.status = "failed"
                    self.log(f"✘ {step.name} FAILED with code {process.returncode}", "bold red")
                    self.error_msg = f"{step.name} failed. Check {step.log_file}"
                    self.paused_for_error = True
                    while self.paused_for_error and not self.aborted:
                        time.sleep(0.5)
                    if self.aborted: break
                    continue
            except Exception as e:
                step.status = "failed"
                self.log(f"!!! EXCEPTION in {step.name}: {str(e)}", "bold red")
                self.paused_for_error = True
                while self.paused_for_error and not self.aborted:
                    time.sleep(0.5)
                if self.aborted: break
                continue
        
        self.is_running = False

    def abort(self):
        self.aborted = True
        self.is_running = False
        self.paused_for_error = False
