# ui/tui/renderers/help.py

from rich.panel import Panel
from rich.align import Align
from rich.text import Text
from rich import box


def render_help(app):

    text = Text()

    text.append(
        "\n[ NEURAL_LINK_COMMANDS ]\n\n",
        style="bold bright_cyan",
    )

    commands = [
        ("ENTER", "Execute Module"),
        ("A", "Toggle Auto"),
        ("F", "Force Run"),
        ("Q", "Quit"),
    ]

    for key, desc in commands:

        text.append(
            f" {key:8s}",
            style="bold bright_white",
        )

        text.append(
            f" {desc}\n",
            style="dim",
        )

    return Panel(
        Align.center(text),
        title="[bold bright_blue] HELP_ENVIRONMENT [/]",
        border_style=app.theme_color,
        box=box.DOUBLE_EDGE,
    )
