#!/usr/bin/env python3
import sys
import os

# Ensure the root directory is in the PYTHONPATH
root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_dir)

from server.engine import GingerEngine
from server.server import start_server

if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    port = 8087
    
    print("Initializing GingerOS Backend Engine...")
    engine = GingerEngine(dry_run=dry_run)
    
    print(f"Starting server on port {port}...")
    try:
        start_server(engine, host="127.0.0.1", port=port)
    except KeyboardInterrupt:
        print("\nShutdown requested by user.")
    finally:
        engine.abort()
        print("GingerOS Backend Engine stopped.")
