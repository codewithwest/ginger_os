# ui/tui/app.py

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Header, Footer, Static, RichLog, ListView, ListItem
from textual.reactive import reactive

from server.engine import GingerEngine
from ui.tui.state import TUIState
from ui.tui.widgets import Branding, NeuralCore, SystemMX, StepItem
from ui.tui.screens import HelpScreen
import time


class GingerTUI(App):
    CSS = """
    /* =========================================================
       GINGER // NEURAL OPS CONSOLE v9.4
       ========================================================= */

    Screen {
        padding:0;
        background: #020304;
        color: #d7f7ff;
        layers: base overlay;
    }

    /* =========================
       GLOBAL
       ========================= */

    * {
        scrollbar-size: 1 1;
        scrollbar-background: #05080a;
        scrollbar-color: #00f0ff;
    }

    Header {
        # background: #041018;
        color: #00f0ff;
        text-style: bold;
        border-bottom: heavy #00f0ff 20%;
    }

    Footer {
        background: #041018;
        color: #9be7ff;
        border-top: heavy #00f0ff 20%;
    }

    /* =========================
       LAYOUT
       ========================= */

    #left_col {
        width: 30%;
        background: #05080b;
        border-right: heavy #00f0ff;
        padding: 1;
    }

    #terminal_col {
        width: 70%;
        # background: #010203;
        padding: 1;
    }

    /* =========================
       MODULE PANELS
       ========================= */

    #branding {
        height: 12;
        margin-bottom: 1;
        content-align: center middle;
        border: double #00f0ff;
        background: #06131a;
        color: #8df5ff;
    }

    #neural_core {
        height: 8;
        margin-bottom: 1;
        border: round #00ffd0;
        background: #041116;
        color: #00ffd0;
    }

    #system_mx {
        height: 8;
        margin-top: 1;
        border: heavy #ff00aa;
        background: #100411;
        color: #ff7ad9;
    }

    /* =========================
       LOG TERMINAL
       ========================= */

    #log_view {
        height: 1fr;
        border: heavy #00f0ff;
        background: #000000;
        color: #c7f7ff;
        padding: 1;
    }

    RichLog {
        text-style: none;
    }

    /* =========================
       STEP LIST
       ========================= */

    ListView {
        height: 1fr;
        border: tall #00f0ff;
        background: #040608;
        margin: 1 0;
        padding: 0 1;
    }

    ListItem {
        background: transparent;
        color: #b9d9e2;
        padding: 0 1;
        margin: 0;
        border-left: wide transparent;
    }

    ListItem > Horizontal {
        height: 1;
    }

    ListItem.--highlight {
        background: #09141a;
        border-left: wide #00f0ff;
    }

    .step-index {
        width: 5;
        color: #00f0ff;
        text-style: bold;
    }

    .step-name {
        width: 1fr;
        color: #d7f7ff;
    }

    .step-status {
        width: 14;
        text-align: right;
        text-style: bold;
    }

    /* =========================
       STATE COLORS
       ========================= */

    ListItem.running {
        background: #07151c;
        border-left: wide #00f0ff;
    }

    ListItem.running .step-name {
        color: #00f0ff;
        text-style: bold;
    }

    ListItem.running .step-status {
        color: #00f0ff;
    }

    ListItem.completed {
        background: #06140d;
        border-left: wide #00ff88;
    }

    ListItem.completed .step-name {
        color: #6dffb3;
    }

    ListItem.completed .step-status {
        color: #00ff88;
    }

    ListItem.failed {
        background: #170608;
        border-left: wide #ff004c;
    }

    ListItem.failed .step-name {
        color: #ff6b8a;
        text-style: bold;
    }

    ListItem.failed .step-status {
        color: #ff004c;
    }

    /* =========================
       CYBER FX
       ========================= */

    .panel-title {
        color: #00f0ff;
        text-style: bold;
    }

    .warning {
        color: #ffcc00;
        text-style: bold;
    }

    .danger {
        color: #ff004c;
        text-style: bold;
    }

    .success {
        color: #00ff88;
        text-style: bold;
    }

    .accent {
        color: #00f0ff;
    }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("a", "toggle_auto", "Auto-mode"),
        ("f", "force_step", "Force Step"),
        ("x", "abort_step", "Abort Module"),
        ("h", "toggle_help", "Help"),
    ]

    selected_step = reactive(0)
    is_running = reactive(False)

    def __init__(self, dry_run: bool = False):
        super().__init__()
        self.engine = GingerEngine(dry_run=dry_run)
        self.state = TUIState()

        # cyberpunk-ish base theme
        self.theme = "dracula"

        # Register TUI log callback to stream logs to RichLog
        self.engine.on_log_callbacks.append(self.log_message)

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)

        with Horizontal():
            with Vertical(id="left_col"):
                yield Branding(id="branding")
                yield NeuralCore(id="neural_core")
                yield ListView(id="steps_list")
                yield SystemMX(id="system_mx")

            with Vertical(id="terminal_col"):
                yield RichLog(
                    highlight=True,
                    markup=True,
                    id="log_view",
                    wrap=True,
                )

        yield Footer()

    def action_toggle_auto(self) -> None:
        self.state.auto_all = not self.state.auto_all

        mode = "ENGAGED" if self.state.auto_all else "DISENGAGED"

        self.log_message(
            f"[bold #00f0ff]AUTO_EXECUTION_PROTOCOL :: {mode}[/]"
        )

    def action_force_step(self) -> None:
        self.run_selected_step(force=True)

    def action_abort_step(self) -> None:
        if self.state.executing_step is not None:
            self.log_message(
                "[bold #ff004c]KERNEL_INTERRUPT :: ABORTING ACTIVE MODULE[/]"
            )
            self.engine.abort()
            self.state.auto_all = False

    def action_toggle_help(self) -> None:
        self.push_screen(HelpScreen())

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item:
            self.selected_step = event.list_view.index

    def on_key(self, event) -> None:
        if event.key == "enter":
            self.run_selected_step(force=False)

    def run_selected_step(self, force: bool = False):
        """Trigger the execution of the currently selected step."""

        idx = self.selected_step

        if self.state.executing_step is not None:
            return

        step = self.engine.steps[idx]

        if self.engine._should_skip(step) and not force:
            self.log_message(
                f"[#ffcc00]SKIP_SIGNAL :: {step.name} already synchronized[/]"
            )
            return

        self.state.executing_step = idx
        self.state.current_start_time = time.time()

        self.log_message(
            f"[bold #00f0ff]EXEC_PIPELINE :: INITIALIZING {step.name}[/]"
        )

        step.status = "running"
        self.update_step_ui(idx)

        self.execute_step_worker(step)

    def execute_step_worker(self, step):
        self.run_worker(lambda: self._step_execution_thread(step), thread=True)

    def _step_execution_thread(self, step):
        try:
            result_code = self.engine.process_monitor.execute_step(step)

            if result_code == 0:
                step.status = "completed"

                self.log_message(
                    f"[bold #00ff88]MODULE_OK :: {step.name} execution complete[/]"
                )

            else:
                step.status = "failed"

                self.log_message(
                    f"[bold #ff004c]MODULE_FAIL :: {step.name} exited with code {result_code}[/]"
                )

        except Exception as e:
            step.status = "failed"

            self.log_message(
                f"[bold #ff004c]CRITICAL_EXCEPTION :: {step.name} :: {str(e)}[/]"
            )

        finally:
            idx = self.state.executing_step
            self.state.executing_step = None

            self.call_from_thread(self.update_step_ui, idx)

            # Auto-mode logic: proceed to next step if successful
            if step.status == "completed" and self.state.auto_all:
                self.call_from_thread(self.trigger_next_step, idx)

            elif step.status == "failed" and self.state.auto_all:
                self.state.auto_all = False

                self.log_message(
                    "[bold #ff004c]AUTO_SEQUENCE_ABORTED :: FAILURE DETECTED[/]"
                )

    def trigger_next_step(self, current_idx: int):
        """Advances the selection and triggers the next step in auto-mode."""

        next_idx = current_idx + 1

        if next_idx < len(self.engine.steps):
            list_view = self.query_one("#steps_list", ListView)

            list_view.index = next_idx

            # Add a small delay to let the UI settle
            self.set_timer(1.0, self.run_selected_step)

        else:
            self.state.auto_all = False

            self.log_message(
                "[bold #00ff88]AUTO_SEQUENCE_COMPLETE :: ALL MODULES PROCESSED[/]"
            )

    def log_message(self, message: str, style: str | None = None):
        """Helper to write to the RichLog widget."""

        log_view = self.query_one("#log_view", RichLog)

        if style and "[" not in message:
            message = f"[{style}]{message}[/]"

        log_view.write(message)

    def on_mount(self) -> None:
        self.populate_steps_list()

        self.log_message(
            "[bold #00f0ff]NEURAL_SYSTEM_INTERFACE :: ONLINE[/]"
        )

        self.log_message(
            "[#6ef7ff]SECURE_LINK_ESTABLISHED :: QUANTUM_CHANNEL_READY[/]"
        )

    def populate_steps_list(self):
        list_view = self.query_one("#steps_list", ListView)

        for idx, step in enumerate(self.engine.steps):
            if self.engine._should_skip(step):
                step.status = "completed"

            list_view.append(StepItem(step, idx))

    def update_step_ui(self, index: int):
        if index is None:
            return

        list_view = self.query_one("#steps_list", ListView)

        item = list_view.children[index]

        if isinstance(item, StepItem):
            item.update_status()