#!/usr/bin/env python3
import sys
import time
import threading
import signal
import subprocess
from rich.console import Console
from rich.live import Live
from lfs_builder_ui import GingerEngine, create_layout, update_ui, MASTER_LOG

def main():
    console = Console()
    engine = GingerEngine()
    layout = create_layout()
    
    def signal_handler(sig, frame):
        engine.abort()
        time.sleep(1)
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)

    # Initial sudo check
    try:
        subprocess.run(["sudo", "-v", "-n"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        console.print("[bold red]Error: Script must be run with sudo or have cached credentials.[/bold red]")
        sys.exit(1)

        # Fixed: We now initialize the Live context more carefully
        # and ensure the engine starts AFTER Live is ready.
        with Live(layout, refresh_per_second=4, screen=True) as live:
            # Start engine in separate thread
            build_thread = threading.Thread(target=engine.run)
            build_thread.start()
            
            while engine.is_running or engine.paused_for_error:
                update_ui(layout, engine)
                live.refresh()
                time.sleep(0.5)
                
            # Final update
            update_ui(layout, engine)
            time.sleep(1)
            
    except KeyboardInterrupt:
        engine.abort()
    except Exception as e:
        console.print(f"[bold red]UI Error: {str(e)}[/bold red]")
    finally:
        if not engine.aborted:
            if any(s.status == "failed" for s in engine.steps):
                console.print("\n[bold red]Build failed. Check the logs above.[/bold red]")
            else:
                console.print("\n[bold green]Success! GingerOS is ready.[/bold green]")
                console.print(f"Master log: {MASTER_LOG}")

if __name__ == "__main__":
    main()
