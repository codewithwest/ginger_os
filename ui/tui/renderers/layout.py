# ui/tui/renderers/layout.py

from rich.layout import Layout


def create_layout():

    layout = Layout()

    layout.split_column(
        Layout(name="header", size=12),
        Layout(name="body", ratio=1),
        Layout(name="footer", size=3),
    )

    layout["body"].split_row(
        Layout(name="left_col", ratio=12),
        Layout(name="terminal", ratio=28),
    )

    layout["left_col"].split_column(
        Layout(name="steps", ratio=2),
        Layout(name="matrix", ratio=1),
    )

    return layout
