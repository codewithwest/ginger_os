"""
Process execution and monitoring for build steps.
"""

import os
import time
import signal
import select
import subprocess
import re


class ProcessMonitor:
    """
    Handles execution and monitoring of build processes.
    """

    def __init__(self, engine):
        self.engine = engine
        self.ansi_escape = re.compile(r"(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]")
        self.non_printable = re.compile(r"[^\x20-\x7E\n\t]")

    def execute_step(self, step, pkg: str = None):
        """
        Execute a single build step in a subprocess.

        Args:
            step: The BuildStep to execute
            pkg: Optional specific package to target

        Returns:
            int: Process return code
        """
        target_name = f"{step.name} (Package: {pkg})" if pkg else step.name
        self.engine.log(f"Starting step: {target_name}", "bold cyan")
        step.start_time = time.time()
        self.engine.phase_start_time = step.start_time
        if self.engine.overall_start_time is None:
            self.engine.overall_start_time = step.start_time
        step.status = "running"
        self.engine.logs = []  # Clear previous logs for this run
        self.engine.aborted = False

        # Initialize package tracking
        self.engine.current_pkg = ""
        self.engine.current_pkg_idx = 0
        self.engine.total_pkg_count = 0
        self.engine.pkg_start_time = None
        step.packages_completed = []

        self.engine.log(f"Phase {step.phase}: Starting {target_name}...", "cyan")

        try:
            with open(step.log_file, "w") as f:
                f.write(f"--- GingerOS Step Log: {target_name} ---\n")

            cmd = step.command
            if pkg:
                cmd = f"{cmd} {pkg}"

            if self.engine.dry_run:
                self.engine.log(f"[DRY-RUN] Would execute: {cmd}", "bold bright_yellow")
                return 0

            # Prepare environment with core allocation
            env = os.environ.copy()
            cores_val = str(getattr(self.engine, "cores", 1))
            env["GINGER_CORES"] = cores_val
            env["MAKEFLAGS"] = f"-j{cores_val}"

            # Start the process
            process = subprocess.Popen(
                cmd,
                cwd=self.engine.ginger_root,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,  # Line buffered
                env=env,
            )
            self.engine.current_process = process

            # Monitor output with timeout
            return self._monitor_process_output(process, step)

        except Exception as e:
            self.engine.log(f"Step execution error: {str(e)}", "bold red")
            step.status = "failed"
            return 1

    def _monitor_process_output(self, process, step):
        """
        Monitor process output with timeout and real-time logging.

        Args:
            process: The subprocess to monitor
            step: The BuildStep being executed

        Returns:
            int: Process return code
        """
        last_output_time = time.time()
        IDLE_TIMEOUT = 600  # 10 minutes

        while True:
            if self.engine.aborted:
                process.terminate()
                break

            # Check for output (non-blocking)
            rlist, _, _ = select.select([process.stdout], [], [], 1.0)

            if rlist:
                line = process.stdout.readline()
                if line:
                    last_output_time = time.time()
                    # Write to log file
                    with open(step.log_file, "a") as f:
                        f.write(line)

                    # Process line for UI
                    clean_line = self._clean_line_for_ui(line)
                    if clean_line:
                        self._update_storage_periodically()
                        self._process_log_line(clean_line, step)
                else:
                    # EOF
                    if process.poll() is not None:
                        break
            else:
                # No output for 1 sec
                if time.time() - last_output_time > IDLE_TIMEOUT:
                    self.engine.log(
                        f"ERROR: Step timed out after {IDLE_TIMEOUT}s of silence.",
                        "bold red",
                    )
                    process.terminate()
                    process.wait()
                    step.status = "failed"
                    return 1

                if process.poll() is not None:
                    break

        # Wait for process completion
        process.wait()

        # Finalize package tracking
        if self.engine.current_pkg and self.engine.pkg_start_time:
            duration = time.time() - self.engine.pkg_start_time
            step.packages_completed.append((self.engine.current_pkg, duration))

        step.end_time = time.time()

        if self.engine.aborted:
            step.status = "failed"
            return 1

        return process.returncode

    def _clean_line_for_ui(self, line):
        """Clean a line for UI display by removing ANSI codes and non-printables."""
        # Strip carriage returns for rich.Live safety
        clean_line = line.replace("\r", "").strip()
        clean_line = self.ansi_escape.sub("", clean_line)
        clean_line = self.non_printable.sub("", clean_line)
        return clean_line

    def _update_storage_periodically(self):
        """Update storage info periodically."""
        if not hasattr(self.engine, "last_storage_update"):
            self.engine.last_storage_update = 0
        if time.time() - self.engine.last_storage_update > 3.0:
            self.engine._update_storage()
            self.engine.last_storage_update = time.time()

    def _process_log_line(self, line, step):
        """Process a log line for special handling and UI updates."""
        style = self._determine_line_style(line)
        self.engine.log(line, style)

        # Handle special markers
        self._handle_special_markers(line, step)

    def _determine_line_style(self, line):
        """Determine the style for a log line based on content."""
        lower_line = line.lower()

        if any(
            kw in lower_line for kw in ["error", "fail", "denied", "critical", "fatal"]
        ):
            return "bold red"
        elif "warning" in lower_line:
            return "yellow"
        elif "pass" in lower_line:
            return "bold green"
        elif "building" in lower_line or "starting" in lower_line:
            return "bold cyan"
        elif "%" in line:  # Progress indicator
            return "cyan"
        else:
            return "white"

    def _handle_special_markers(self, line, step):
        """Handle special markers in log output."""
        # Package completion/start marker
        if line.startswith("__GINGER_PKG_MARKER__:"):
            self._handle_package_completion(step, line)

        # Package count marker
        elif "__GINGER_PKG_COUNT__:" in line:
            self._parse_package_count(line)

        # Missing source URL
        elif "__GINGER_MISSING_SOURCE_URL__:" in line:
            url = line.split("__GINGER_MISSING_SOURCE_URL__:")[-1].strip()
            self.engine._download_missing_source(url)

    def _parse_package_count(self, line):
        """Parse package count information from log line."""
        try:
            parts = line.split(":")
            count_part = parts[1].strip()
            pkg_name_part = parts[2].strip() if len(parts) > 2 else ""

            curr, total = count_part.split("/")
            self.engine.current_pkg_idx = int(curr)
            self.engine.total_pkg_count = int(total)

            if pkg_name_part:
                self.engine.current_pkg = pkg_name_part.replace("(Skipped)", "").strip()
                if "(Skipped)" not in pkg_name_part and not self.engine.pkg_start_time:
                    self.engine.pkg_start_time = time.time()
        except:
            pass

    def _handle_package_completion(self, step, line):
        """Handle package completion marker."""
        if self.engine.current_pkg and self.engine.pkg_start_time:
            duration = time.time() - self.engine.pkg_start_time
            step.packages_completed.append((self.engine.current_pkg, duration))

        pkg_name = line.replace("__GINGER_PKG_MARKER__:", "").strip()
        self.engine.current_pkg = pkg_name
        self.engine.pkg_start_time = time.time()
        self.engine.log(f"Building Package: {pkg_name}", "bold cyan")

        # Interactive stepping
        if self.engine.package_stepping and not self.engine.dry_run:
            self._handle_package_stepping(pkg_name)

    def _handle_package_stepping(self, pkg_name):
        """Handle interactive package stepping."""
        self.engine.paused_for_package = True
        self.engine.log(
            f"⏸ PAUSED before {pkg_name}. Press SPACE to continue.",
            "bold yellow",
        )
        if self.engine.current_process:
            os.kill(self.engine.current_process.pid, signal.SIGSTOP)
            while self.engine.paused_for_package and not self.engine.aborted:
                time.sleep(0.1)
