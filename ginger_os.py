
import os
import sys
import time
import subprocess
import threading
import signal
from datetime import datetime
import re
import termios
import tty
from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.live import Live
from rich.table import Table
from rich.progress import Progress, BarColumn, TextColumn, SpinnerColumn
from rich.text import Text
from rich.align import Align
from rich.columns import Columns

# ============================================================================
# CONFIGURATION
# ============================================================================

GINGER_ROOT = os.path.dirname(os.path.abspath(__file__))
STATE_DIR = os.path.join(GINGER_ROOT, ".build_state")
LOG_DIR = os.path.join(GINGER_ROOT, "logs")
MASTER_LOG = os.path.join(STATE_DIR, "ginger_os_build.log")

# Create directories
os.makedirs(STATE_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

# Colors & Style
ELECTRIC_BLUE = "#268bd2"
LASER_GREEN = "#859900"
LASER_RED = "#dc322f"
LASER_YELLOW = "#b58900"

# ASCII Logo
LOGO = """
  _____ _                         ____   ____
 / ____(_)                       / __ \\ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \\ / _` |/ _ \\ '__|| |  | |\\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ 
                 __/ |                         
                |___/         v1.0 [Python]
"""

# ============================================================================
# DATA MODELS
# ============================================================================

class BuildStep:
    def __init__(self, id, name, command, phase="General"):
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

# ============================================================================
# ENGINE
# ============================================================================

class GingerEngine:
    def __init__(self):
        self.steps = [
            # Preparation Phase
            BuildStep("01_permissions", "Set Permissions", "chmod -R 755 .", "Preparation"),
            BuildStep("02_host_reqs", "Host Requirements", "bash ./scripts/host/host-requirements-install.sh", "Preparation"),
            BuildStep("03_version_check", "Version Check", "bash ./scripts/host/version-check.sh", "Preparation"),
            BuildStep("04_prepare_image", "Prepare Image", "bash ./scripts/image/prepare-image.sh", "Preparation"),
            BuildStep("05_download_sources", "Download Sources", "bash ./scripts/host/download.sh", "Preparation"),
            BuildStep("06_host_setup", "Host Setup", "bash ./scripts/host/setup-host.sh", "Preparation"),
            BuildStep("07_update_dir", "Update Directories", "bash ./scripts/host/update-dir.sh", "Preparation"),
            
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
        
        # Keep sudo alive
        self.sudo_thread = threading.Thread(target=self._sudo_keepalive, daemon=True)
        
        # Keyboard listener
        self.kb_thread = threading.Thread(target=self._kb_listener, daemon=True)

    def _kb_listener(self):
        """Listen for R and P keys when paused."""
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(sys.stdin.fileno())
            while True:
                char = sys.stdin.read(1).lower()
                if self.paused_for_error:
                    if char == 'r':
                        self.restart_phase()
                    elif char == 'p':
                        self.restart_package()
                if char == '\x03': # Ctrl+C
                    os.kill(os.getpid(), signal.SIGINT)
                    break
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    def restart_phase(self):
        self.log("RESTARTING PHASE...", "bold yellow")
        # Just unpause, the run loop stays at current_step_idx
        self.paused_for_error = False

    def restart_package(self):
        if not self.current_pkg:
            self.log("Cannot restart package: Unknown current package", "bold red")
            return
            
        self.log(f"RESTARTING PACKAGE: {self.current_pkg}...", "bold yellow")
        
        # Determine marker file location
        # Phase 1/2 use /mnt/lfs/var/lib/ginger
        # Phase 3 uses /var/lib/ginger (inside chroot)
        # We'll try to delete both or use common knowledge
        marker_paths = [
            f"/mnt/lfs/var/lib/ginger/{self.current_pkg}.built",
            f"/var/lib/ginger/{self.current_pkg}.built"
        ]
        
        deleted = False
        for path in marker_paths:
            if os.path.exists(path):
                try:
                    os.remove(path)
                    self.log(f"Deleted marker: {path}", "dim")
                    deleted = True
                except Exception as e:
                    self.log(f"Failed to delete marker {path}: {str(e)}", "red")
        
        if not deleted:
            self.log("No marker file found to delete. Restarting script anyway...", "dim")
            
        self.paused_for_error = False

    def _sudo_keepalive(self):
        while True:
            subprocess.run(["sudo", "-v"], capture_output=True)
            time.sleep(60)

    def log(self, message, style=None):
        # Filter ANSI codes
        message = self.ansi_escape.sub('', message)
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.logs.append((log_entry, style))
        if len(self.logs) > self.max_logs:
            self.logs.pop(0)
        
        # Write to master log
        with open(MASTER_LOG, "a") as f:
            f.write(log_entry + "\n")

    def run(self):
        self.is_running = True
        self.overall_start_time = time.time()
        self.sudo_thread.start()
        self.kb_thread.start()
        self.log("Starting GingerOS Build Engine...", "bold green")
        
        while self.current_step_idx < len(self.steps):
            if self.aborted:
                break
                
            step = self.steps[self.current_step_idx]
            step.status = "running"
            step.start_time = time.time()
            self.phase_start_time = step.start_time
            self.current_pkg = ""
            self.pkg_start_time = None
            step.packages_completed = []
            
            self.log(f"Phase {step.phase}: Starting {step.name}...", "cyan")
            
            try:
                # Ensure log file exists and is empty
                with open(step.log_file, "w") as f:
                    f.write(f"--- GingerOS Step Log: {step.name} ---\n")
                
                # Run the command
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
                
                # Monitor output
                for line in iter(process.stdout.readline, ""):
                    if self.aborted:
                        process.terminate()
                        break
                    if line:
                        stripped = line.strip()
                        # Clean line for internal processing
                        clean_line = self.ansi_escape.sub('', stripped)
                        
                        # Check for package marker
                        if clean_line.startswith("GINGER_PKG:"):
                            # If we were tracking a package, record its end
                            if self.current_pkg and self.pkg_start_time:
                                duration = time.time() - self.pkg_start_time
                                step.packages_completed.append((self.current_pkg, duration))
                            
                            self.current_pkg = clean_line.replace("GINGER_PKG:", "").strip()
                            self.pkg_start_time = time.time()
                            self.log(f"Building: {self.current_pkg}", "bold cyan")
                        
                        # Only log to UI if it's not too chatty, but always log to file
                        with open(step.log_file, "a") as f:
                            f.write(line)
                        
                        # Show some filtered output in UI logs
                        if any(kw in clean_line.lower() for kw in ["error", "warning", "installing", "building", "configuring", "checking"]):
                            if not clean_line.startswith("GINGER_PKG:"):
                                self.log(f"  {clean_line[:80]}", "dim")
                
                process.wait()
                step.end_time = time.time()
                
                # Record the last package's duration if applicable
                if self.current_pkg and self.pkg_start_time:
                    duration = time.time() - self.pkg_start_time
                    step.packages_completed.append((self.current_pkg, duration))
                
                if self.aborted:
                    step.status = "failed"
                    self.log(f"{step.name} ABORTED", "bold yellow")
                    break
                
                if process.returncode == 0:
                    step.status = "completed"
                    self.log(f"✓ {step.name} completed successfully in {step.duration():.1f}s", "green")
                    self.current_step_idx += 1
                else:
                    step.status = "failed"
                    self.log(f"✘ {step.name} FAILED with code {process.returncode}", "bold red")
                    self.error_msg = f"{step.name} failed. Check {step.log_file}"
                    
                    # Enter error recovery mode
                    self.paused_for_error = True
                    while self.paused_for_error and not self.aborted:
                        time.sleep(0.5)
                    
                    if self.aborted:
                        break
                    # If we aren't aborted, it means the user requested a restart (step or pkg)
                    # We've already stayed on the same current_step_idx
                    continue
                    
            except Exception as e:
                step.status = "failed"
                step.end_time = time.time()
                self.log(f"!!! EXCEPTION in {step.name}: {str(e)}", "bold red")
                self.error_msg = str(e)
                self.paused_for_error = True
                while self.paused_for_error and not self.aborted:
                    time.sleep(0.5)
                if self.aborted:
                    break
                continue
        
        self.is_running = False
        if not self.aborted and self.current_step_idx >= len(self.steps):
            self.log("🎉 ALL BUILD PHASES COMPLETED SUCCESSFULLY 🎉", "bold green")

    def abort(self):
        self.aborted = True
        self.is_running = False
        self.log("Abort requested. Cleaning up...", "bold yellow")

# ============================================================================
# UI RENDERING
# ============================================================================

def create_layout() -> Layout:
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=10),
        Layout(name="main"),
        Layout(name="footer", size=3)
    )
    
    layout["main"].split_row(
        Layout(name="side", ratio=1),
        Layout(name="body", ratio=2)
    )
    
    layout["body"].split_column(
        Layout(name="status", size=11),  # Increased size for more progress bars
        Layout(name="logs")
    )
    
    return layout

