# ui/tui/renderers/__init__.py

from rich.panel import Panel
from rich import box

from ui.tui.renderers.header import render_header
from ui.tui.renderers.steps import render_steps
from ui.tui.renderers.matrix import render_matrix
from ui.tui.renderers.terminal import render_terminal
from ui.tui.renderers.footer import render_footer
from ui.tui.renderers.help import render_help


def update_layout(app, layout):

    layout["header"].update(
        render_header(app)
    )

    layout["footer"].update(
        render_footer(app)
    )

    if app.state.show_help:

        layout["steps"].update(
            render_help(app)
        )

        layout["matrix"].update(
            Panel(
                "",
                border_style=app.theme_color,
                box=box.ROUNDED,
            )
        )

        layout["terminal"].update(
            Panel(
                "",
                border_style=app.theme_color,
                box=box.SQUARE,
            )
        )

    else:

        layout["steps"].update(
            render_steps(app)
        )

        layout["matrix"].update(
            render_matrix(app)
        )

        layout["terminal"].update(
            render_terminal(app)
        )
