# ui/tui/__init__.py

"""
GingerOS Neural TUI Package
===========================

High-performance command-first terminal interface
for orchestrating GingerOS build operations.

Modules:
    - app
    - state
    - renderers
    - handlers
    - themes
    - utils

Author: GingerOS
"""

from ui.tui.app import GingerTUI
from ui.tui.state import TUIState

__version__ = "1.0.0"
__author__ = "GingerOS"

PACKAGE_NAME = "ginger-tui"

DEFAULT_THEME = "cyberpunk"

SUPPORTED_THEMES = [
    "cyberpunk",
]

__all__ = [
    "GingerTUI",
    "TUIState",
]
