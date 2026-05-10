# ui/tui/renderers/terminal.py

from rich.panel import Panel
from rich.text import Text
from rich import box


def render_terminal(app):

    text = Text()

    if app.engine.logs:

        for entry, style in app.engine.logs[-28:]:

            text.append(
                " >_ ",
                style="bold bright_cyan",
            )

            text.append(
                entry + "\n",
                style=style or "white",
            )

    else:

        text.append(
            "\n[ TERMINAL_STANDBY ]",
            style="bold dim cyan",
        )

    return Panel(
        text,
        title="[bold bright_blue]══ TERMINAL_STREAM ══[/]",
        border_style=app.theme_color,
        box=box.SQUARE,
    )
