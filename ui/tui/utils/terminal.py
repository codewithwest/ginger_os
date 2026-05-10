# ui/tui/utils/terminal.py

import sys
import tty
import termios

from contextlib import contextmanager


@contextmanager
def terminal_mode():

    fd = sys.stdin.fileno()

    old_settings = termios.tcgetattr(fd)

    try:

        tty.setcbreak(fd)

        yield

    finally:

        termios.tcsetattr(
            fd,
            termios.TCSADRAIN,
            old_settings,
        )
