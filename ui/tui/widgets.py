# ui/tui/widgets.py

from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Static, ListItem, Label
from textual.reactive import reactive
from textual.containers import Vertical, Horizontal
from rich.text import Text
from rich.panel import Panel
from rich import box

from config.constants import (
    LOGO,
    GINGER_BLUE,
    NEON_YELLOW,
    NEON_MAGENTA,
    LASER_GREEN,
    LASER_RED,
    BRIGHT_WHITE,
    LFS_MOUNT
)
from ui.tui.themes.cyberpunk import get_pulsar
from ui.tui.utils.ai import get_ai_thought
from ui.tui.utils.time import format_time
import time
import os
import multiprocessing

class Branding(Static):
    """The GingerOS logo and version branding."""
    def on_mount(self) -> None:
        self.update(Text(LOGO.strip(), style=f"bold {GINGER_BLUE}"))

class NeuralCore(Static):
    """Displays AI thoughts and system status."""
    thought = reactive("")
    status = reactive("NEURAL_CORE_READY")
    
    def on_mount(self) -> None:
        self.set_interval(0.1, self.refresh_pulsar)
        
    def refresh_pulsar(self) -> None:
        pulsar = get_pulsar()
        content = Text()
        
        if self.app.state.executing_step is not None:
            step = self.app.engine.steps[self.app.state.executing_step]
            elapsed = time.time() - self.app.state.current_start_time
            
            content.append("🚀 SYSTEM_BUSY\n", style=f"bold {LASER_RED}")
            content.append(f"MODULE: {step.name}\n", style=f"bold {BRIGHT_WHITE}")
            
            # Package Progress
            if self.app.engine.current_pkg:
                content.append(f"PKG:    {self.app.engine.current_pkg} ", style=f"bold {GINGER_BLUE}")
                if self.app.engine.total_pkg_count > 0:
                    content.append(f"({self.app.engine.current_pkg_idx}/{self.app.engine.total_pkg_count})\n", style=NEON_YELLOW)
                else:
                    content.append("\n")

            content.append(f"UPTIME: {format_time(elapsed)}\n", style=NEON_YELLOW)
            content.append("\n🧠 AI_CORE:\n", style=f"bold {NEON_MAGENTA}")
            content.append(get_ai_thought(step.name), style="italic bright_blue")
            content.append(f"\n\n{pulsar} NEURAL_CORE_ACTIVE", style="dim cyan")
        else:
            content.append("🟢 NEURAL_CORE_READY\n", style=f"bold {LASER_GREEN}")
            content.append("\nAwaiting operator command...", style="dim italic")
            
        self.update(Panel(content, border_style=GINGER_BLUE, box=box.DOUBLE_EDGE))

class SystemMX(Static):
    """System stats (Matrix) widget."""
    def on_mount(self) -> None:
        self.set_interval(2.0, self.update_stats)
        self.update_stats()
        
    def update_stats(self) -> None:
        text = Text()
        text.append("\n 🖥️ HOST_NODE\n", style=f"bold {BRIGHT_WHITE}")
        
        try:
            load = os.getloadavg()
            text.append(f"  LOAD:  {load[0]:.2f} {load[1]:.2f} {load[2]:.2f}\n", style=GINGER_BLUE)
        except: pass
        
        try:
            cores = multiprocessing.cpu_count()
            text.append(f"  CORES: {cores}\n", style=LASER_GREEN)
        except: pass

        # Storage Stats
        text.append("\n 💾 STORAGE\n", style=f"bold {BRIGHT_WHITE}")
        stats = self.app.engine.storage_stats
        for key, val in stats.items():
            color = LASER_RED if val > 90 else (NEON_YELLOW if val > 70 else LASER_GREEN)
            text.append(f"  {key.upper():<5}: ", style="dim")
            text.append(f"{val:>5.1f}%\n", style=color)
        
        self.update(Panel(text, title="[bold bright_blue]══ SYS_MX ══[/]", border_style=GINGER_BLUE, box=box.ROUNDED))

class StepItem(ListItem):
    """A single build step in the list."""
    def __init__(self, step, index: int):
        super().__init__()
        self.step = step
        self.index = index
        # Set initial status classes
        self.set_class(self.step.status == "completed", "completed")
        self.set_class(self.step.status == "failed", "failed")
        self.set_class(self.step.status == "running", "running")
        
    def compose(self) -> ComposeResult:
        with Horizontal():
            yield Label(f"{self.index+1:02d}", classes="step-index")
            yield Label(self.step.name, classes="step-name")
            yield Label(self.get_status_text(), classes="step-status", id=f"status-{self.index}")

    def get_status_text(self) -> str:
        if self.step.status == "completed":
            return "✔ COMPLETE"
        elif self.step.status == "failed":
            return "✘ FAILED"
        elif self.step.status == "running":
            return "▶ RUNNING"
        return "◐ PENDING"
    
    def update_status(self):
        label = self.query_one(f"#status-{self.index}", Label)
        label.update(self.get_status_text())
        self.set_class(self.step.status == "completed", "completed")
        self.set_class(self.step.status == "failed", "failed")
        self.set_class(self.step.status == "running", "running")
