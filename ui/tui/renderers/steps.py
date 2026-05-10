# ui/tui/renderers/steps.py

from rich.table import Table
from rich.panel import Panel
from rich import box


def render_steps(app):

    table = Table(
        show_header=True,
        header_style="bold bright_cyan",
        box=box.SIMPLE,
        expand=True,
    )

    table.add_column(
        "SLOT",
        width=5,
        justify="center",
    )

    table.add_column(
        "MODULE",
    )

    table.add_column(
        "STATE",
        width=14,
        justify="right",
    )

    for idx, step in enumerate(app.engine.steps):

        active = (
            app.state.executing_step == idx
        )

        complete = (
            app.engine._should_skip(step)
        )

        if active:
            state = "[bold bright_cyan]▶ RUNNING[/]"
            style = "on blue3"

        elif complete:
            state = "[bold bright_green]✔ COMPLETE[/]"
            style = ""

        else:
            state = "[dim]◐ PENDING[/]"
            style = "dim"

        table.add_row(
            f"{idx + 1:02d}",
            step.name,
            state,
            style=style,
        )

    return Panel(
        table,
        title="[bold bright_blue] 0x_SEQUENCE [/]",
        border_style=app.theme_color,
        box=box.ROUNDED,
    )
