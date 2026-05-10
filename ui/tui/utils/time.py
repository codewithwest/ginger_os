# ui/tui/utils/time.py

def format_time(seconds):

    minutes, seconds = divmod(
        int(seconds),
        60,
    )

    return f"{minutes:02d}:{seconds:02d}"
