import time
from rich.layout import Layout
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.align import Align
from rich.columns import Columns
from .constants import LOGO, LASER_GREEN, LASER_RED

def create_layout() -> Layout:
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=10),
        Layout(name="main"),
        Layout(name="footer", size=3)
    )
    
    layout["main"].split_row(
        Layout(name="side", ratio=1),
        Layout(name="body", ratio=2)
    )
    
    layout["side"].split_column(
        Layout(name="roadmap")
    )
    
    layout["body"].split_column(
        Layout(name="status", size=5),
        Layout(name="logs")
    )
    
    return layout

def format_time(seconds):
    if seconds is None: return "00:00"
    hours, remainder = divmod(int(seconds), 3600)
    mins, secs = divmod(remainder, 60)
    if hours > 0:
        return f"{hours:02d}:{mins:02d}:{secs:02d}"
    return f"{mins:02d}:{secs:02d}"

def update_ui(layout: Layout, engine):
    # Header
    layout["header"].update(Panel(
        Align.center(
            Columns([
                Text(LOGO, style="bold #00FFFF"), # Laser Blue/Cyan
                Text("\n\n🌶️ GingerOS Build System\nLFS 12.4 Automata\nCyberpunk Edition", style="bold #39FF14", justify="center") # Laser Green
            ])
        ),
        border_style="#00BFFF" # Laser Blue Border
    ))
    
    # Roadmap
    roadmap_table = Table(show_header=True, header_style="bold magenta", expand=True, box=None)
    roadmap_table.add_column("PHASE / STEP", style="bold white")
    roadmap_table.add_column("STAT", justify="right")
    
    last_phase = ""
    for step in engine.steps:
        if step.phase != last_phase:
            roadmap_table.add_row(f"[dim]─── {step.phase} ───[/dim]", "")
            last_phase = step.phase
        
        marker = " [ ]"
        style = "white"
        if step.status == "completed":
            marker = " [✓]"
            style = "green"
        elif step.status == "running":
            marker = " [▶]"
            style = "bold cyan"
        elif step.status == "failed":
            marker = " [✘]"
            style = "bold red"
            
        name = step.name[:17] + "..." if len(step.name) > 20 else step.name
        roadmap_table.add_row(Text(f"{marker} {name}", style=style), Text(step.status.upper(), style=style))
    
    layout["side"]["roadmap"].update(Panel(roadmap_table, title="[bold blue]Roadmap[/bold blue]", border_style="bright_blue"))
    
    # Status
    if engine.current_step_idx < len(engine.steps):
        current_step = engine.steps[engine.current_step_idx]
        overall_progress = (engine.current_step_idx / len(engine.steps)) * 100
        status_table = Table.grid(expand=True)
        
        overall_time = time.time() - engine.overall_start_time if engine.overall_start_time else 0
        overall_bar = "█" * int(overall_progress / 2.5) + "░" * (40 - int(overall_progress / 2.5))
        status_table.add_row(f"[bold cyan]OVERALL:[/bold cyan] [{LASER_GREEN}]{overall_bar}[/] {overall_progress:.0f}%  [bold magenta]⏱ {format_time(overall_time)}[/bold magenta]")
        
        phase_time = time.time() - engine.phase_start_time if engine.phase_start_time else 0
        status_table.add_row(f"[bold cyan]PHASE  :[/bold cyan] {current_step.name} ({current_step.phase}) [bold magenta]⏱ {format_time(phase_time)}[/bold magenta]")
        
        pkg_time = time.time() - engine.pkg_start_time if engine.pkg_start_time else 0
        pkg_display = engine.current_pkg or "Initializing..."
        if engine.paused_for_error:
            pkg_display = f"[bold red blink]FAILED: {pkg_display}[/bold red blink]"
        status_table.add_row(f"[bold yellow]PACKAGE:[/bold yellow] {pkg_display} [bold magenta]⏱ {format_time(pkg_time)}[/bold magenta]")
        
        layout["status"].update(Panel(status_table, title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))
    else:
        layout["status"].update(Panel(Align.center("[bold green]BUILD COMPLETE[/bold green]"), title="[bold blue]System Status[/bold blue]", border_style="bright_blue"))

    # Logs
    log_content = Text(no_wrap=True)
    # Increased lines since logs panel is now bigger
    log_slice = engine.logs[-25:] if engine.paused_for_error else engine.logs[-18:]
    for entry, style in log_slice:
        log_content.append(entry + "\n", style=style or "bright_white")
    
    layout["logs"].update(Panel(
        log_content, 
        title="[bold blue]Live Logs[/bold blue]", 
        border_style="bright_blue",
        padding=(0, 1)
    ))
    
    # Footer
    footer_text = "STATUS: RUNNING BUILD"
    footer_style = "bold yellow"
    if engine.paused_for_error:
        footer_text = "⚠️ ERROR: [bold white]R[/] Restart Phase | [bold white]P[/] Restart Pkg | [bold white]Ctrl+C[/] Abort"
        footer_style = "bold red"
    elif not engine.is_running:
        footer_text = f"CRITICAL ERROR: {engine.error_msg}" if engine.error_msg else "🎉 BUILD COMPLETED SUCCESSFULLY"
        footer_style = "bold red" if engine.error_msg else "bold green"
    
    layout["footer"].update(Panel(Align.center(Text(footer_text, style=footer_style)), border_style="bright_blue"))
