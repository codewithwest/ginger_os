#!/usr/bin/env python3
import sys
import time
import threading
import signal
import subprocess
import argparse
from rich.console import Console
from rich.live import Live
from rich.table import Table
from rich.panel import Panel
from lfs_builder_ui import GingerEngine, create_layout, update_ui, MASTER_LOG

def list_steps(engine):
    """Display all available build steps"""
    console = Console()
    
    table = Table(title="GingerOS Build Steps", show_header=True, header_style="bold cyan")
    table.add_column("#", style="dim", width=4)
    table.add_column("Step ID", style="cyan")
    table.add_column("Name", style="green")
    table.add_column("Phase", style="yellow")
    table.add_column("Status", style="magenta")
    
    for idx, step in enumerate(engine.steps, 1):
        status = "✓ Complete" if engine._should_skip(step) else "○ Pending"
        table.add_row(str(idx), step.id, step.name, step.phase, status)
    
    console.print(table)
    console.print(f"\n[dim]Total steps: {len(engine.steps)}[/dim]")
    console.print("[dim]Use: python3 ginger_os.py --step <number> to run a specific step[/dim]")
    console.print("[dim]Use: python3 ginger_os.py --interactive for step-by-step mode[/dim]")

def show_markers(engine):
    """Display marker status for all steps"""
    console = Console()
    
    console.print("\n[bold cyan]Marker Status:[/bold cyan]\n")
    
    for idx, step in enumerate(engine.steps, 1):
        has_marker = engine._should_skip(step)
        marker_symbol = "[green]✓[/green]" if has_marker else "[dim]○[/dim]"
        console.print(f"{marker_symbol} [{idx:2d}] {step.name}")
    
    console.print("\n[dim]Markers are stored in: /mnt/lfs/var/lib/ginger/ and .build_state/[/dim]")

def run_single_step(engine, step_num, force=False):
    """Run a single step by number"""
    console = Console()
    
    if step_num < 1 or step_num > len(engine.steps):
        console.print(f"[bold red]Error: Step number must be between 1 and {len(engine.steps)}[/bold red]")
        return False
    
    step = engine.steps[step_num - 1]
    
    # Show step info
    console.print(Panel(
        f"[bold]{step.name}[/bold]\n"
        f"Phase: {step.phase}\n"
        f"Command: [dim]{step.command}[/dim]",
        title=f"Step {step_num}/{len(engine.steps)}",
        border_style="cyan"
    ))
    
    # Check if already complete
    if engine._should_skip(step) and not force:
        console.print("[yellow]⚠ Step already complete (marker exists)[/yellow]")
        console.print("[dim]Use --force to run anyway[/dim]")
        return True
    
    # Run the step
    console.print(f"\n[bold green]▶ Running step...[/bold green]\n")
    
    engine.current_step_idx = step_num - 1
    engine._execute_step(step)
    
    if step.status == "completed":
        console.print(f"\n[bold green]✓ Step completed successfully[/bold green]")
        return True
    else:
        console.print(f"\n[bold red]✗ Step failed[/bold red]")
        console.print(f"[dim]Check log: {step.log_file}[/dim]")
        return False

def run_interactive_mode(engine):
    """Run build in interactive keyboard-driven mode"""
    console = Console()
    
    console.print(Panel(
        "[bold cyan]Interactive Build Mode[/bold cyan]\n\n"
        "Controls:\n"
        "  [green]ENTER[/green]     - Run current step\n"
        "  [yellow]s[/yellow]       - Skip current step\n"
        "  [cyan]f[/cyan]       - Force run (ignore markers)\n"
        "  [magenta]j[/magenta]       - Jump to step number\n"
        "  [blue]l[/blue]       - List all steps\n"
        "  [red]q[/red]       - Quit\n",
        border_style="cyan"
    ))
    
    current_idx = 0
    
    while current_idx < len(engine.steps):
        step = engine.steps[current_idx]
        step_num = current_idx + 1
        
        # Show current step
        console.print(f"\n{'='*60}")
        console.print(f"[bold]Step {step_num}/{len(engine.steps)}: {step.name}[/bold]")
        console.print(f"Phase: [yellow]{step.phase}[/yellow]")
        console.print(f"Command: [dim]{step.command}[/dim]")
        
        # Check marker status
        has_marker = engine._should_skip(step)
        if has_marker:
            console.print("[green]✓ Marker exists (already complete)[/green]")
        else:
            console.print("[dim]○ No marker (not yet run)[/dim]")
        
        console.print(f"{'='*60}")
        
        # Get user input
        console.print("\n[cyan]Action?[/cyan] [dim](ENTER=run, s=skip, f=force, j=jump, l=list, q=quit)[/dim]: ", end="")
        action = input().strip().lower()
        
        if action == 'q':
            console.print("[yellow]Exiting interactive mode[/yellow]")
            break
        
        elif action == 'l':
            list_steps(engine)
            continue
        
        elif action == 'j':
            console.print("Jump to step number: ", end="")
            try:
                jump_num = int(input().strip())
                if 1 <= jump_num <= len(engine.steps):
                    current_idx = jump_num - 1
                    console.print(f"[green]Jumped to step {jump_num}[/green]")
                else:
                    console.print(f"[red]Invalid step number. Must be 1-{len(engine.steps)}[/red]")
            except ValueError:
                console.print("[red]Invalid input. Please enter a number.[/red]")
            continue
        
        elif action == 's':
            console.print("[yellow]Skipping step[/yellow]")
            current_idx += 1
            continue
        
        elif action == 'f' or action == '' or action == '\n':
            # Force run or normal run
            force = (action == 'f')
            
            if has_marker and not force:
                console.print("[yellow]Step already complete. Use 'f' to force run.[/yellow]")
                current_idx += 1
                continue
            
            # Execute step
            console.print(f"\n[bold green]▶ Running step...[/bold green]\n")
            engine.current_step_idx = current_idx
            engine._execute_step(step)
            
            if step.status == "completed":
                console.print(f"\n[bold green]✓ Step completed successfully[/bold green]")
                current_idx += 1
            else:
                console.print(f"\n[bold red]✗ Step failed[/bold red]")
                console.print(f"[dim]Log: {step.log_file}[/dim]")
                console.print("\n[yellow]Continue anyway?[/yellow] [dim](y/N)[/dim]: ", end="")
                cont = input().strip().lower()
                if cont == 'y':
                    current_idx += 1
                else:
                    console.print("[red]Stopping at failed step[/red]")
                    break
        else:
            console.print("[red]Invalid action. Try again.[/red]")
    
    console.print("\n[bold cyan]Interactive mode finished[/bold cyan]")

