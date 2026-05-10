# ui/tui/renderers/matrix.py

from rich.panel import Panel
from rich.text import Text
from rich import box

import multiprocessing
import os


def render_matrix(app):

    text = Text()

    text.append(
        "\n 🖥️ HOST\n",
        style="bold bright_white",
    )

    try:
        load = os.getloadavg()

        text.append(
            f"  LOAD: {load[0]:.2f}\n",
            style="bright_cyan",
        )

    except Exception:
        pass

    try:
        cores = multiprocessing.cpu_count()

        text.append(
            f"  CORES: {cores}\n",
            style="bright_green",
        )

    except Exception:
        pass

    return Panel(
        text,
        title="[bold bright_blue]══ SYS_MX ══[/]",
        border_style=app.theme_color,
        box=box.ROUNDED,
    )
