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
            Layout(name="header", size=7),
            Layout(name="main_grid", ratio=1),
            Layout(name="terminal", size=10),
            Layout(name="footer", size=3)
        )
        
        layout["main_grid"].split_row(
            Layout(name="steps", ratio=1),
            Layout(name="dashboard", ratio=2),
            Layout(name="matrix", ratio=1)
        )
        
        layout["dashboard"].split_column(
            Layout(name="neural_stats", ratio=1),
            Layout(name="ai_copilot", size=6)
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
        """Render high-tech header"""
        pulsar = self.get_neural_pulsar()
        
        branding = Text()
        branding.append(f" {pulsar} ", style="bold bright_cyan")
        branding.append("GINGER_OS // ", style="bold bright_white")
        branding.append("NEURAL_CORE_V1.1", style="dim cyan")
        
        status_info = Text()
        if self.executing_step is not None:
            status_info.append(" [ SYSTEM_BUSY ] ", style="bold bright_red blink")
        else:
            status_info.append(" [ CORE_READY ] ", style="bold bright_green")
            
        return Panel(
            Align.center(branding + status_info, vertical="middle"),
            border_style="bright_blue",
            box=box.DOUBLE_EDGE
        )

    def render_steps(self):
        """Modern cyber-table for build steps"""
        table = Table(
            show_header=True,
            header_style="bold bright_cyan",
            box=box.SIMPLE_HEAD,
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
                state = "[bold bright_cyan]ACTIVE[/]"
                row_style = "on blue3"
                slot_txt = f"[black on bright_cyan] {idx+1:02d} [/]"
            elif is_completed:
                state = "[bright_green]STABLE[/]"
                row_style = ""
                slot_txt = f"{idx+1:02d}"
            else:
                state = "[dim]LOCKED[/]"
                row_style = "dim"
                slot_txt = f"{idx+1:02d}"

            # Highlight cursor
            if idx == self.selected_step and self.executing_step is None:
                row_style = "on gray23"
                slot_txt = f"[bold bright_yellow]>{idx+1:02d}[/]"

            table.add_row(
                slot_txt,
                step.name,
                state,
                style=row_style
            )
            
        return Panel(
            table,
            title="[bold bright_cyan]══ SEQUENCE_STACK ══[/]",
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
        matrix.append("\n 🖥️  HOST_RESOURCES\n", style="bold bright_white")
        
        try:
            load = os.getloadavg()
            matrix.append(f"  CPU_LOAD: ", style="bright_cyan")
            matrix.append(f"{load[0]:.2f}\n", style="bold bright_white")
        except: pass
        
        # Disk stats
        host_disk = self.engine.storage_stats.get("host", 0)
        lfs_disk = self.engine.storage_stats.get("lfs", 0)
        
        def disk_bar(val):
            filled = int(val / 10)
            return "█" * filled + "░" * (10 - filled)
            
        matrix.append(f"\n 💿  STORAGE_NODES\n", style="bold bright_white")
        matrix.append(f"  HOST: [{disk_bar(host_disk)}] {host_disk:.0f}%\n", style="bright_cyan" if host_disk < 90 else "bright_red")
        matrix.append(f"  LFS:  [{disk_bar(lfs_disk)}] {lfs_disk:.0f}%\n", style="bright_green")
        
        # Stability / Build Index
        complete = sum(1 for s in self.engine.steps if self.engine._should_skip(s))
        total = len(self.engine.steps)
        stability = (complete/total) * 100
        matrix.append(f"\n 🛡️  CORE_STABILITY\n", style="bold bright_white")
        matrix.append(f"  INDEX: [{disk_bar(stability)}] {stability:.0f}%\n", style="bold bright_green")
        
        matrix.append(f"\n 🛰️  ENCRYPTION\n", style="dim")
        matrix.append("  AES-256_ACTIVE\n", style="dim italic green")
        
        return Panel(
            matrix,
            title="[bold bright_white]══ SYSTEM_MATRIX ══[/]",
            border_style="bright_white",
            box=box.ROUNDED
        )

    def render_terminal(self):
        """Live log terminal with scanline effect simulator"""
        log_content = Text()
        
        if self.executing_step is not None:
            recent_logs = self.engine.logs[-15:] if len(self.engine.logs) > 15 else self.engine.logs
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
            box=box.PLAIN
        )
    
    def update_display(self, layout):
        """Update all specific Neural UI panels"""
        layout["header"].update(self.render_header())
        layout["steps"].update(self.render_steps())
        layout["dashboard"].split_column(
            Layout(self.render_dashboard(), ratio=1),
            Layout(self.render_ai_copilot(), size=6)
        )
        layout["matrix"].update(self.render_matrix())
        layout["terminal"].update(self.render_terminal())
        layout["footer"].update(self.render_footer())
    
    def render_help(self):
        """Render help panel"""
        help_text = Text()
        help_text.append("KEYBOARD COMMANDS\n\n", style="bold bright_cyan")
        
        help_text.append("Navigation:\n", style="bold bright_yellow")
        help_text.append("  ↑/k      ", style="bright_white")
        help_text.append("Move up\n", style="dim")
        help_text.append("  ↓/j      ", style="bright_white")
        help_text.append("Move down\n", style="dim")
        help_text.append("  g/Home   ", style="bright_white")
        help_text.append("Go to first\n", style="dim")
        help_text.append("  G/End    ", style="bright_white")
        help_text.append("Go to last\n\n", style="dim")
        
        help_text.append("Actions:\n", style="bold bright_yellow")
        help_text.append("  ENTER    ", style="bright_white")
        help_text.append("Run selected step\n", style="dim")
        help_text.append("  f        ", style="bright_white")
        help_text.append("Force run (ignore marker)\n", style="dim")
        help_text.append("  d        ", style="bright_white")
        help_text.append("Delete marker\n", style="dim")
        help_text.append("  a        ", style="bright_white")
        help_text.append("Run all pending steps\n", style="dim")
        help_text.append("  s        ", style="bright_white")
        help_text.append("Skip to next pending\n\n", style="dim")
        
        help_text.append("Other:\n", style="bold bright_yellow")
        help_text.append("  ?        ", style="bright_white")
        help_text.append("Toggle this help\n", style="dim")
        help_text.append("  q/ESC    ", style="bright_white")
        help_text.append("Quit\n", style="dim")
        
        return Panel(
            help_text,
            title="[bold bright_yellow]Help[/]",
            border_style="bold bright_yellow"
        )
    
    def render_footer(self):
        """Render footer with shortcuts"""
        footer = Text()
        
        if self.executing_step is not None:
            footer.append("⚡ EXECUTING ", style="bold bright_cyan")
            footer.append(f"Step {self.executing_step + 1}", style="bold bright_white")
            footer.append(" | Press ", style="dim")
            footer.append("Ctrl+C", style="bold bright_red")
            footer.append(" to stop", style="dim")
        else:
            footer.append("↑↓/jk", style="bold bright_white")
            footer.append("=nav  ", style="dim")
            footer.append("ENTER", style="bold bright_green")
            footer.append("=run  ", style="dim")
            footer.append("f", style="bold bright_cyan")
            footer.append("=force  ", style="dim")
            footer.append("d", style="bold bright_red")
            footer.append("=delete  ", style="dim")
            
            auto_style = "bold bright_cyan" if self.auto_all else "bold bright_white"
            auto_label = "AUTO-ON" if self.auto_all else "auto"
            footer.append("a", style=auto_style)
            footer.append(f"={auto_label}  ", style="dim")
            
            p_style = "bold bright_magenta" if self.engine.package_stepping else "bold bright_white"
            footer.append("p", style=p_style)
            footer.append("=pkg-step  ", style="dim")
            
            footer.append("?", style="bold bright_magenta")
            footer.append("=help  ", style="dim")
            footer.append("q", style="bold bright_red")
            footer.append("=quit", style="dim")
        
        return Panel(
            Align.center(footer),
            border_style="bold bright_blue"
        )
    
    def update_display(self, layout):
        """Update all panels"""
        layout["header"].update(self.render_header())
        layout["steps"].update(self.render_steps())
        layout["details"].update(self.render_details())
        layout["logs"].update(self.render_logs())
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
    parser.add_argument("-w", "--web", action="store_true", help="Start the remote monitoring Web UI")
    parser.add_argument("-p", "--port", type=int, default=8000, help="Web UI port (default: 8000)")
    args = parser.parse_args()
    
    tui = GingerTUI(dry_run=args.dry_run)
    
    if args.web:
        try:
            import fastapi
            import uvicorn
        except ImportError:
            print("\nError: Web UI dependencies missing.")
            print("Please install them with: pip install fastapi uvicorn")
            sys.exit(1)

        from lfs_builder_ui.server import start_server
        web_thread = threading.Thread(
            target=start_server, 
            args=(tui.engine, "0.0.0.0", args.port), 
            daemon=True
        )
        web_thread.start()
        # Small delay to let the server start before logging to terminal
        time.sleep(0.5)
        tui.engine.log(f"Web UI Dashboard: Active at http://localhost:{args.port}", "bold green")

    tui.run()

if __name__ == "__main__":
    main()
