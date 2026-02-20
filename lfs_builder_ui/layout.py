import time
from rich.layout import Layout
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.align import Align
from rich.columns import Columns
from .constants import LOGO, LASER_GREEN, LASER_RED, ELECTRIC_BLUE, LASER_BLUE, GINGER_BLUE

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
    layout["header"].update(Panel(
        Align.center(
            Columns([
                # Use bright colors for transparent terminals
                Text(LOGO, style=f"bold {GINGER_BLUE}"),
                Text("\n\n🌶️ GingerOS Build System\nLFS 12.4", style=f"bold {LASER_GREEN}", justify="center")
            ])
        ),
        border_style=f"bold {LASER_BLUE}"
    ))
    
    # Roadmap
    roadmap_table = Table(show_header=True, header_style="bold bright_magenta", expand=True, box=None)
    roadmap_table.add_column("PHASE / STEP", style="bold bright_white")
    roadmap_table.add_column("STAT", justify="right")
    
    last_phase = ""
    for step in engine.steps:
        if step.phase != last_phase:
            roadmap_table.add_row(f"[dim]─── {step.phase} ───[/dim]", "")
            last_phase = step.phase
        
        marker = " [ ]"
        style = "bright_white"
        if step.status == "completed":
            marker = " [✓]"
            style = "bright_green"
        elif step.status == "running":
            marker = " [▶]"
            style = "bold bright_cyan"
        elif step.status == "failed":
            marker = " [✘]"
            style = "bold bright_red"
            
        name = step.name[:17] + "..." if len(step.name) > 20 else step.name
        roadmap_table.add_row(Text(f"{marker} {name}", style=style), Text(step.status.upper(), style=style))
    
    layout["side"]["roadmap"].update(Panel(roadmap_table, title="[bold bright_blue]Roadmap[/bold bright_blue]", border_style="bold bright_blue"))
    
    # Status
    if engine.current_step_idx < len(engine.steps):
        current_step = engine.steps[engine.current_step_idx]
        overall_progress = (engine.current_step_idx / len(engine.steps)) * 100
        status_table = Table.grid(expand=True)
        
        overall_time = time.time() - engine.overall_start_time if engine.overall_start_time else 0
        overall_bar = "█" * int(overall_progress / 2.5) + "░" * (40 - int(overall_progress / 2.5))
        status_table.add_row(f"[bold bright_cyan]OVERALL:[/bold bright_cyan] [{LASER_GREEN}]{overall_bar}[/] {overall_progress:.0f}%  [bold bright_magenta]⏱ {format_time(overall_time)}[/bold bright_magenta]")
        
        phase_time = time.time() - engine.phase_start_time if engine.phase_start_time else 0
        status_table.add_row(f"[bold bright_cyan]PHASE  :[/bold bright_cyan] {current_step.name} ({current_step.phase}) [bold bright_magenta]⏱ {format_time(phase_time)}[/bold bright_magenta]")
        
        pkg_time = time.time() - engine.pkg_start_time if engine.pkg_start_time else 0
        pkg_display = engine.current_pkg or "Initializing..."
        if engine.paused_for_error:
            pkg_display = f"[bold bright_red blink]FAILED: {pkg_display}[/bold bright_red blink]"
        status_table.add_row(f"[bold bright_yellow]PACKAGE:[/bold bright_yellow] {pkg_display} [bold bright_magenta]⏱ {format_time(pkg_time)}[/bold bright_magenta]")
        
        # Storage Monitoring
        host_color = LASER_RED if engine.storage_stats["host"] > 90 else ELECTRIC_BLUE
        lfs_color = LASER_RED if engine.storage_stats["lfs"] > 90 else LASER_GREEN
        
        host_bar = "█" * int(engine.storage_stats["host"] / 5) + "░" * (20 - int(engine.storage_stats["host"] / 5))
        lfs_bar = "█" * int(engine.storage_stats["lfs"] / 5) + "░" * (20 - int(engine.storage_stats["lfs"] / 5))
        
        storage_row = Columns([
            Text.from_markup(f"[bold cyan]STORAGE (Host):[/][{host_color}]{host_bar}[/] {engine.storage_stats['host']:.0f}% "),
            Text.from_markup(f"[bold cyan](LFS):[/][{lfs_color}]{lfs_bar}[/] {engine.storage_stats['lfs']:.0f}%")
        ])
        status_table.add_row(storage_row)
        
        layout["status"].update(Panel(status_table, title="[bold bright_blue]System Status[/bold bright_blue]", border_style="bold bright_blue"))
    else:
        layout["status"].update(Panel(Align.center("[bold bright_green]BUILD COMPLETE[/bold bright_green]"), title="[bold bright_blue]System Status[/bold bright_blue]", border_style="bold bright_blue"))

    # Logs
    log_content = Text(no_wrap=True)
    # Increased lines since logs panel is now bigger
    log_slice = engine.logs[-25:] if engine.paused_for_error else engine.logs[-18:]
    for entry, style in log_slice:
        log_content.append(entry + "\n", style=style or "bright_white")
    
    layout["logs"].update(Panel(
        log_content, 
        title="[bold bright_blue]Live Logs[/bold bright_blue]", 
        border_style="bold bright_blue",
        padding=(0, 1)
    ))
    
    # Footer with keyboard shortcuts
    footer_text = Text()
    footer_style = "bold yellow"
    
    if engine.paused_for_error:
        footer_text.append("⚠️ ERROR: ", style="bold red")
        footer_text.append("R", style="bold white on red")
        footer_text.append(" Restart Phase | ", style="bold red")
        footer_text.append("P", style="bold white on red")
        footer_text.append(" Restart Pkg | ", style="bold red")
        footer_text.append("Ctrl+C", style="bold white on red")
        footer_text.append(" Abort", style="bold red")
    elif not engine.is_running:
        footer_msg = f"CRITICAL ERROR: {engine.error_msg}" if engine.error_msg else "🎉 BUILD COMPLETED SUCCESSFULLY"
        footer_text.append(footer_msg, style="bold red" if engine.error_msg else "bold green")
    else:
        # Show keyboard shortcuts during normal operation
        footer_text.append("⚡ CONTROLS: ", style="bold cyan")
        footer_text.append("SPACE", style="bold white on blue")
        footer_text.append("=Pause ", style="dim")
        footer_text.append("N", style="bold white on green")
        footer_text.append("=Next ", style="dim")
        footer_text.append("S", style="bold white on yellow")
        footer_text.append("=Skip ", style="dim")
        footer_text.append("J", style="bold white on magenta")
        footer_text.append("=Jump ", style="dim")
        footer_text.append("L", style="bold white on cyan")
        footer_text.append("=List ", style="dim")
        footer_text.append("?", style="bold white on blue")
        footer_text.append("=Help ", style="dim")
        footer_text.append("Q", style="bold white on red")
        footer_text.append("=Quit", style="dim")
    
    layout["footer"].update(Panel(Align.center(footer_text), border_style="bold bright_blue"))
