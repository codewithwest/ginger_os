
import os
import sys
import time
import subprocess
import threading
import signal
from datetime import datetime
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
 / ____(_)                       / __ \ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \ / _` |/ _ \ '__|| |  | |\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \_____|_|_| |_|\__, |\___|_|    \____/|_____/ 
                 __/ |                         
                |___/         v2.0 [Python]
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
        self.logs = []
        self.max_logs = 100
        self.is_running = False
        self.aborted = False
        self.error_msg = ""
        
        # Keep sudo alive
        self.sudo_thread = threading.Thread(target=self._sudo_keepalive, daemon=True)

    def _sudo_keepalive(self):
        while True:
            subprocess.run(["sudo", "-v"], capture_output=True)
            time.sleep(60)

    def log(self, message, style=None):
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
        self.sudo_thread.start()
        self.log("Starting GingerOS Build Engine...", "bold green")
        
        for i, step in enumerate(self.steps):
            if self.aborted:
                break
                
            self.current_step_idx = i
            step.status = "running"
            step.start_time = time.time()
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
                        # Only log to UI if it's not too chatty, but always log to file
                        with open(step.log_file, "a") as f:
                            f.write(line)
                        
                        # Show some filtered output in UI logs
                        if any(kw in stripped.lower() for kw in ["error", "warning", "installing", "building", "configuring", "checking"]):
                            self.log(f"  {stripped[:80]}", "dim")
                
                process.wait()
                step.end_time = time.time()
                
                if self.aborted:
                    step.status = "failed"
                    self.log(f"{step.name} ABORTED", "bold yellow")
                    break
                
                if process.returncode == 0:
                    step.status = "completed"
                    self.log(f"✓ {step.name} completed successfully in {step.duration():.1f}s", "green")
                else:
                    step.status = "failed"
                    self.log(f"✘ {step.name} FAILED with code {process.returncode}", "bold red")
                    self.error_msg = f"{step.name} failed. Check {step.log_file}"
                    self.is_running = False
                    return
                    
            except Exception as e:
                step.status = "failed"
                step.end_time = time.time()
                self.log(f"!!! EXCEPTION in {step.name}: {str(e)}", "bold red")
                self.error_msg = str(e)
                self.is_running = False
                return
        
        self.is_running = False
        if not self.aborted:
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
        Layout(name="status", size=8),
        Layout(name="logs")
    )
    
    return layout

def update_ui(layout, engine):
    # Header
    layout["header"].update(Panel(
        Align.center(
            Columns([
                Text(LOGO, style="bold cyan"),
                Text("\n\n🌶️ GingerOS Build System\nLFS 12.4 Automata\nCyberpunk Edition", style="bold green", justify="center")
            ])
        ),
        border_style="bright_blue"
    ))
    
    # Side - Roadmaps
    table = Table(show_header=True, header_style="bold magenta", expand=True, box=None)
    table.add_column("PHASE / STEP", style="bold white")
    table.add_column("STATUS", justify="right")
    
    last_phase = ""
    for i, step in enumerate(engine.steps):
        if step.phase != last_phase:
            table.add_row(f"[dim]─── {step.phase} ───[/dim]", "")
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
        
        table.add_row(
            Text(f"{marker} {name}", style=style),
            Text(step.status.upper(), style=style)
        )
    
    layout["side"].update(Panel(table, title="[bold blue]Roadmap[/bold blue]", border_style="bright_blue"))
    
    # Status
    if engine.current_step_idx < len(engine.steps):
        current_step = engine.steps[engine.current_step_idx]
        progress_val = (engine.current_step_idx / len(engine.steps)) * 100
        if current_step.status == "completed": progress_val = 100
        
        status_table = Table.grid(expand=True)
        status_table.add_row(f"[bold cyan]ACTIVE:[/bold cyan] {current_step.name}")
        status_table.add_row(f"[bold cyan]PHASE :[/bold cyan] {current_step.phase}")
        status_table.add_row(f"[bold cyan]TIME  :[/bold cyan] {current_step.duration():.1f}s")
        
        # Simple progress bar
        bar_width = 40
        filled = int((progress_val / 100) * bar_width)
        bar = "█" * filled + "░" * (bar_width - filled)
        status_table.add_row(f"[{LASER_GREEN}]{bar}[/] {progress_val:.0f}%")
        
        layout["status"].update(Panel(status_table, title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))
    else:
        layout["status"].update(Panel(Align.center("[bold green]BUILD COMPLETE[/bold green]"), title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))

    # Logs
    log_content = Text()
    for entry, style in engine.logs[-15:]:
        log_content.append(entry + "\n", style=style or "dim")
    
    layout["logs"].update(Panel(log_content, title="[bold blue]Real-time Intelligence[/bold blue]", border_style="bright_blue"))
    
    # Footer
    footer_text = "PRESS CTRL+C TO TERMINATE BUILD SAFELY"
    if not engine.is_running:
        if engine.error_msg:
            footer_text = f"CRITICAL ERROR: {engine.error_msg}"
        else:
            footer_text = "BUILD TERMINATED SUCCESSFULLY"
    
    layout["footer"].update(Panel(
        Align.center(Text(footer_text, style="bold yellow")),
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
