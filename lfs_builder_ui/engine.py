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
from .constants import MASTER_LOG, LOG_DIR, GINGER_ROOT, STATE_DIR, LFS_MOUNT
from .models import BuildStep

class GingerEngine:
    """
    Core build engine for GingerOS.
    
    Manages the execution of build steps, process monitoring, logging,
    and user interaction via a keyboard listener.
    """

    def __init__(self):
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
        
        # Keyboard listener
        self.kb_thread = threading.Thread(target=self._kb_listener, daemon=True)

        # Telemetry
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.telemetry_file = os.path.join(STATE_DIR, "telemetry.json")

    def _kb_listener(self):
        """Listen for keyboard commands during build."""
        import select
        
        while not self.aborted:
            # Check if there's input available (non-blocking)
            if select.select([sys.stdin], [], [], 0.1)[0]:
                fd = sys.stdin.fileno()
                try:
                    old_settings = termios.tcgetattr(fd)
                    tty.setcbreak(fd)  # Use cbreak instead of raw for better control
                    char = sys.stdin.read(1).lower()
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                    
                    # Error recovery keys (when paused)
                    if self.paused_for_error:
                        if char == 'r':
                            self.restart_phase()
                        elif char == 'p':
                            self.restart_package()
                        elif char == ' ' or char == '\r' or char == '\n':  # SPACE or ENTER
                            self.paused_for_error = False
                            self.log("▶ BUILD STARTED/RESUMED", "bold green")
                        elif char == '\x03':  # Ctrl+C
                            self.abort()
                            break
                    
                    # Interactive control keys (during normal operation)
                    elif self.is_running:
                        if char == ' ':  # SPACE - Pause/Resume
                            self.toggle_pause()
                        elif char == 'n':  # N - Next step
                            self.skip_to_next()
                        elif char == 's':  # S - Skip current step
                            self.skip_current_step()
                        elif char == 'j':  # J - Jump to step
                            self.jump_to_step()
                        elif char == 'l':  # L - List steps
                            self.show_steps_list()
                        elif char == '?':  # ? - Help
                            self.show_help()
                        elif char == 'q':  # Q - Quit
                            self.abort()
                            break
                        elif char == '\x03':  # Ctrl+C
                            self.abort()
                            break
                except:
                    pass
            time.sleep(0.1)

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

    def _check_phase_complete(self, script_subdir, marker_dir):
        """Helper to check if all scripts in a directory have corresponding markers."""
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

            possible_markers = [
                os.path.join(marker_dir, f"{file_name}.built"),
                os.path.join(marker_dir, f"{file_name}-temp.built")
            ]
            if pkg_name:
                possible_markers.extend([
                    os.path.join(marker_dir, f"{pkg_name}.built"),
                    os.path.join(marker_dir, f"{pkg_name}-temp.built")
                ])
            
            if not any(os.path.exists(m) for m in possible_markers):
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
            
        # 3. Smart checks for major phases
        lfs_marker_dir = f"{LFS_MOUNT}/var/lib/ginger"
        if step.id == "10_phase1_toolchain":
            return self._check_phase_complete("phase1-tools", lfs_marker_dir)
        if step.id == "11_phase2_toolchain":
            return self._check_phase_complete("phase2-tools", lfs_marker_dir)
        if step.id == "13_phase3_system":
             return self._check_phase_complete("phase3-system", lfs_marker_dir)
        if step.id == "14_kernel":
             return self._check_phase_complete("phase4-boot", lfs_marker_dir)
             
        # 4. Dynamic state checks
        if step.id == "04_prepare_image":
            # Check if image is already mounted to LFS
            # CRITICAL FAILSAFE: Even if marker exists, if it's NOT mounted, we should NOT skip
            try:
                result = subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True)
                is_mounted = result.returncode == 0
                if not is_mounted:
                    return False
                return True # Marker exists AND is mounted
            except: return False
            
        if step.id == "12_chroot_mounts":
            # Check if chroot special filesystems are mounted
            # FAILSAFE: If marker exists but mounts are gone, do NOT skip
            try:
                result = subprocess.run(["grep", "-q", f"{LFS_MOUNT}/proc", "/proc/mounts"], capture_output=True)
                is_mounted = result.returncode == 0
                if not is_mounted:
                    return False
                return True # Marker exists AND chroot is mounted
            except: return False

        return False

    def _sudo_keepalive(self):
        while True:
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
        with open(MASTER_LOG, "a") as f:
            f.write(log_entry + "\n")

    def _ensure_lfs_mounted(self):
        """
        Verify that LFS_MOUNT is mounted. If not, automatically run
        the idempotent prepare-image step to recover the environment.
        
        Returns:
            bool: True if mounted (or successfully re-mounted), False otherwise.
        """
        try:
            result = subprocess.run(["mountpoint", "-q", LFS_MOUNT], capture_output=True)
            if result.returncode == 0:
                return True
            
            # Mount lost! Attempt automatic recovery.
            self.log(f"WARN: LFS partition ({LFS_MOUNT}) is NOT mounted!", "yellow")
            self.log("Attempting automated mount recovery...", "bold cyan")
            
            # Find the "prepare-image" step
            prepare_step = next((s for s in self.steps if s.id == "04_prepare_image"), None)
            if not prepare_step:
                self.log("ERROR: Could not find Recovery Step (04_prepare_image)!", "bold red")
                return False
                
            # Run the idempotent script directly
            # We don't use _execute_step here to avoid recursion/state mess
            proc = subprocess.run(prepare_step.command, shell=True, cwd=GINGER_ROOT, capture_output=True, text=True)
            if proc.returncode == 0:
                self.log("✅ Mount recovered successfully.", "bold green")
                return True
            else:
                self.log(f"❌ Automated recovery failed: {proc.stderr}", "bold red")
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
        self.pkg_start_time = None
        step.packages_completed = []
        
        self.log(f"Phase {step.phase}: Starting {step.name}...", "cyan")
        
        try:
            with open(step.log_file, "w") as f:
                f.write(f"--- GingerOS Step Log: {step.name} ---\n")
            
            # Use Popen to capture output in real-time
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
            
            # Read output with timeout
            import select
            last_output_time = time.time()
            IDLE_TIMEOUT = 600  # 10 minutes (configurable via constant eventually)

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
                            
                            if "error" in lower_line or "fail" in lower_line:
                                style = "bold red"
                            elif "warning" in lower_line:
                                style = "yellow"
                            elif "pass" in lower_line:
                                style = "bold green"
                            elif "%" in clean_line: # Progress
                                style = "cyan"
                            
                            self.log(clean_line, style)

                            # Package tracking
                            if clean_line.startswith("__GINGER_PKG_MARKER__:"):
                                if self.current_pkg and self.pkg_start_time:
                                    duration = time.time() - self.pkg_start_time
                                    step.packages_completed.append((self.current_pkg, duration))
                                
                                pkg_name = clean_line.replace("__GINGER_PKG_MARKER__:", "").strip()
                                self.current_pkg = pkg_name
                                self.pkg_start_time = time.time()
                                self.log(f"Building Package: {pkg_name}", "bold cyan")
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
            
            process.wait()
            step.end_time = time.time()
            if self.current_pkg and self.pkg_start_time:
                duration = time.time() - self.pkg_start_time
                step.packages_completed.append((self.current_pkg, duration))
            
            if self.aborted:
                step.status = "failed"
                return
            
            if process.returncode == 0:
                step.status = "completed"
                # Persist the completion state
                try:
                    marker_path = os.path.join(STATE_DIR, f"{step.id}.built")
                    with open(marker_path, "w") as f:
                        f.write(f"Completed at {datetime.now()}\n")
                except: pass
            else:
                step.status = "failed"
                self.log(f"✘ {step.name} FAILED with code {process.returncode}", "bold red")
                self.error_msg = f"{step.name} failed. Check {step.log_file}"
                
            self._save_telemetry()
                
        except Exception as e:
            step.status = "failed"
            self.log(f"!!! EXCEPTION in {step.name}: {str(e)}", "bold red")
            self.error_msg = str(e)

    def run(self):
        """
        Main execution loop for the build engine.
        
        Iterates through the defined steps, skipping completed ones,
        and executing pending ones. Handles the overall flow control,
        including pauses and aborts.
        """
        # State should already be set by caller, but we'll ensure it here
        self.is_running = True
        self.overall_start_time = time.time()
        self.sudo_thread.start()
        self.kb_thread.start()
        self.log("Starting GingerOS Build Engine...", "bold green")
        
        while self.current_step_idx < len(self.steps):
            if self.aborted: break
            step = self.steps[self.current_step_idx]
            
            # Smart skipping check
            if self._should_skip(step):
                self.log(f"Step '{step.name}' already complete. Skipping.", "green")
                step.status = "completed"
                self.current_step_idx += 1
                continue

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
                        # CRITICAL: Strip carriage returns which mess up rich.Live
                        stripped = line.replace('\r', '').strip()
                        clean_line = self.ansi_escape.sub('', stripped)
                        clean_line = self.non_printable.sub('', clean_line)
                        
                        # Periodically update storage info
                        if time.time() % 3 < 0.1:
                            self._update_storage()

                        if clean_line.startswith("GINGER_PKG:"):
                            if self.current_pkg and self.pkg_start_time:
                                duration = time.time() - self.pkg_start_time
                                step.packages_completed.append((self.current_pkg, duration))
                            self.current_pkg = clean_line.replace("GINGER_PKG:", "").strip()
                            self.pkg_start_time = time.time()
                            self.log(f"Building: {self.current_pkg}", "bold cyan")
                        
                        with open(step.log_file, "a") as f:
                            f.write(line)
                        
                        # Only show very specific, safe keywords in the UI to avoid clutter/corruption
                        if any(kw in clean_line.lower() for kw in ["error", "warning", "waiting", "checking", "..."]):
                            if not clean_line.startswith("GINGER_PKG:"):
                                self.log(f"  {clean_line[:100]}", "dim")
                
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
                    # Persist the completion state
                    try:
                        marker_path = os.path.join(STATE_DIR, f"{step.id}.built")
                        with open(marker_path, "w") as f:
                            f.write(f"Completed at {datetime.now()}\n")
                    except: pass
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
        self._save_telemetry()

    def abort(self):
        self.aborted = True
        self.is_running = False
        self.paused_for_error = False
