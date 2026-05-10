# ui/tui/renderers/header.py

from rich.panel import Panel
from rich.align import Align
from rich.columns import Columns
from rich.text import Text
from rich import box

from config.constants import LOGO

from ui.tui.utils.ai import get_ai_thought
from ui.tui.utils.time import format_time
from ui.tui.themes.cyberpunk import get_pulsar

import time


def render_header(app):

    pulsar = get_pulsar()

    branding = Text(
        "\n" + LOGO.strip() + "\n",
        style=f"bold {app.theme_secondary_color}",
    )

    metrics = Text()

    if app.state.executing_step is not None:

        step = app.engine.steps[app.state.executing_step]

        elapsed = (
            time.time() -
            app.state.current_start_time
        )

        metrics.append(
            "🚀 SYSTEM_BUSY\n",
            style="bold bright_red",
        )

        metrics.append(
            f"MODULE: {step.name}\n",
            style="bold bright_white",
        )

        metrics.append(
            f"UPTIME: {format_time(elapsed)}\n",
            style="bright_yellow",
        )

        metrics.append(
            "\n🧠 AI_CORE:\n",
            style="bold bright_magenta",
        )

        metrics.append(
            get_ai_thought(step.name),
            style="italic bright_blue",
        )

        metrics.append(
            f"\n\n{pulsar} NEURAL_CORE_READY",
            style="dim cyan",
        )

    else:

        metrics.append(
            "🟢 NEURAL_CORE_READY\n",
            style=f"bold {app.theme_color}",
        )

        metrics.append(
            "\nAwaiting operator command...",
            style="dim italic",
        )

    return Panel(
        Columns(
            [
                Align.left(branding),
                Align.right(metrics),
            ],
            expand=True,
        ),
        border_style=app.theme_color,
        box=box.DOUBLE_EDGE,
        title="[bold bright_blue] NEURAL_SYSTEM_INTERFACE [/]",
    )
