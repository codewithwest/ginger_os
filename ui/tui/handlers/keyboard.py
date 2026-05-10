# ui/tui/handlers/keyboard.py

import select
import sys

from ui.tui.handlers.actions import execute_action


def process_keyboard(app):

    if not select.select(
        [sys.stdin],
        [],
        [],
        0.05,
    )[0]:
        return

    key = sys.stdin.read(1)

    action = map_key(key)

    if action:
        execute_action(app, action)


def map_key(key):

    key = key.lower()

    if key == "q":
        return "quit"

    if key == "a":
        return "auto"

    if key in ("\r", "\n"):
        return "run"

    if key == "f":
        return "force"

    if key == "?":
        return "help"

    return None
