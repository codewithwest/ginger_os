# ui/tui/screens.py

from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Static, Footer
from textual.containers import Container, Vertical
from rich.panel import Panel
from rich.text import Text
from rich import box
from config.constants import GINGER_BLUE, NEON_YELLOW, LASER_GREEN, LASER_RED

class HelpScreen(ModalScreen):
    """A modal screen that displays help information."""
    
    BINDINGS = [("escape,q,h", "dismiss", "Close")]

    def compose(self) -> ComposeResult:
        help_text = Text()
        
        help_text.append("GINGER_OS NEURAL_INTERFACE HELP\n", style=f"bold {GINGER_BLUE}")
        help_text.append("═" * 40 + "\n\n", style="dim")
        
        commands = [
            ("ENTER", "Execute selected module", NEON_YELLOW),
            ("A", "Toggle AI Automation mode", LASER_GREEN),
            ("F", "Force execution (skip check)", LASER_RED),
            ("X", "Abort active module", LASER_RED),
            ("H / ESC", "Toggle this help matrix", GINGER_BLUE),
            ("Q", "Emergency disconnect (Quit)", LASER_RED),
        ]
        
        for key, desc, color in commands:
            help_text.append(f" {key:<8}", style=f"bold black on {color}")
            help_text.append(f" {desc}\n\n", style="white")
            
        help_text.append("\n" + "═" * 40 + "\n", style="dim")
        help_text.append("Neural Core v1.0.0", style="dim italic")

        yield Container(
            Vertical(
                Static(Panel(help_text, border_style=GINGER_BLUE, box=box.DOUBLE_EDGE, padding=(1, 2))),
                id="help_content"
            )
        )
        yield Footer()

    CSS = """
    HelpScreen {
        align: center middle;
    }
    #help_content {
        width: 60;
        height: auto;
        background: $boost;
        border: thick $accent;
    }
    """
