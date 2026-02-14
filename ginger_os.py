#!/usr/bin/env python3
"""
GingerOS Command-First TUI
Build system controlled entirely by keyboard commands
"""

import sys
import os
import time
import threading
import subprocess
import termios
import tty
import select
import argparse
from rich.console import Console
from rich.live import Live
from rich.layout import Layout
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.align import Align
from rich import box

from rich.columns import Columns

# Add to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lfs_builder_ui import GingerEngine
from lfs_builder_ui.constants import LOGO

class GingerTUI:
    def __init__(self, dry_run=False):
        self.console = Console()
        self.dry_run = dry_run
        self.engine = GingerEngine(dry_run=dry_run)
        self.selected_step = 0
        self.running = True
        self.executing_step = None
        self.executing_thread = None
        self.current_start_time = 0
        self.show_help = False
        self.mode = "select"  # select, execute, logs
        self.log_scroll = 0
        self.auto_all = False
        self.last_auto_step = None
        
    def create_layout(self):
        """Create the high-tech Neural-Link layout"""
        layout = Layout()
        layout.split_column(
            Layout(name="top", size=13),
            Layout(name="body", ratio=1),
            Layout(name="footer", size=3)
        )
        
        layout["top"].split_row(
            Layout(name="header", ratio=12), # Logo Area
            Layout(name="monitor_area", ratio=28) # Deployment Monitor + Copilot
        )
        
        layout["monitor_area"].split_column(
            Layout(name="neural_stats", ratio=1), # DEPLOYMENT_MONITOR
            Layout(name="ai_copilot", size=4)      # AI_COPILOT_STREAM
        )

        layout["body"].split_row(
            Layout(name="left_col", ratio=12),
            Layout(name="terminal", ratio=28) # Live Log Terminal
        )

        layout["left_col"].split_column(
            Layout(name="steps", ratio=2), # SEQUENCE
            Layout(name="matrix", ratio=1)  # SYS_MX
        )
        
        return layout

    def format_time(self, seconds):
        mins, secs = divmod(int(seconds), 60)
        return f"{mins:02d}:{secs:02d}"

    def get_neural_pulsar(self):
        """Generates an animated AI 'pulsar' character"""
        frames = ["󱐋", "󱐌", "󱐍", "󱐎", "󱐏", "󱐐", "󱐑"]
        # Use simpler characters if the terminal doesn't support nerd fonts
        simple_frames = ["|", "/", "-", "\\"]
        idx = int(time.time() * 8) % len(simple_frames)
        return simple_frames[idx]

    def render_header(self):
        """Render high-tech header with logo and branding"""
        pulsar = self.get_neural_pulsar()
        
        # Original Branding
        branding = Text(LOGO.strip() + "\n", style="bold bright_cyan")
        branding.append(f" {pulsar} NEURAL_CORE_V1.1_LOADED", style="dim cyan")
        
        return Panel(
            Align.center(branding, vertical="middle"),
            border_style="bright_blue",
            box=box.DOUBLE_EDGE,
            title="[bold dim blue] SYSTEM_ID [/]"
        )

    def render_steps(self):
        """Modern cyber-table for build steps"""
        table = Table(
            show_header=True,
            header_style="bold bright_cyan",
            box=box.SIMPLE,
            expand=True,
            padding=(0, 1)
        )
        
        table.add_column("SLOT", width=6, justify="center", style="dim")
        table.add_column("MODULE", style="bright_white")
        table.add_column("STATE", width=10, justify="right")
        
        for idx, step in enumerate(self.engine.steps):
            is_active = self.executing_step == idx
            is_completed = self.engine._should_skip(step)
            
            # Status styling
            if is_active:
                state = "[bold bright_cyan]▶ RUNNING[/]"
                row_style = "on blue3"
                slot_txt = f"[bold bright_cyan]{idx+1:02d}[/]"
            elif is_completed:
                state = "[bright_green]✔ STABLE[/]"
                row_style = ""
                slot_txt = f"[dim]{idx+1:02d}[/]"
            else:
                state = "[dim]○ PENDING[/]"
                row_style = "dim"
                slot_txt = f"{idx+1:02d}"

            # Highlight cursor
            if idx == self.selected_step and self.executing_step is None:
                row_style = "on gray19"
                slot_txt = f"[bold bright_yellow]{idx+1:02d}[/]"

            table.add_row(
                slot_txt,
                step.name,
                state,
                style=row_style
            )
            
        return Panel(
            table,
            title="[bold bright_cyan] 0x_SEQUENCE [/]",
            border_style="bright_blue",
            box=box.ROUNDED
        )

    def render_dashboard(self):
        """Central dashboard with rich progress and gauges"""
        stats = Text()
        
        if self.executing_step is not None:
            step = self.engine.steps[self.executing_step]
            elapsed = time.time() - self.current_start_time
            
            stats.append(f"\n» CURRENT_PHASE: ", style="bold bright_cyan")
            stats.append(f"{step.name}\n", style="bold bright_white")
            
            # Sub-module progress
            if self.engine.current_pkg:
                stats.append(f"» TARGET: ", style="bright_yellow")
                stats.append(f"{self.engine.current_pkg}\n", style="bright_white")
                
                if self.engine.total_pkg_count > 0:
                    prog = self.engine.current_pkg_idx / self.engine.total_pkg_count
                    bar_width = 30
                    filled = int(prog * bar_width)
                    bar = "█" * filled + "░" * (bar_width - filled)
                    stats.append(f"  [{bar}] ", style="bright_cyan")
                    stats.append(f"{self.engine.current_pkg_idx}/{self.engine.total_pkg_count}\n", style="dim")
                
                if self.engine.pkg_start_time:
                    p_elapsed = time.time() - self.engine.pkg_start_time
                    stats.append(f"  ETR_PKG: ", style="dim")
                    stats.append(f"{self.format_time(p_elapsed)}\n", style="bright_green")

            stats.append(f"\n» UPTIME: {self.format_time(elapsed)}\n", style="bold bright_yellow")
            
        else:
            # Idle view
            stats.append("\n\n [ NEURAL_CORE_IDLE ]\n", style="bold dim cyan")
            stats.append(" Select a module to initiate deployment\n", style="dim")
            
            # Show summary
            complete = sum(1 for s in self.engine.steps if self.engine._should_skip(s))
            total = len(self.engine.steps)
            stats.append(f"\n STABILITY_INDEX: {int((complete/total)*100)}%\n", style="bright_green")
            
        return Panel(
            Align.center(stats, vertical="middle"),
            title=f"[bold bright_magenta]══ DEPLOYMENT_MONITOR ══[/]",
            border_style="bright_magenta",
            box=box.HEAVY
        )

    def render_help(self):
        """High-tech help panel overlay"""
        help_text = Text()
        help_text.append(" [ NEURAL_LINK_COMMANDS ]\n\n", style="bold bright_cyan")
        
        cmds = [
            ("ENTER", "Initiate Module Sequence"),
            ("A", "Toggle Autonomous Deploy"),
            ("P", "Toggle Package Stepping"),
            ("F", "Force Module Re-build"),
            ("D", "Purge Module State"),
            ("S", "Skip to Next Pending"),
            ("?", "Toggle Neural Help"),
            ("Q", "Terminate Session")
        ]
        
        for key, desc in cmds:
            help_text.append(f" {key:5s} ", style="bold black on bright_white")
            help_text.append(f" » {desc}\n", style="dim")
            
        return Panel(
            Align.center(help_text, vertical="middle"),
            title="[bold bright_yellow]══ HELP_ENVIRONMENT ══[/]",
            border_style="bright_yellow",
            box=box.DOUBLE_EDGE
        )

    def render_ai_copilot(self):
        """AI Assistant thought log with dynamic states"""
        thoughts = Text()
        
        # Simulated AI internal states
        states = [" ANALYZING", " OPTIMIZING", " MONITORING", " SECURING"]
        state = states[int(time.time() / 2) % len(states)]
        
        thoughts.append(f" 🧠 {state}: ", style="bold bright_magenta")
        
        if self.executing_step is not None:
            step = self.engine.steps[self.executing_step]
            # Context-aware phrases
            if "host" in step.name.lower():
                thoughts.append("Verifying ecosystem dependencies. Host environment identified as stable.")
            elif "toolchain" in step.name.lower():
                thoughts.append("Synthesizing binary primitives. Mitigating entropy in the cross-compiler.")
            elif "kernel" in step.name.lower():
                thoughts.append("Orchestrating the heart of GingerOS. Calibrating scheduler and memory safety.")
            else:
                thoughts.append(f"Executing directive: {step.name}. Monitoring for syscall anomalies.")
        else:
            if self.auto_all:
                thoughts.append("Autonomous sequence engaged. Standing by for multi-phase synchronization.")
            else:
                thoughts.append("Awaiting operator 'EXECUTE' command. Ready to initiate sequence pulse.")
            
        return Panel(
            thoughts,
            title="[bold bright_magenta] AI_COPILOT_STREAM [/]",
            border_style="dim magenta",
            box=box.SQUARE,
            padding=(1, 2)
        )

    def render_matrix(self):
        """System metrics matrix with stability gauge"""
        matrix = Text()
        matrix.append("\n 🖥️  HOST\n", style="bold bright_white")
        
        try:
            load = os.getloadavg()
            matrix.append(f"  LOAD: {load[0]:.2f}\n", style="bright_cyan")
        except: pass
        
        # Disk stats
        host_disk = self.engine.storage_stats.get("host", 0)
        lfs_disk = self.engine.storage_stats.get("lfs", 0)
        
        def mini_bar(val):
            filled = int(val / 20)
            return "█" * filled + "░" * (5 - filled)
            
        matrix.append(f"\n 💿  STORAGE\n", style="bold bright_white")
        matrix.append(f"  Host Disk: [{mini_bar(host_disk)}] {host_disk:.0f}%\n", style="bright_cyan" if host_disk < 90 else "bright_red")
        matrix.append(f"  LFS Disk: [{mini_bar(lfs_disk)}] {lfs_disk:.0f}%\n", style="bright_green")
        
        # Build Index
        complete = sum(1 for s in self.engine.steps if self.engine._should_skip(s))
        total = len(self.engine.steps)
        stability = (complete/total) * 100
        matrix.append(f"\n 🛡️  STABLE\n", style="bold bright_white")
        matrix.append(f"  {stability:.0f}%\n", style="bold bright_green")
        
        return Panel(
            matrix,
            title="[bold bright_white]══ SYS_MX ══[/]",
            border_style="bright_white",
            box=box.ROUNDED
        )

    def render_terminal(self):
        """Live log terminal with scanline effect simulator"""
        log_content = Text()
        
        if self.engine.logs:
            # We can show more logs now in the side panel
            recent_logs = self.engine.logs[-28:] if len(self.engine.logs) > 28 else self.engine.logs
            for log_entry, style in recent_logs:
                # Truncate and prefix
                if len(log_entry) > 100: log_entry = log_entry[:97] + "..."
                log_content.append(" >_ ", style="bold bright_cyan")
                log_content.append(log_entry + "\n", style=style or "bright_white")
        else:
            log_content.append("\n [ TERMINAL_STANDBY ]\n", style="bold dim cyan")
            log_content.append(" Pulse frequency: 440Hz\n", style="dim italic")
            log_content.append(" Waiting for neural link acquisition...", style="dim")
            
        return Panel(
            log_content,
            title="[bold bright_cyan]══ TERMINAL_STREAM ══[/]",
            border_style="dim cyan",
            box=box.SQUARE
        )

    def render_footer(self):
        """Stylish button-like footer"""
        footer = Text()
        
        # (Key, Label, Color)
        commands = [
            ("↵", "EXECUTE", "bright_green"),
            ("A", "AUTO", "bright_cyan"),
            ("P", "STEP", "bright_magenta"),
            ("F", "FORCE", "bright_yellow"),
            ("D", "PURGE", "bright_red"),
            ("?", "HELP", "white"),
            ("Q", "QUIT", "bright_red")
        ]
        
        for key, cmd, color in commands:
            footer.append(f" {key} ", style=f"bold black on {color}")
            footer.append(f" {cmd} ", style=f"dim")
            footer.append("  ")
            
        return Panel(
            Align.center(footer, vertical="middle"),
            border_style="dim cyan",
            box=box.SIMPLE
        )
    
    def update_display(self, layout):
        """Update all specific Neural UI panels"""
        layout["header"].update(self.render_header())
        layout["steps"].update(self.render_steps())
        
        # Dashboard (Monitor Area) handles help toggle
        if self.show_help:
            layout["monitor_area"].update(self.render_help())
        else:
            # Ensure the monitor area is split if it was showing help
            if not isinstance(layout["monitor_area"].renderable, Layout):
                layout["monitor_area"].split_column(
                    Layout(name="neural_stats", ratio=1),
                    Layout(name="ai_copilot", size=4)
                )
            
            layout["neural_stats"].update(self.render_dashboard())
            layout["ai_copilot"].update(self.render_ai_copilot())
            
        layout["matrix"].update(self.render_matrix())
        layout["terminal"].update(self.render_terminal())
        layout["footer"].update(self.render_footer())
    
    def run_step(self, step_idx, force=False):
        """Execute a single step in a background thread"""
        step = self.engine.steps[step_idx]
        
        # Check if already complete
        if self.engine._should_skip(step) and not force:
            return False
        
        if self.executing_step is not None:
            return False  # Already running
            
        self.executing_step = step_idx
        self.current_start_time = time.time()
        self.engine.current_step_idx = step_idx
        
        def _target():
            self.engine._execute_step(step)
            # Signal completion is handled by polling in main loop
            # or we can update executing_step here, but main loop is safer
            self.executing_step = None

        # Start execution thread
        self.executing_thread = threading.Thread(target=_target, daemon=True)
        self.executing_thread.start()
        
        return True
    
    def delete_marker(self, step_idx):
        """Delete marker for a step"""
        step = self.engine.steps[step_idx]
        from lfs_builder_ui.constants import STATE_DIR
        
        marker_paths = [
            os.path.join(STATE_DIR, f"{step.id}.built"),
            f"/mnt/lfs/var/lib/ginger/{step.id}.built",
        ]
        
        for path in marker_paths:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except:
                    pass
    
    def run_all_pending(self):
        """Toggle automatic sequential execution mode."""
        self.auto_all = not self.auto_all
        if self.auto_all:
            self.last_auto_step = None
            # Disable stepping when auto-running
            self.engine.package_stepping = False
            # Resume if paused
            if self.engine.paused_for_package:
                self.engine.resume_package()
    
    def handle_key(self, key):
        """Handle keyboard input"""
        # Navigation
        if key in ['j', '\x1b[B']:  # j or DOWN
            if self.selected_step < len(self.engine.steps) - 1:
                self.selected_step += 1
        
        elif key in ['k', '\x1b[A']:  # k or UP
            if self.selected_step > 0:
                self.selected_step -= 1
        
        elif key == 'g':  # Go to first
            self.selected_step = 0
        
        elif key == 'G':  # Go to last
            self.selected_step = len(self.engine.steps) - 1
        
        # Actions
        elif key == '\r' or key == '\n':  # ENTER - run step
            return 'run'
        
        elif key == 'f':  # Force run
            return 'force'
        
        elif key == 'd':  # Delete marker
            return 'delete'
        
        elif key == 'a':  # Run all
            return 'run_all'
        
        elif key == 'p':  # Toggle stepping
            return 'toggle_stepping'
        
        elif key == ' ':  # Resume from pause
            return 'resume'
        
        elif key == 's':  # Skip to next pending
            for idx in range(self.selected_step + 1, len(self.engine.steps)):
                if not self.engine._should_skip(self.engine.steps[idx]):
                    self.selected_step = idx
                    break
        
        # Other
        elif key == '?':
            self.show_help = not self.show_help
        
        elif key in ['q', '\x1b']:  # q or ESC
            self.running = False
        
        return None
    
    def run(self):
        """Main TUI loop"""
        layout = self.create_layout()
        
        # Set up terminal
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        
        try:
            tty.setcbreak(fd)
            
            with Live(layout, refresh_per_second=10, screen=True) as live:
                while self.running:
                    # Sequential Auto-All Logic
                    if self.auto_all and self.executing_step is None:
                        # Safety: If the last step we tried in auto-mode failed, stop.
                        if self.last_auto_step is not None:
                            last_step = self.engine.steps[self.last_auto_step]
                            if last_step.status == "failed":
                                self.auto_all = False
                                self.last_auto_step = None
                                self.engine.log(f"Auto-Run: Stopped (Step '{last_step.name}' failed)", "bold red")
                                continue # Skip finding next till user interacts
                        
                        next_step_idx = -1
                        for idx, step in enumerate(self.engine.steps):
                            if not self.engine._should_skip(step):
                                next_step_idx = idx
                                break
                        
                        if next_step_idx != -1:
                            self.last_auto_step = next_step_idx
                            self.run_step(next_step_idx)
                        else:
                            self.auto_all = False 
                            self.last_auto_step = None
                            self.engine.log("Auto-Run: All pending steps finished! 🏁", "bold green")

                    # Update display
                    self.update_display(layout)
                    live.update(layout)
                    
                    # Check for input (non-blocking)
                    if select.select([sys.stdin], [], [], 0.05)[0]:
                        key = sys.stdin.read(1)
                        
                        # Handle arrow keys (multi-byte)
                        if key == '\x1b':
                            next_chars = sys.stdin.read(2)
                            key = key + next_chars
                        
                        action = self.handle_key(key)
                        
                        if action == 'delete':
                            self.delete_marker(self.selected_step)
                        elif action == 'run_all':
                            self.run_all_pending()
                        elif action == 'run':
                            self.run_step(self.selected_step, force=False)
                        elif action == 'force':
                            self.run_step(self.selected_step, force=True)
                        elif action == 'toggle_stepping':
                            self.engine.package_stepping = not self.engine.package_stepping
                        elif action == 'resume':
                            self.engine.resume_package()
        
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        
        self.console.print("\n[bright_cyan]Build session ended[/]")

def main():
    parser = argparse.ArgumentParser(description="GingerOS Command-First TUI")
    parser.add_argument("-n", "--dry-run", action="store_true", help="Preview build without executing commands")
    parser.add_argument("--no-web", action="store_true", help="Disable the remote monitoring Web UI")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Web UI host (default: 127.0.0.1)")
    parser.add_argument("-p", "--port", type=int, default=8000, help="Web UI port (default: 8000)")
    args = parser.parse_args()
    
    tui = GingerTUI(dry_run=args.dry_run)
    
    # Start Web UI by default unless explicitly disabled
    if not args.no_web:
        try:
            import fastapi
            import uvicorn
            from lfs_builder_ui.server import start_server
            
            web_thread = threading.Thread(
                target=start_server, 
                args=(tui.engine, args.host, args.port), 
                daemon=True
            )
            web_thread.start()
            # Small delay to let the server start
            time.sleep(0.5)
            tui.engine.log(f"NEURAL_LINK: Dashboard active at http://{args.host}:{args.port}", "bold green")
        except ImportError:
            tui.engine.log("SYSTEM_WARNING: Web UI dependencies (fastapi, uvicorn) missing. Dashboard disabled.", "yellow")

    tui.run()

if __name__ == "__main__":
    main()
