# ui/tui/state.py

from dataclasses import dataclass
from typing import Optional
import threading


@dataclass
class TUIState:
    selected_step: int = 0
    running: bool = True

    executing_step: Optional[int] = None
    executing_thread: Optional[threading.Thread] = None

    current_start_time: float = 0

    show_help: bool = False

    auto_all: bool = False
    last_auto_step: Optional[int] = None

    log_scroll: int = 0
