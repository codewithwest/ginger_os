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
import json
from datetime import datetime
from .constants import MASTER_LOG, LOG_DIR, GINGER_ROOT, STATE_DIR, SOURCES_DIR, LFS_MOUNT, BUILD_TYPE
from .models import BuildStep

class GingerEngine:
    """
    Core build engine for GingerOS.
    
    Manages the execution of build steps, process monitoring, logging,
    and user interaction via a keyboard listener.
    """

    def __init__(self, dry_run=False):
        """
        Initialize the build engine with defined steps and state.
        
        Sets up the build pipeline, initializing step objects, internal counters,
        and launching background threads for sudo keepalive and keyboard input.
        """
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
            BuildStep("12_chroot_mounts", "Mount Chroot", "sudo bash scripts/chroot.sh --mount-only", "Phase 3 System"),
            BuildStep("13_phase3_system", "System Build", "sudo chroot /mnt/lfs /bin/bash -c 'bash scripts/phases/build-phase3.sh'", "Phase 3 System"),
            
            # Kernel & Boot
            BuildStep("14_kernel", "Kernel Build", "sudo chroot /mnt/lfs /bin/bash -c 'bash scripts/phases/build-phase4.sh'", "Kernel & Boot"),
            BuildStep("15_finalize", "Finalize System", "bash scripts/host/finalize-system.sh", "Kernel & Boot"),
            BuildStep("16_teardown", "Teardown", "bash scripts/image/teardown.sh", "Kernel & Boot")
        ]
        self.dry_run = dry_run
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
        
        # Storage monitoring
        self.storage_stats = {"host": 0, "lfs": 0}
        
        # Regex for ANSI filtering
        self.ansi_escape = re.compile(r'(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]')
        # Filter for non-printable characters except newline and tab
        self.non_printable = re.compile(r'[^\x20-\x7E\n\t]')
        
        # Log rotation
        self._rotate_logs()
        
        # Keep sudo alive
        self.sudo_thread = threading.Thread(target=self._sudo_keepalive, daemon=True)
        self.sudo_thread.start()

        # Telemetry
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.telemetry_file = os.path.join(STATE_DIR, "telemetry.json")

        self.package_stepping = False
        self.paused_for_package = False
        self.current_process = None
        self.on_log_callbacks = []

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

    def toggle_pause(self):
        """Pause/Resume the build"""
        self.paused_for_error = not self.paused_for_error
        if self.paused_for_error:
            self.log("⏸ BUILD PAUSED (press SPACE to resume)", "bold yellow")
        else:
            self.log("▶ BUILD RESUMED", "bold green")
    
    def skip_to_next(self):
        """Skip to next step"""
        if self.current_step_idx < len(self.steps) - 1:
            self.current_step_idx += 1
            self.log(f"⏭ SKIPPED TO: {self.steps[self.current_step_idx].name}", "bold cyan")
        else:
            self.log("Already at last step", "yellow")
    
    def skip_current_step(self):
        """Mark current step as skipped and move to next"""
        if self.current_step_idx < len(self.steps):
            current = self.steps[self.current_step_idx]
            current.status = "completed"  # Mark as complete to skip
            self.log(f"⏭ SKIPPED: {current.name}", "bold yellow")
            self.skip_to_next()
    
    def jump_to_step(self):
        """Jump to a specific step (shows prompt)"""
        self.paused_for_error = True  # Pause to show prompt
        self.log("JUMP TO STEP: Enter step number (1-15):", "bold cyan")
        # Note: Actual input handling would need terminal restoration
        # For now, just log the option
    
    def show_steps_list(self):
        """Show list of all steps"""
        self.log("=" * 60, "dim")
        self.log("STEPS LIST:", "bold cyan")
        for idx, step in enumerate(self.steps, 1):
            status = "✓" if self._should_skip(step) else "○"
            self.log(f"  {status} [{idx:2d}] {step.name} ({step.phase})", "white")
        self.log("=" * 60, "dim")
    
    def show_help(self):
        """Show help information"""
        self.log("=" * 60, "dim")
        self.log("KEYBOARD SHORTCUTS:", "bold cyan")
        self.log("  SPACE - Pause/Resume build", "white")
        self.log("  N     - Skip to next step", "white")
        self.log("  S     - Skip current step", "white")
        self.log("  J     - Jump to specific step", "white")
        self.log("  L     - List all steps", "white")
        self.log("  ?     - Show this help", "white")
        self.log("  Q     - Quit build", "white")
        self.log("  R     - Restart phase (when paused on error)", "white")
        self.log("  P     - Restart package (when paused on error)", "white")
        self.log("=" * 60, "dim")


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

    def _update_storage(self):
        """Update storage usage percentages."""
        paths = {"host": "/", "lfs": "/mnt/lfs"}
        for key, path in paths.items():
            try:
                if os.path.exists(path):
                    st = os.statvfs(path)
                    used = (st.f_blocks - st.f_bfree)
                    total = st.f_blocks
                    if total > 0:
                        percent = (used / total) * 100
                        self.storage_stats[key] = percent
                        
                        # Emergency Autonomous Cleanup
                        if key == "host" and percent > 95:
                            # Only cleanup host sources if we are already in Phase 3 or 4
                            # because at that point, sources are already copied to LFS
                            if self.current_step_idx >= 12: # Phase 3 System or later
                                host_sources = os.path.join(GINGER_ROOT, "sources")
                                if os.path.exists(host_sources):
                                    self.log("CRITICAL: Host disk full! Purging host sources to survive...", "bold red")
                                    try:
                                        # We don't delete the dir, just the contents
                                        for f in os.listdir(host_sources):
                                            fpath = os.path.join(host_sources, f)
                                            if os.path.isfile(fpath): os.remove(fpath)
                                            elif os.path.isdir(fpath): shutil.rmtree(fpath)
                                        self.log("Emergency cleanup finished. Build will attempt to continue.", "green")
                                    except Exception as e:
                                        self.log(f"Emergency cleanup failed: {str(e)}", "bold red")
                else:
                    self.storage_stats[key] = 0
            except:
                self.storage_stats[key] = 0

    def _get_script_pkg_name(self, script_path):
        """Peeks into a script to find its PKG_NAME definition."""
        try:
            with open(script_path, 'r') as f:
                content = f.read()
                match = re.search(r'^PKG_NAME=["\'](.*)["\']', content, re.M)
                if match:
                    return match.group(1)
        except:
            pass
        return None

    def _check_phase_complete(self, script_subdir):
        """Helper to check if all scripts in a directory have corresponding central markers."""
        scripts_dir = os.path.join(GINGER_ROOT, "scripts", script_subdir)
        if not os.path.exists(scripts_dir):
            return False
            
        scripts = sorted([f for f in os.listdir(scripts_dir) if f.endswith(".sh")])
        if not scripts:
            return False
            
        for script in scripts:
            script_path = os.path.join(scripts_dir, script)
            pkg_name = self._get_script_pkg_name(script_path)
            file_name = script.replace(".sh", "")
            
            # For Phase 3/4, file names often have prefixes like 01-
            if script_subdir in ["phase3-system", "phase4-boot"]:
                file_name = "-".join(file_name.split("-")[1:]) if "-" in file_name else file_name

            # Prioritize the central host marker as the single source of truth
            possible_marker_names = [f"{file_name}.built", f"{file_name}-temp.built"]
            if pkg_name:
                possible_marker_names.extend([f"{pkg_name}.built", f"{pkg_name}-temp.built"])
            
            if not any(os.path.exists(os.path.join(STATE_DIR, m)) for m in possible_marker_names):
                return False
        return True

    def _should_skip(self, step):
        """
        Determines if a build step should be skipped based on markers or filesystem state.
        
        Args:
            step (BuildStep): The build step to check.
            
        Returns:
            bool: True if the step is already completed, False otherwise.
        """
        # 1. CRITICAL: Source Integrity Check (HOST SIDE)
        # If we are missing sources, we MUST NOT skip the download step, 
        # because the chroot doesn't have wget to fix it later.
        if step.id == "05_download_sources":
            sources_dir = os.path.join(GINGER_ROOT, "sources")
            if not os.path.exists(sources_dir) or len(os.listdir(sources_dir)) < 5:
                # Force re-download by removing the marker if it exists
                marker_path = os.path.join(STATE_DIR, f"{step.id}.built")
                if os.path.exists(marker_path):
                    try: os.remove(marker_path)
                    except: pass
                return False

        # 2. Direct marker check in the central state dir
        central_marker = os.path.join(STATE_DIR, f"{step.id}.built")
        if os.path.exists(central_marker):
            return True
            
        # 3. Smart checks for major phases (checks all constituent packages)
        if step.id == "10_phase1_toolchain":
            return self._check_phase_complete("phase1-tools")
        if step.id == "11_phase2_toolchain":
            return self._check_phase_complete("phase2-tools")
        if step.id == "13_phase3_system":
             return self._check_phase_complete("phase3-system")
        if step.id == "14_kernel":
             return self._check_phase_complete("phase4-boot")
             
        # 4. Dynamic state checks
        if step.id == "04_prepare_image":
            # Check if image is already mounted to LFS
            # CRITICAL FAILSAFE: Even if marker exists, if it's NOT mounted, we should NOT skip
            try:
                result = subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True, timeout=5)
                is_mounted = result.returncode == 0
                if not is_mounted:
                    return False
                return True # Marker exists AND is mounted
            except subprocess.TimeoutExpired:
                self.log(f"WARN: mountpoint check timed out for {LFS_MOUNT}", "yellow")
                return False
            except: return False
            
        if step.id == "12_chroot_mounts":
            # Check if chroot special filesystems are mounted
            # FAILSAFE: If marker exists but mounts are gone, do NOT skip
            try:
                result = subprocess.run(["grep", "-q", f"{LFS_MOUNT}/proc", "/proc/mounts"], capture_output=True, timeout=5)
                is_mounted = result.returncode == 0
                if not is_mounted:
                    return False
                return True # Marker exists AND chroot is mounted
            except subprocess.TimeoutExpired:
                return False
            except: return False

        return False

    def _sudo_keepalive(self):
        while not self.aborted:
            if not self.dry_run:
                subprocess.run(["sudo", "-v"], capture_output=True)
            time.sleep(60)

    def log(self, message, style=None):
        # Filter ANSI and non-printables
        message = self.ansi_escape.sub('', message)
        message = self.non_printable.sub('', message)
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.logs.append((log_entry, style))
        if len(self.logs) > self.max_logs:
            self.logs.pop(0)

        # Broadcast to Web UI
        for callback in self.on_log_callbacks:
            try:
                callback(log_entry, style)
            except:
                pass

        with open(MASTER_LOG, "a") as f:
            f.write(log_entry + "\n")

    def _ensure_lfs_mounted(self):
        """
        Verify that LFS_MOUNT is mounted. If not, automatically run
        the idempotent prepare-image step to recover the environment.
        
        Returns:
            bool: True if mounted (or successfully re-mounted), False otherwise.
        """
        if self.dry_run:
            return True
        try:
            result = subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True, timeout=5)
            if result.returncode == 0:
                return True
            
            if self.dry_run: return True
            
            # Mount lost! Behavior depends on BUILD_TYPE
            if BUILD_TYPE == "native":
                self.log(f"CRITICAL: LFS partition ({LFS_MOUNT}) is NOT mounted!", "bold red")
                self.log("On native servers, please mount your partition manually.", "yellow")
                return False

            # Image recovery
            self.log(f"WARN: LFS partition ({LFS_MOUNT}) is NOT mounted!", "yellow")
            self.log("Attempting automated mount recovery...", "bold cyan")
            
            # ... recovery steps ...
            prepare_step = next((s for s in self.steps if s.id == "04_prepare_image"), None)
            if not prepare_step:
                self.log("ERROR: Could not find Recovery Step (04_prepare_image)!", "bold red")
                return False
                
            # Run the idempotent script with a timeout to avoid hangs
            try:
                proc = subprocess.run(prepare_step.command, shell=True, cwd=GINGER_ROOT, capture_output=True, text=True, timeout=30)
                if proc.returncode == 0:
                    self.log("✅ Mount recovered successfully.", "bold green")
                    return True
                else:
                    self.log(f"❌ Automated recovery failed: {proc.stderr}", "bold red")
                    return False
            except subprocess.TimeoutExpired:
                self.log("❌ Automated recovery TIMED OUT (likely waiting for sudo).", "bold red")
                return False
        except Exception as e:
            self.log(f"!!! Error during mount check: {str(e)}", "bold red")
            return False

    def _save_telemetry(self):
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
                    "steps": {}
                }
            
            for step in self.steps:
                if step.status != "pending":
                    data[self.session_id]["steps"][step.id] = {
                        "name": step.name,
                        "status": step.status,
                        "duration": step.duration(),
                        "packages": {pkg: dur for pkg, dur in step.packages_completed}
                    }
            
            with open(self.telemetry_file, "w") as f:
                json.dump(data, f, indent=4)
        except Exception as e:
            self.log(f"WARN: Failed to save telemetry: {str(e)}", "yellow")

    def _verify_chroot_ready(self):
        """Verify chroot filesystems are mounted."""
        if self.dry_run:
            return True
        mounts = [f"{LFS_MOUNT}/proc", f"{LFS_MOUNT}/sys", f"{LFS_MOUNT}/dev"]
        try:
            with open("/proc/mounts", "r") as f:
                content = f.read()
                for m in mounts:
                    if m not in content:
                        self.log(f"CRITICAL: {m} is NOT mounted!", "bold red")
                        return False
            return True
        except:
            return False

    def _execute_step(self, step):
        """
        Execute a single build step in a subprocess.
        
        Handles:
        - Output capturing and logging
        - Real-time UI updates (via shared state)
        - Timeout enforcement
        - Error handling and status updates
        
        Args:
            step (BuildStep): The step to execute.
        """
        self.log(f"Starting step: {step.name}", "bold cyan")
        step.start_time = time.time()
        self.phase_start_time = step.start_time
        step.status = "running"
        self.logs = []  # Clear previous logs for this run
        self.aborted = False
        
        # Verify mount and chroot for dependent phases
        # Steps 07 (Host Setup) through 16 (Teardown) require the LFS disk to be mounted
        try:
            step_num = int(step.id.split('_')[0])
            if step_num >= 7 and step_num <= 16:
                if not self._ensure_lfs_mounted():
                    self.log(f"ERROR: Step {step.name} cannot proceed without LFS mount.", "bold red")
                    step.status = "failed"
                    return
        except (ValueError, IndexError):
            pass # Non-standard step ID, skip auto-mount check

        # Verify chroot for system phases
        if step.id in ["13_phase3_system", "14_kernel"]:
            if not self._verify_chroot_ready():
                self.log("WARN: Chroot environments are NOT mounted!", "yellow")
                self.log("Attempting automated chroot recovery...", "bold cyan")
                
                # Find the "chroot-mounts" step
                mount_step = next((s for s in self.steps if s.id == "12_chroot_mounts"), None)
                if mount_step:
                    # Run it once
                    proc = subprocess.run(mount_step.command, shell=True, cwd=GINGER_ROOT, capture_output=True, text=True)
                    if proc.returncode == 0:
                        self.log("✅ Chroot recovered successfully.", "bold green")
                    else:
                        self.log(f"❌ Chroot recovery failed: {proc.stderr}", "bold red")
                        step.status = "failed"
                        return
                
                # Re-verify after attempt
                if not self._verify_chroot_ready():
                    self.log("ERROR: Chroot still not ready. Please run 'Mount Chroot' step manually.", "bold red")
                    step.status = "failed"
                    return
        
        self.current_pkg = ""
        self.current_pkg_idx = 0
        self.total_pkg_count = 0
        self.pkg_start_time = None
        step.packages_completed = []
        
        self.log(f"Phase {step.phase}: Starting {step.name}...", "cyan")
        
        try:
            with open(step.log_file, "w") as f:
                f.write(f"--- GingerOS Step Log: {step.name} ---\n")
            
            # Execution logic
            if self.dry_run:
                self.log(f"[DRY-RUN] Would execute: {step.command}", "bold bright_yellow")
                process_returncode = 0
                last_output_time = time.time()
            else:
                        process = subprocess.Popen(
                            step.command,
                            cwd=GINGER_ROOT,
                            shell=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT,
                            text=True,
                            bufsize=1,  # Line buffered
                            env=os.environ.copy()
                        )
                        self.current_process = process
            
            # Read output with timeout
            import select
            last_output_time = time.time()
            IDLE_TIMEOUT = 600  # 10 minutes (configurable via constant eventually)

            if not self.dry_run:
                while True:
                    if self.aborted:
                        process.terminate()
                        break

                    # Check for output (non-blocking)
                    # We select on process.stdout
                    rlist, _, _ = select.select([process.stdout], [], [], 1.0) # 1 sec poll

                    if rlist:
                        # Output available - read line
                        line = process.stdout.readline()
                        if line:
                            last_output_time = time.time()
                            # Write exact raw line to log file
                            with open(step.log_file, "a") as f:
                                f.write(line)

                            # Clean for UI
                            # CRITICAL: Strip carriage returns for rich.Live safety
                            clean_line = line.replace('\r', '').strip()
                            clean_line = self.ansi_escape.sub('', clean_line)
                            clean_line = self.non_printable.sub('', clean_line)
                            
                            if clean_line:
                                # Periodically update storage info (non-blocking if possible)
                                if not hasattr(self, 'last_storage_update'): self.last_storage_update = 0
                                if time.time() - self.last_storage_update > 3.0:
                                    self._update_storage()
                                    self.last_storage_update = time.time()
                                
                                # Log to TUI panel (NO PRINT!)
                                # Special handling for useful keywords
                                style = "white"
                                lower_line = clean_line.lower()
                                
                                if any(kw in lower_line for kw in ["error", "fail", "denied", "critical", "fatal"]):
                                    style = "bold red"
                                elif "warning" in lower_line:
                                    style = "yellow"
                                elif "pass" in lower_line:
                                    style = "bold green"
                                elif "building" in lower_line or "starting" in lower_line:
                                    style = "bold cyan"
                                    # Extract package name for UI
                                    if "__GINGER_PKG_MARKER__" in line:
                                        self.current_pkg = line.split(":")[-1].strip()
                                elif "%" in clean_line: # Progress indicator
                                    style = "cyan"
                                
                                self.log(clean_line, style)

                                # Auto-Download Handler
                                if "__GINGER_MISSING_SOURCE_URL__:" in clean_line:
                                    url = clean_line.split("__GINGER_MISSING_SOURCE_URL__:")[-1].strip()
                                    self._download_missing_source(url)

                                # Package progress parsing (e.g. __GINGER_PKG_COUNT__: 3/17 : PackageName)
                                if "__GINGER_PKG_COUNT__:" in clean_line:
                                    try:
                                        parts = clean_line.split(":")
                                        count_part = parts[1].strip()
                                        pkg_name_part = parts[2].strip() if len(parts) > 2 else ""
                                        
                                        curr, total = count_part.split("/")
                                        self.current_pkg_idx = int(curr)
                                        self.total_pkg_count = int(total)
                                        
                                        if pkg_name_part:
                                            self.current_pkg = pkg_name_part.replace("(Skipped)", "").strip()
                                            # If it's not a skip message, mark start time if not already set for this package
                                            if "(Skipped)" not in pkg_name_part:
                                                if not self.pkg_start_time:
                                                    self.pkg_start_time = time.time()
                                    except:
                                        pass

                                # Package tracking
                                if clean_line.startswith("__GINGER_PKG_MARKER__:"):
                                    if self.current_pkg and self.pkg_start_time:
                                        duration = time.time() - self.pkg_start_time
                                        step.packages_completed.append((self.current_pkg, duration))
                                    
                                    pkg_name = clean_line.replace("__GINGER_PKG_MARKER__:", "").strip()
                                    self.current_pkg = pkg_name
                                    self.pkg_start_time = time.time()
                                    self.log(f"Building Package: {pkg_name}", "bold cyan")

                                    # Interactive Stepping
                                    if self.package_stepping and not self.dry_run:
                                        self.paused_for_package = True
                                        self.log(f"⏸ PAUSED before {pkg_name}. Press SPACE to continue.", "bold yellow")
                                        os.kill(process.pid, signal.SIGSTOP)
                                        while self.paused_for_package and not self.aborted:
                                            time.sleep(0.1)
                        else:
                            # EOF
                            if process.poll() is not None:
                                break
                    else:
                        # No output for 1 sec
                        if time.time() - last_output_time > IDLE_TIMEOUT:
                            self.log(f"ERROR: Step timed out after {IDLE_TIMEOUT}s of silence.", "bold red")
                            process.terminate()
                            process.wait() # Cleanup zombie
                            step.status = "failed"
                            return

                        if process.poll() is not None:
                            break
            
            if not self.dry_run:
                process.wait()
                process_returncode = process.returncode
            
            step.end_time = time.time()
            if self.current_pkg and self.pkg_start_time:
                duration = time.time() - self.pkg_start_time
                step.packages_completed.append((self.current_pkg, duration))
            
            if self.aborted:
                step.status = "failed"
                return
            
            if process_returncode == 0:
                step.status = "completed"
                # Persist the completion state only if NOT dry-run
                if not self.dry_run:
                    try:
                        marker_path = os.path.join(STATE_DIR, f"{step.id}.built")
                        with open(marker_path, "w") as f:
                            f.write(f"Completed at {datetime.now()}\n")
                    except: pass
                self.current_step_idx += 1
            else:
                step.status = "failed"
                if not self.dry_run:
                    self.log(f"✘ {step.name} FAILED with code {process.returncode}", "bold red")
                else:
                    self.log(f"✘ {step.name} simulated failure", "bold red")
                self.error_msg = f"{step.name} failed. Check {step.log_file}"
                
            self._save_telemetry()
            self.current_process = None
                
        except Exception as e:
            step.status = "failed"
            self.log(f"!!! EXCEPTION in {step.name}: {str(e)}", "bold red")
            self.error_msg = str(e)

    def resume_package(self):
        """Resume process from package-level pause."""
        if self.paused_for_package and self.current_process:
            os.kill(self.current_process.pid, signal.SIGCONT)
            self.paused_for_package = False
            return True
        return False


    def abort(self):
        """Abort the current build process."""
        self.aborted = True
        self.paused_for_package = False
        if self.current_process:
            try:
                self.current_process.terminate()
                self.current_process.wait(timeout=5)
            except:
                try: self.current_process.kill()
                except: pass
            self.current_process = None
    def _download_missing_source(self, url):
        """Attempts a host-side download using a background thread."""
        def download_worker():
            try:
                filename = os.path.basename(url)
                self.log(f"HOST_DOWNLOAD: Requesting {filename} on behalf of chroot...", "bold yellow")
                
                # Using wget on host for maximum reliability
                cmd = ["wget", "-4", "--continue", "--progress=bar:force:noscroll", "-O", os.path.join(SOURCES_DIR, filename), url]
                
                # Execute download
                subprocess.run(cmd, capture_output=True)
                self.log(f"HOST_DOWNLOAD: Succeeded for {filename}", "bold green")
            except Exception as e:
                self.log(f"HOST_DOWNLOAD: Failed: {str(e)}", "bold red")
        
        # Launch background downloader
        threading.Thread(target=download_worker, daemon=True).start()
