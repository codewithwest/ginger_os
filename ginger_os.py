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
    def __init__(self):
        self.console = Console()
        self.engine = GingerEngine()
        self.selected_step = 0
        self.running = True
        self.executing_step = None
        self.current_start_time = 0
        self.show_help = False
        self.mode = "select"  # select, execute, logs
        self.log_scroll = 0
        
    def create_layout(self):
        """Create the TUI layout"""
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=10),
            Layout(name="body"),
            Layout(name="footer", size=3)
        )
        
        layout["body"].split_row(
            Layout(name="steps", ratio=1),
            Layout(name="right", ratio=3)
        )
        
        # Split right side into details and logs
        layout["right"].split_column(
            Layout(name="details", size=8),
            Layout(name="logs")
        )
        
        return layout
    
    def format_time(self, seconds):
        mins, secs = divmod(int(seconds), 60)
        return f"{mins:02d}:{secs:02d}"
    
    def render_header(self):
        """Render header with logo and stats"""
        total = len(self.engine.steps)
        complete = sum(1 for s in self.engine.steps if self.engine._should_skip(s))
        pending = total - complete
        
        stats_text = Text()
        
        if self.executing_step is not None:
            elapsed = time.time() - self.current_start_time
            stats_text.append("🚀 EXECUTION IN PROGRESS\n", style="bold bright_red blink")
            stats_text.append(f"Running: {self.engine.steps[self.executing_step].name}\n", style="bold bright_white")
            stats_text.append(f"Time: {self.format_time(elapsed)}\n\n", style="bold bright_yellow")
            stats_text.append("⚠️  PLEASE WAIT - SYSTEM BUSY", style="bold bright_red")
        else:
            stats_text.append("🌶️ GingerOS Command Center 🌶️\n", style="bold bright_cyan")
            stats_text.append("LFS 12.4 Automata - Cyberpunk Edition\n\n", style="bold bright_green")
            stats_text.append(f"Total: {total}  ", style="dim")
            stats_text.append(f"✓ {complete}  ", style="bright_green")
            stats_text.append(f"○ {pending}", style="bright_yellow")
        
        return Panel(
            Columns([
                Text(LOGO, style="bold bright_cyan"),
                Align.center(stats_text, vertical="middle")
            ]),
            border_style="bold bright_blue",
            box=box.ROUNDED
        )
    
    def render_steps(self):
        """Render steps list"""
        table = Table(
            show_header=True,
            header_style="bold bright_cyan",
            box=box.SIMPLE_HEAVY,
            expand=True
        )
        
        table.add_column("#", width=4, justify="right")
        table.add_column("Status", width=8)
        table.add_column("Step", style="bright_white")
        
        for idx, step in enumerate(self.engine.steps):
            # Status
            if self.engine._should_skip(step):
                status = "[bright_green]✓ COMPLETED[/]"
            elif self.executing_step == idx:
                status = "[bright_cyan]▶ RUNNING[/]"
            else:
                status = "[dim]○ PENDING[/]"
            
            # Highlight selected
            if idx == self.selected_step:
                num = f"[black on bright_cyan]▶{idx+1:2d}[/]"
                name = f"[black on bright_cyan]{step.name}[/]"
            else:
                num = f"{idx+1:2d}"
                name = step.name
            
            table.add_row(num, status, name)
        
        return Panel(
            table,
            title="[bold bright_blue]Build Steps[/]",
            border_style="bold bright_blue"
        )
    
    def render_details(self):
        """Render details panel"""
        if self.show_help:
            return self.render_help()
        
        step = self.engine.steps[self.selected_step]
        
        details = Text()
        details.append(f"Step {self.selected_step + 1}: ", style="bold bright_cyan")
        details.append(f"{step.name}\n", style="bold bright_white")
        
        details.append("Phase: ", style="bright_yellow")
        details.append(f"{step.phase}\n", style="bright_white")
        
        details.append("Command: ", style="bright_yellow")
        details.append(f"{step.command}\n", style="dim")
        
        details.append("Status: ", style="bright_yellow")
        if self.engine._should_skip(step):
            details.append("✓ Completed", style="bright_green")
        elif self.executing_step == self.selected_step:
            details.append("▶ Running...", style="bright_cyan")
        else:
            details.append("○ Pending", style="dim")
        
        return Panel(
            details,
            title="[bold bright_blue]Details[/]",
            border_style="bold bright_blue"
        )
    
    def render_logs(self):
        """Render live logs panel"""
        log_content = Text()
        
        if self.executing_step is not None:
            # Show live output during execution
            log_content.append("🔴 LIVE OUTPUT\n\n", style="bold bright_red")
            
            # Show recent logs (last 30 lines)
            recent_logs = self.engine.logs[-30:] if len(self.engine.logs) > 30 else self.engine.logs
            
            for log_entry, style in recent_logs:
                # Truncate very long lines
                if len(log_entry) > 120:
                    log_entry = log_entry[:117] + "..."
                log_content.append(log_entry + "\n", style=style or "bright_white")
        else:
            # Show instructions when idle
            log_content.append("Ready to execute commands\n\n", style="bold bright_cyan")
            log_content.append("Press ", style="dim")
            log_content.append("ENTER", style="bold bright_green")
            log_content.append(" to run selected step\n", style="dim")
            log_content.append("Press ", style="dim")
            log_content.append("?", style="bold bright_magenta")
            log_content.append(" for help", style="dim")
        
        return Panel(
            log_content,
            title="[bold bright_blue]Live Output[/]",
            border_style="bold bright_blue"
        )
    
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
            footer.append("a", style="bold bright_yellow")
            footer.append("=run-all  ", style="dim")
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
        """Execute a single step"""
        step = self.engine.steps[step_idx]
        
        # Check if already complete
        if self.engine._should_skip(step) and not force:
            return False
        
        self.executing_step = step_idx
        self.current_start_time = time.time()
        self.engine.current_step_idx = step_idx
        
        # Execute in current thread (blocking)
        self.engine._execute_step(step)
        
        self.executing_step = None
        return step.status == "completed"
    
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
        """Run all pending steps"""
        for idx, step in enumerate(self.engine.steps):
            if not self.engine._should_skip(step):
                success = self.run_step(idx, force=False)
                if not success:
                    break
    
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
                    # Update display
                    self.update_display(layout)
                    live.update(layout)
                    
                    # Check for input (non-blocking)
                    if select.select([sys.stdin], [], [], 0.1)[0]:
                        key = sys.stdin.read(1)
                        
                        # Handle arrow keys (multi-byte)
                        if key == '\x1b':
                            next_chars = sys.stdin.read(2)
                            key = key + next_chars
                        
                        action = self.handle_key(key)
                        
                        # Handle actions that need terminal restoration
                        if action in ['run', 'force', 'delete', 'run_all']:
                            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                            
                            if action == 'run':
                                self.run_step(self.selected_step, force=False)
                            elif action == 'force':
                                self.run_step(self.selected_step, force=True)
                            elif action == 'delete':
                                self.delete_marker(self.selected_step)
                            elif action == 'run_all':
                                self.run_all_pending()
                            
                            tty.setcbreak(fd)
        
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        
        self.console.print("\n[bright_cyan]Build session ended[/]")

def main():
    tui = GingerTUI()
    tui.run()

if __name__ == "__main__":
    main()