def format_time(seconds):
    if seconds is None: return "00:00"
    hours, remainder = divmod(int(seconds), 3600)
    mins, secs = divmod(remainder, 60)
    if hours > 0:
        return f"{hours:02d}:{mins:02d}:{secs:02d}"
    return f"{mins:02d}:{secs:02d}"

def update_ui(layout, engine):
    # Header
    layout["header"].update(Panel(
        Align.center(
            Columns([
                Text(LOGO, style="bold bright_cyan"),
                Text("\n\n🌶️ GingerOS Build System\nLFS 12.4 Automata\nCyberpunk Edition", style="bold bright_green", justify="center")
            ])
        ),
        border_style="bright_blue"
    ))
    
    # Side - Roadmaps & Package History
    roadmap_table = Table(show_header=True, header_style="bold magenta", expand=True, box=None)
    roadmap_table.add_column("PHASE / STEP", style="bold white")
    roadmap_table.add_column("STAT", justify="right")
    
    last_phase = ""
    for i, step in enumerate(engine.steps):
        if step.phase != last_phase:
            roadmap_table.add_row(f"[dim]─── {step.phase} ───[/dim]", "")
            last_phase = step.phase
            
        marker = " [ ]"
        style = "white"
        if step.status == "completed":
            marker = " [✓]"
            style = "green"
        elif step.status == "running":
            marker = " [▶]"
            style = "bold cyan"
        elif step.status == "failed":
            marker = " [✘]"
            style = "bold red"
            
        name = step.name
        if len(name) > 20: name = name[:17] + "..."
        
        roadmap_table.add_row(
            Text(f"{marker} {name}", style=style),
            Text(step.status.upper(), style=style)
        )
    
    # History of packages for current phase
    history_content = Text()
    if engine.current_step_idx < len(engine.steps):
        current_step = engine.steps[engine.current_step_idx]
        history_content.append(f"\n[bold yellow]Completed in {current_step.name}:[/bold yellow]\n")
        if not current_step.packages_completed:
            history_content.append("  (No packages yet)\n", style="dim italic")
        for pkg, dur in current_step.packages_completed[-5:]:  # Show last 5
            history_content.append(f"  ✓ {pkg} ({dur:.1f}s)\n", style="green")

    side_layout = Layout()
    side_layout.split_column(
        Layout(Panel(roadmap_table, title="[bold blue]Roadmap[/bold blue]", border_style="bright_blue"), ratio=2),
        Layout(Panel(history_content, title="[bold blue]Package Trail[/bold blue]", border_style="bright_blue"), ratio=1)
    )
    layout["side"].update(side_layout)
    
    # Status
    if engine.current_step_idx < len(engine.steps):
        current_step = engine.steps[engine.current_step_idx]
        
        # Calculate progress values
        overall_progress = (engine.current_step_idx / len(engine.steps)) * 100
        
        # Phase internal progress (estimate based on common step counts)
        # For simplicity, we can't easily know total packages in a phase script 
        # until they finish, so we just show it as "active".
        # But we CAN show step progress.
        
        status_table = Table.grid(expand=True)
        
        # Overall Timer & Progress
        overall_time = time.time() - engine.overall_start_time if engine.overall_start_time else 0
        overall_bar = "█" * int(overall_progress / 2.5) + "░" * (40 - int(overall_progress / 2.5))
        status_table.add_row(f"[bold cyan]OVERALL:[/bold cyan] [{LASER_GREEN}]{overall_bar}[/] {overall_progress:.0f}%  [bold magenta]⏱ {format_time(overall_time)}[/bold magenta]")
        
        # Phase Timer & Info
        phase_time = time.time() - engine.phase_start_time if engine.phase_start_time else 0
        status_table.add_row(f"[bold cyan]PHASE  :[/bold cyan] {current_step.name} ({current_step.phase}) [bold magenta]⏱ {format_time(phase_time)}[/bold magenta]")
        
        # Package Timer & Info
        pkg_time = time.time() - engine.pkg_start_time if engine.pkg_start_time else 0
        pkg_display = engine.current_pkg or "Initializing..."
        if engine.paused_for_error:
            pkg_display = f"[bold red blink]FAILED: {pkg_display}[/bold red blink]"
        status_table.add_row(f"[bold yellow]PACKAGE:[/bold yellow] {pkg_display} [bold magenta]⏱ {format_time(pkg_time)}[/bold magenta]")
        
        layout["status"].update(Panel(status_table, title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))
    else:
        layout["status"].update(Panel(Align.center("[bold green]BUILD COMPLETE[/bold green]"), title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))

    # Logs
    log_content = Text()
    # If paused for error, show more logs or highlight last error
    log_slice = engine.logs[-15:]
    if engine.paused_for_error:
        log_slice = engine.logs[-25:] # Show more logs during error
        
    for entry, style in log_slice:
        log_content.append(entry + "\n", style=style or "bright_white")
    
    layout["logs"].update(Panel(log_content, title="[bold blue]Real-time Intelligence[/bold blue]", border_style="bright_blue"))
    
    # Footer
    footer_text = "STATUS: RUNNING BUILD"
    footer_style = "bold yellow"
    
    if engine.paused_for_error:
        footer_text = "⚠️ ERROR DETECTED: [bold white]R[/] to Restart Phase | [bold white]P[/] to Restart Package | [bold white]Ctrl+C[/] to Abort"
        footer_style = "bold red"
    elif not engine.is_running:
        if engine.error_msg:
            footer_text = f"CRITICAL ERROR: {engine.error_msg}"
            footer_style = "bold red"
        else:
            footer_text = "🎉 BUILD COMPLETED SUCCESSFULLY"
            footer_style = "bold green"
    
    layout["footer"].update(Panel(
        Align.center(Text(footer_text, style=footer_style)),
        border_style="bright_blue"
    ))

