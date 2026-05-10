# ui/tui/renderers/footer.py

from rich.panel import Panel
from rich.align import Align
from rich.text import Text
from rich import box


def render_footer(app):

    footer = Text()

    commands = [
        ("↵", "EXECUTE", "bright_green"),
        ("A", "AUTO", "bright_cyan"),
        ("F", "FORCE", "bright_yellow"),
        ("Q", "QUIT", "bright_red"),
    ]

    for key, label, color in commands:

        footer.append(
            f" {key} ",
            style=f"bold black on {color}",
        )

        footer.append(
            f" {label}  ",
            style="dim",
        )

    return Panel(
        Align.center(footer),
        border_style=app.theme_color,
        box=box.SIMPLE,
    )
