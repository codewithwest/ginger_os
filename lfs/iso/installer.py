#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import threading
import queue
from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.align import Align
from rich.live import Live
from rich import box
from rich.columns import Columns

# --- CONFIGURATION & BRANDING ---
LOGO = """
  _____ _                         ____   ______
 / ____(_)                       / __ \\ / ____|
| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ 
| | |_ | | '_ \\ / _` |/ _ \\ '__|| |  | |\\___ \\
| |__| | | | | | (_| |  __/ |   | |__| |____) |
 \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ 
                 __/ |                         
                |___/         v1.0.0 [Terminal UI Installer]
"""

THEME_COLOR = "bright_green"
SECONDARY_COLOR = "bright_blue"
ACCENT_COLOR = "bright_cyan"
LASER_RED = "bright_red"


class GingerInstaller:
    def __init__(self):
        self.console = Console()
        self.data = {
            "target_dev": "",
            "username": "ginger",
            "password": "",
            "root_password": "",
        }
        self.steps = [
            "Welcome",
            "Partitioning",
            "Extractions",
            "Hardware Sync",
            "User Setup",
            "Bootloader",
        ]
        self.current_step_idx = 0
        self.logs = collections.deque(maxlen=20)
        self.install_finished = False
        self.install_success = False
        self.log_queue = queue.Queue()

    def create_layout(self):
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=10),
            Layout(name="body", ratio=1),
            Layout(name="footer", size=3),
        )
        layout["body"].split_row(
            Layout(name="steps_col", ratio=1), Layout(name="main_col", ratio=3)
        )
        return layout

    def render_header(self):
        branding = Text(LOGO, style=f"bold {SECONDARY_COLOR}")
        metrics = Text("\n\n GINGER_OS INSTALLER ENGINE\n", style="bold white")
        metrics.append(f" STATE: [bold {THEME_COLOR}]READY[/]\n")
        metrics.append(f" MODE: [bold {ACCENT_COLOR}]RICH_TUI[/]", style="dim")

        return Panel(
            Columns(
                [
                    Align.left(branding, vertical="middle"),
                    Align.right(metrics, vertical="middle"),
                ],
                expand=True,
            ),
            border_style=THEME_COLOR,
            box=box.DOUBLE_EDGE,
        )

    def render_steps(self):
        table = Table(show_header=False, box=box.SIMPLE, expand=True)
        for i, step in enumerate(self.steps):
            if i < self.current_step_idx:
                style = f"{THEME_COLOR}"
                prefix = "✔ "
            elif i == self.current_step_idx:
                style = f"bold {ACCENT_COLOR}"
                prefix = "▶ "
            else:
                style = "dim"
                prefix = "○ "
            table.add_row(Text(f"{prefix}{step}", style=style))

        return Panel(table, title=" SEQUENCE ", border_style=THEME_COLOR)

    def render_footer(self):
        footer = Text(
            " [GingerOS Professional Deployment System] ",
            style=f"bold {THEME_COLOR}",
        )
        if not self.install_finished:
            footer.append(" | ", style="dim")
            footer.append("STATUS: ", style="dim")
            footer.append("INSTALLING...", style="bold yellow blink")
        else:
            footer.append(" | ", style="dim")
            footer.append("COMPLETE", style=f"bold {THEME_COLOR}")

        return Panel(Align.center(footer), border_style=THEME_COLOR, box=box.SIMPLE)

    def welcome_screen(self):
        welcome_text = Text(
            "\nWelcome to the GingerOS Professional Installation Suite.\n\n",
            style="bold white",
        )
        welcome_text.append(
            "This system will deploy a high-performance Linux From Scratch\n"
        )
        welcome_text.append("environment directly to your hardware.\n\n")
        welcome_text.append(
            "Press [ENTER] to initiate the deployment sequence...",
            style=f"bold {THEME_COLOR} blink",
        )

        body = Panel(
            Align.center(welcome_text, vertical="middle"),
            title=" WELCOME ",
            border_style=THEME_COLOR,
        )

        layout = self.create_layout()
        layout["header"].update(self.render_header())
        layout["steps_col"].update(self.render_steps())
        layout["main_col"].update(body)
        layout["footer"].update(self.render_footer())

        self.console.clear()
        self.console.print(layout)
        input()

    def disk_selection(self):
        while True:
            # Get disks
            try:
                output = subprocess.check_output(
                    ["lsblk", "-d", "-n", "-p", "-o", "NAME,SIZE,MODEL"], text=True
                )
                disks = [
                    line.strip()
                    for line in output.split("\n")
                    if line.strip() and "sr0" not in line and "loop" not in line
                ]
            except:
                disks = []

            table = Table(title="Available Storage Devices", border_style=ACCENT_COLOR)
            table.add_column("Dev", style="bold yellow")
            table.add_column("Size")
            table.add_column("Model")

            for d in disks:
                parts = d.split(None, 2)
                if len(parts) >= 2:
                    table.add_row(
                        parts[0], parts[1], parts[2] if len(parts) > 2 else ""
                    )

            layout = self.create_layout()
            layout["header"].update(self.render_header())
            layout["steps_col"].update(self.render_steps())
            layout["main_col"].update(
                Panel(
                    Align.center(table),
                    title=" DISK_SELECTION ",
                    border_style=THEME_COLOR,
                )
            )
            layout["footer"].update(self.render_footer())

            self.console.clear()
            self.console.print(layout)

            self.console.print(
                f"\n [bold {ACCENT_COLOR}]Enter target disk (e.g. /dev/sda):[/] ",
                end="",
            )
            dev = input().strip()
            if os.path.exists(dev) and dev.startswith("/dev/"):
                self.data["target_dev"] = dev
                break
            else:
                self.console.print(
                    f"[bold {LASER_RED}]Invalid device.[/] Press ENTER to retry."
                )
                input()

    def user_setup(self):
        layout = self.create_layout()
        layout["header"].update(self.render_header())
        layout["steps_col"].update(self.render_steps())

        setup_panel = Panel(
            Text(
                "\nDefining System Administrator Credentials...\n", style="dim italic"
            ),
            title=" USER_PROVISIONING ",
            border_style=THEME_COLOR,
        )
        layout["main_col"].update(setup_panel)
        layout["footer"].update(self.render_footer())

        self.console.clear()
        self.console.print(layout)

        self.console.print(f" [bold {ACCENT_COLOR}]Username:[/] ", end="")
        self.data["username"] = input().strip() or "ginger"

        self.console.print(
            f" [bold {ACCENT_COLOR}]Password for {self.data['username']}:[/] ", end=""
        )
        import getpass

        self.data["password"] = getpass.getpass("")

        self.console.print(f" [bold {ACCENT_COLOR}]Root Password:[/] ", end="")
        self.data["root_password"] = getpass.getpass("")

    def confirmation(self):
        conf_text = Text("\nFINAL DEPLOYMENT CONFIRMATION\n\n", style="bold red")
        conf_text.append(
            f" TARGET DISK: {self.data['target_dev']}\n", style="bold white"
        )
        conf_text.append(f" ADMINISTRATOR: {self.data['username']}\n\n")
        conf_text.append(
            " WARNING: ALL DATA ON THE TARGET DISK WILL BE DESTROYED!\n\n",
            style="bold yellow",
        )
        conf_text.append(
            "Type 'YES' to confirm and begin installation: ", style="bold white"
        )

        layout = self.create_layout()
        layout["header"].update(self.render_header())
        layout["steps_col"].update(self.render_steps())
        layout["main_col"].update(
            Panel(
                Align.center(conf_text, vertical="middle"),
                title=" DEPLOY_AUTH ",
                border_style="red",
            )
        )
        layout["footer"].update(self.render_footer())

        self.console.clear()
        self.console.print(layout)

        ans = input().strip().upper()
        if ans not in ["YES", "Y"]:
            self.console.print("[bold red]Installation aborted by user.[/]")
            sys.exit(0)

    def run_backend(self):
        env = os.environ.copy()
        env["TARGET_DEV"] = self.data["target_dev"]
        env["NEW_USER"] = self.data["username"]
        env["NEW_PASS"] = self.data["password"]
        env["ROOT_PASS"] = self.data["root_password"]
        env["GINGER_NON_INTERACTIVE"] = "1"

        try:
            # We call the bash installer script as the backend
            process = subprocess.Popen(
                ["/bin/bash", "./installer.sh", self.data["target_dev"]],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )

            for line in process.stdout:
                line = line.strip()
                if not line:
                    continue

                # Check for step markers from the UI library
                # The bash-ui uses ui_step <n>. We can match on progress or specific markers.
                # Since installer.sh uses ui_step, it might output something we can catch.
                # Actually ui_step calls ui_save_state which writes to a file.
                # But it also calls ui_log which appends to UI_LOG_FILE.
                # Let's just use the stdout for now.

                self.log_queue.put(line)

            process.wait()
            self.install_success = process.returncode == 0
        except Exception as e:
            self.log_queue.put(f"ERROR: {str(e)}")
            self.install_success = False
        finally:
            self.install_finished = True

    def installation_progress(self):
        # Start backend thread
        threading.Thread(target=self.run_backend, daemon=True).start()

        layout = self.create_layout()
        layout["header"].update(self.render_header())
        layout["steps_col"].update(self.render_steps())

        with Live(layout, refresh_per_second=10, screen=True) as live:
            while not self.install_finished:
                # Update logs
                try:
                    while True:
                        line = self.log_queue.get_nowait()
                        self.logs.append(line)

                        # Advance side menu based on [STEP X/6] markers from installer.sh
                        if "STEP 1/6" in line:
                            self.current_step_idx = 1  # Partitioning
                        elif "STEP 2/6" in line:
                            self.current_step_idx = 1  # Formatting (still Partitioning)
                        elif "STEP 3/6" in line:
                            self.current_step_idx = 1  # Mounting
                        elif "STEP 4/6" in line:
                            self.current_step_idx = 2  # Extractions
                        elif "STEP 5/6" in line:
                            self.current_step_idx = 3  # Hardware Sync (UUID)
                        elif "STEP 6/6" in line:
                            self.current_step_idx = 5  # Bootloader
                except queue.Empty:
                    pass

                log_content = Text()
                for l in self.logs:
                    log_content.append(" > ", style="cyan")
                    log_content.append(f"{l}\n", style="white")

                layout["header"].update(self.render_header())
                layout["steps_col"].update(self.render_steps())
                layout["footer"].update(self.render_footer())
                layout["main_col"].update(
                    Panel(
                        log_content,
                        title=" REALTIME_DEPLOY_STREAM ",
                        border_style=ACCENT_COLOR,
                    )
                )
                time.sleep(0.1)

        self.console.clear()
        if self.install_success:
            finish_text = Text(
                "\nDEPLOYMENT SYNCHRONIZED SUCCESSFULLY!\n\n",
                style=f"bold {THEME_COLOR}",
            )
            finish_text.append("GingerOS is now operational on your hardware.\n")
            finish_text.append(
                "Eject media and initiate system ignition (Reboot).\n\n", style="dim"
            )
            self.console.print(
                Panel(Align.center(finish_text), border_style=THEME_COLOR)
            )
        else:
            fail_text = Text("\nDEPLOYMENT CRITICAL FAILURE\n\n", style="bold red")
            fail_text.append(
                "Kernel deployment interrupted. Analyze logs for anomaly detection.\n"
            )
            self.console.print(Panel(Align.center(fail_text), border_style="red"))

        self.console.print("\nPress ENTER to exit.")
        input()

    def run(self):
        try:
            self.welcome_screen()
            self.disk_selection()
            self.user_setup()
            self.confirmation()
            self.installation_progress()
        except KeyboardInterrupt:
            self.console.print("\n[bold red]Installation aborted.[/]")
            sys.exit(1)


import collections

if __name__ == "__main__":
    GingerInstaller().run()
