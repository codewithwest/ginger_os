#!/usr/bin/env python3
"""
GingerOS Interactive TUI - K9s-style interface
Keyboard-driven terminal UI for managing GingerOS builds
"""

import sys
import os
import subprocess
from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.live import Live
from rich.text import Text
from rich import box
import time
import termios
import tty
import select

# Add parent directory to path to import engine
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lfs_builder_ui import GingerEngine

class GingerTUI:
    def __init__(self):
        self.engine = GingerEngine()
        self.console = Console()
        self.selected_idx = 0
        self.running = True
        self.show_help = False
        self.filter_mode = "all"  # all, pending, complete
        self.last_refresh = time.time()
        
    def get_filtered_steps(self):
        """Get steps based on current filter"""
        if self.filter_mode == "pending":
            return [(i, s) for i, s in enumerate(self.engine.steps) if not self.engine._should_skip(s)]
        elif self.filter_mode == "complete":
            return [(i, s) for i, s in enumerate(self.engine.steps) if self.engine._should_skip(s)]
        else:  # all
            return list(enumerate(self.engine.steps))
    
    def create_header(self):
        """Create header panel"""
        title = Text()
        title.append("🌶️  GingerOS Build System  🌶️", style="bold cyan")
        
        stats = Text()
        total = len(self.engine.steps)
        complete = sum(1 for s in self.engine.steps if self.engine._should_skip(s))
        pending = total - complete
        
        stats.append(f"Total: {total}  ", style="dim")
        stats.append(f"✓ Complete: {complete}  ", style="green")
        stats.append(f"○ Pending: {pending}", style="yellow")
        
        header = Table.grid(padding=1)
        header.add_column(justify="center")
        header.add_column(justify="right")
        header.add_row(title, stats)
        
        return Panel(header, box=box.ROUNDED, border_style="cyan")
    
    def create_steps_table(self):
        """Create main steps table"""
        table = Table(
            show_header=True,
            header_style="bold cyan",
            box=box.SIMPLE_HEAVY,
            expand=True,
            highlight=True
        )
        
        table.add_column("#", style="dim", width=4, justify="right")
        table.add_column("Status", width=8, justify="center")
        table.add_column("Step Name", style="bold")
        table.add_column("Phase", style="yellow", width=20)
        table.add_column("ID", style="dim", width=20)
        
        filtered_steps = self.get_filtered_steps()
        
        for display_idx, (actual_idx, step) in enumerate(filtered_steps):
            # Determine status
            if self.engine._should_skip(step):
                status = "[green]✓[/green]"
                status_text = "Complete"
            else:
                status = "[dim]○[/dim]"
                status_text = "Pending"
            
            # Highlight selected row
            if display_idx == self.selected_idx:
                style = "black on cyan"
                num = f"[{style}]▶ {actual_idx + 1}[/{style}]"
                status_col = f"[{style}]{status_text}[/{style}]"
                name_col = f"[{style}]{step.name}[/{style}]"
                phase_col = f"[{style}]{step.phase}[/{style}]"
                id_col = f"[{style}]{step.id}[/{style}]"
            else:
                num = str(actual_idx + 1)
                status_col = status_text
                name_col = step.name
                phase_col = step.phase
                id_col = step.id
            
            table.add_row(num, status_col, name_col, phase_col, id_col)
        
        return table
    
    def create_footer(self):
        """Create footer with keyboard shortcuts"""
        if self.show_help:
            help_text = Text()
            help_text.append("Keyboard Shortcuts:\n", style="bold cyan")
            help_text.append("  ↑/k      ", style="yellow")
            help_text.append("Move up\n")
            help_text.append("  ↓/j      ", style="yellow")
            help_text.append("Move down\n")
            help_text.append("  ENTER    ", style="green")
            help_text.append("Run selected step\n")
            help_text.append("  f        ", style="cyan")
            help_text.append("Force run (ignore marker)\n")
            help_text.append("  d        ", style="red")
            help_text.append("Delete marker\n")
            help_text.append("  a        ", style="magenta")
            help_text.append("Show all steps\n")
            help_text.append("  p        ", style="magenta")
            help_text.append("Show pending only\n")
            help_text.append("  c        ", style="magenta")
            help_text.append("Show complete only\n")
            help_text.append("  r        ", style="blue")
            help_text.append("Refresh status\n")
            help_text.append("  ?        ", style="dim")
            help_text.append("Toggle this help\n")
            help_text.append("  q/ESC    ", style="red")
            help_text.append("Quit\n")
            
            return Panel(help_text, title="Help", border_style="yellow", box=box.ROUNDED)
        else:
            shortcuts = Text()
            shortcuts.append("↑↓/jk", style="yellow")
            shortcuts.append("=nav  ", style="dim")
            shortcuts.append("ENTER", style="green")
            shortcuts.append("=run  ", style="dim")
            shortcuts.append("f", style="cyan")
            shortcuts.append("=force  ", style="dim")
            shortcuts.append("d", style="red")
            shortcuts.append("=delete  ", style="dim")
            shortcuts.append("a/p/c", style="magenta")
            shortcuts.append("=filter  ", style="dim")
            shortcuts.append("r", style="blue")
            shortcuts.append("=refresh  ", style="dim")
            shortcuts.append("?", style="yellow")
            shortcuts.append("=help  ", style="dim")
            shortcuts.append("q", style="red")
            shortcuts.append("=quit", style="dim")
            
            filter_text = Text()
            filter_text.append(f"  Filter: ", style="dim")
            filter_text.append(f"{self.filter_mode.upper()}", style="bold cyan")
            
            footer_grid = Table.grid(padding=1)
            footer_grid.add_column(justify="left")
            footer_grid.add_column(justify="right")
            footer_grid.add_row(shortcuts, filter_text)
            
            return Panel(footer_grid, border_style="dim", box=box.ROUNDED)
    
    def create_layout(self):
        """Create the full layout"""
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=5),
            Layout(name="body"),
            Layout(name="footer", size=3 if not self.show_help else 18)
        )
        
        layout["header"].update(self.create_header())
        layout["body"].update(self.create_steps_table())
        layout["footer"].update(self.create_footer())
        
        return layout
    
    def get_selected_step(self):
        """Get the currently selected step"""
        filtered_steps = self.get_filtered_steps()
        if 0 <= self.selected_idx < len(filtered_steps):
            actual_idx, step = filtered_steps[self.selected_idx]
            return actual_idx, step
        return None, None
    
    def run_step(self, force=False):
        """Run the selected step"""
        actual_idx, step = self.get_selected_step()
        if step is None:
            return
        
        # Check if already complete
        if self.engine._should_skip(step) and not force:
            self.console.print("\n[yellow]⚠ Step already complete. Use 'f' to force run.[/yellow]")
            input("\nPress ENTER to continue...")
            return
        
        # Clear screen and run
        self.console.clear()
        self.console.print(Panel(
            f"[bold]{step.name}[/bold]\n"
            f"Phase: {step.phase}\n"
            f"Command: [dim]{step.command}[/dim]",
            title=f"Running Step {actual_idx + 1}/{len(self.engine.steps)}",
            border_style="green"
        ))
        
        # Execute
        self.engine.current_step_idx = actual_idx
        self.engine._execute_step(step)
        
        # Show result
        if step.status == "completed":
            self.console.print("\n[bold green]✓ Step completed successfully[/bold green]")
        else:
            self.console.print("\n[bold red]✗ Step failed[/bold red]")
            self.console.print(f"[dim]Log: {step.log_file}[/dim]")
        
        input("\nPress ENTER to continue...")
    
    def delete_marker(self):
        """Delete marker for selected step"""
        actual_idx, step = self.get_selected_step()
        if step is None:
            return
        
        if not self.engine._should_skip(step):
            self.console.print("\n[yellow]No marker exists for this step[/yellow]")
            input("\nPress ENTER to continue...")
            return
        
        # Delete markers
        from lfs_builder_ui.constants import STATE_DIR
        marker_paths = [
            os.path.join(STATE_DIR, f"{step.id}.built"),
            f"/mnt/lfs/var/lib/ginger/{step.id}.built",
        ]
        
        deleted = False
        for path in marker_paths:
            if os.path.exists(path):
                try:
                    os.remove(path)
                    deleted = True
                except Exception as e:
                    self.console.print(f"[red]Failed to delete {path}: {e}[/red]")
        
        if deleted:
            self.console.print(f"\n[green]✓ Marker deleted for: {step.name}[/green]")
        else:
            self.console.print(f"\n[yellow]No marker files found[/yellow]")
        
        input("\nPress ENTER to continue...")
    
    def handle_key(self, key):
        """Handle keyboard input"""
        filtered_steps = self.get_filtered_steps()
        max_idx = len(filtered_steps) - 1
        
        if key in ['q', '\x1b']:  # q or ESC
            self.running = False
        
        elif key == '?':
            self.show_help = not self.show_help
        
        elif key in ['j', '\x1b[B']:  # j or DOWN arrow
            if self.selected_idx < max_idx:
                self.selected_idx += 1
        
        elif key in ['k', '\x1b[A']:  # k or UP arrow
            if self.selected_idx > 0:
                self.selected_idx -= 1
        
        elif key == '\r' or key == '\n':  # ENTER
            return 'run'
        
        elif key == 'f':
            return 'force'
        
        elif key == 'd':
            return 'delete'
        
        elif key == 'a':
            self.filter_mode = "all"
            self.selected_idx = 0
        
        elif key == 'p':
            self.filter_mode = "pending"
            self.selected_idx = 0
        
        elif key == 'c':
            self.filter_mode = "complete"
            self.selected_idx = 0
        
        elif key == 'r':
            # Refresh - just redraw
            pass
        
        return None
    
    def run(self):
        """Main TUI loop"""
        # Set up terminal for raw input
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        
        try:
            tty.setcbreak(fd)
            
            with Live(self.create_layout(), refresh_per_second=4, screen=True) as live:
                while self.running:
                    # Update display
                    live.update(self.create_layout())
                    
                    # Check for input (non-blocking)
                    if select.select([sys.stdin], [], [], 0.1)[0]:
                        key = sys.stdin.read(1)
                        
                        # Handle arrow keys (multi-byte sequences)
                        if key == '\x1b':
                            next_chars = sys.stdin.read(2)
                            key = key + next_chars
                        
                        action = self.handle_key(key)
                        
                        if action == 'run':
                            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                            self.run_step(force=False)
                            tty.setcbreak(fd)
                        
                        elif action == 'force':
                            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                            self.run_step(force=True)
                            tty.setcbreak(fd)
                        
                        elif action == 'delete':
                            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                            self.delete_marker()
                            tty.setcbreak(fd)
        
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        
        self.console.print("\n[cyan]Goodbye![/cyan]")

def main():
    tui = GingerTUI()
    tui.run()

if __name__ == "__main__":
    main()
