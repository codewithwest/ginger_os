# ui/tui/themes/cyberpunk.py

import time


def get_pulsar():

    frames = [
        "|",
        "/",
        "-",
        "\\",
    ]

    idx = int(
        time.time() * 8
    ) % len(frames)

    return frames[idx]
