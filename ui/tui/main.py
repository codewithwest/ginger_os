#!/usr/bin/env python3

import sys

def main():
    print("======================================================================")
    print("⚠️  DEPRECATION NOTICE: PYTHON TUI IS DEPRECATED")
    print("======================================================================")
    print("The legacy Python TUI has been deprecated in favor of our modern,")
    print("high-performance Go HUD client (ginger-hud).")
    print("")
    print("To run the new HUD, please execute:")
    print("  cd ui/gotui && ./ginger-hud")
    print("======================================================================")
    sys.exit(0)

if __name__ == "__main__":
    main()