def main():
    parser = argparse.ArgumentParser(
        description='GingerOS Build System - LFS 12.4',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 ginger_os.py                    # Run full automated build
  python3 ginger_os.py --list             # List all build steps
  python3 ginger_os.py --markers          # Show marker status
  python3 ginger_os.py --step 5           # Run step 5 only
  python3 ginger_os.py --step 10 --force  # Force run step 10 (ignore markers)
  python3 ginger_os.py --interactive      # Interactive step-by-step mode
        """
    )
    
    parser.add_argument('--interactive', '-i', action='store_true',
                       help='Run in interactive keyboard-driven mode')
    parser.add_argument('--step', '-s', type=int, metavar='N',
                       help='Run specific step by number (1-16)')
    parser.add_argument('--force', '-f', action='store_true',
                       help='Force run step even if marker exists')
    parser.add_argument('--list', '-l', action='store_true',
                       help='List all build steps with status')
    parser.add_argument('--markers', '-m', action='store_true',
                       help='Show marker status for all steps')
    
    args = parser.parse_args()
    
    console = Console()
    engine = GingerEngine()
    
    # Handle list command
    if args.list:
        list_steps(engine)
        return
    
    # Handle markers command
    if args.markers:
        show_markers(engine)
        return
    
    # Handle single step execution
    if args.step:
        success = run_single_step(engine, args.step, force=args.force)
        sys.exit(0 if success else 1)
    
    # Handle interactive mode
    if args.interactive:
        run_interactive_mode(engine)
        return
    
    # Default: Run full automated build with UI
    layout = create_layout()
    
    def signal_handler(sig, frame):
        engine.abort()
        time.sleep(1)
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start paused - wait for user command
    engine.paused_for_error = True  # Use this flag to pause at start
    engine.is_running = True
    
    with Live(layout, refresh_per_second=4, screen=True) as live:
        # Show initial state
        update_ui(layout, engine)
        live.update(layout)
        
        # Log welcome message
        engine.log("🌶️ GingerOS Build System Ready", "bold cyan")
        engine.log("=" * 60, "dim")
        engine.log("CONTROLS:", "bold yellow")
        engine.log("  SPACE or ENTER - Start/Resume build", "white")
        engine.log("  N - Skip to next step", "white")
        engine.log("  S - Skip current step", "white")
        engine.log("  L - List all steps", "white")
        engine.log("  ? - Show help", "white")
        engine.log("  Q - Quit", "white")
        engine.log("=" * 60, "dim")
        engine.log("⏸ Press SPACE or ENTER to start the build...", "bold green")
        
        # Start threads
        engine.sudo_thread.start()
        engine.kb_thread.start()
        
        # Wait for user to unpause
        while engine.paused_for_error and not engine.aborted:
            update_ui(layout, engine)
            live.update(layout)
            time.sleep(0.1)
        
        # If not aborted, run the build
        if not engine.aborted:
            engine.paused_for_error = False  # Ensure we're unpaused
            
            # Run build in separate thread
            build_thread = threading.Thread(target=engine.run)
            build_thread.start()
            
            # Update UI while build runs
            while build_thread.is_alive():
                update_ui(layout, engine)
                live.update(layout)
                time.sleep(0.25)
            
            build_thread.join()
    
    # Final status
    if engine.error_msg:
        console.print(f"\n[bold red]Build failed: {engine.error_msg}[/bold red]")
        sys.exit(1)
    else:
        console.print("\n[bold green]✓ Build completed successfully![/bold green]")
        console.print(f"Master log: {MASTER_LOG}")
        sys.exit(0)

if __name__ == "__main__":
    main()