# ============================================================================
# MAIN
# ============================================================================

def main():
    console = Console()
    engine = GingerEngine()
    layout = create_layout()
    
    # Signal handlers
    def signal_handler(sig, frame):
        engine.abort()
        # Give a moment for cleanup
        time.sleep(1)
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)

    # Initial sudo check
    try:
        subprocess.run(["sudo", "-v", "-n"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        console.print("[bold red]Error: This script must be run with sudo or have cached credentials.[/bold red]")
        console.print("Please run 'sudo -v' first or run this script with sudo.")
        sys.exit(1)

    # Start build
    build_thread = threading.Thread(target=engine.run)
    build_thread.start()
    
    try:
        with Live(layout, refresh_per_second=4, screen=True) as live:
            while engine.is_running or build_thread.is_alive():
                update_ui(layout, engine)
                time.sleep(0.2)
            update_ui(layout, engine)
            time.sleep(2) # Show final state
    except Exception as e:
        console.print(f"[bold red]UI Error: {str(e)}[/bold red]")
    finally:
        # Final summary
        if not engine.aborted:
            if any(s.status == "failed" for s in engine.steps):
                console.print("\n[bold red]Build failed. Check the logs above.[/bold red]")
            else:
                console.print("\n[bold green]Success! GingerOS is ready.[/bold green]")
                console.print(f"Master log: {MASTER_LOG}")

if __name__ == "__main__":
    main()
