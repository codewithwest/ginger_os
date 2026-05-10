#!/usr/bin/env python3

import argparse
from ui.tui.app import GingerTUI


def main():
    parser = argparse.ArgumentParser(description="GingerOS Neural TUI")
    parser.add_argument("--dry-run", action="store_true", help="Run in dry-run mode")
    args = parser.parse_args()

    app = GingerTUI(dry_run=args.dry_run)
    app.run()


if __name__ == "__main__":
    main()
