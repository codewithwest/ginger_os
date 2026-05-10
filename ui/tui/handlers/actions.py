# ui/tui/handlers/actions.py

import threading
import time


def execute_action(app, action):

    if action == "quit":

        app.state.running = False

    elif action == "help":

        app.state.show_help = (
            not app.state.show_help
        )

    elif action == "auto":

        app.state.auto_all = (
            not app.state.auto_all
        )

    elif action == "run":

        run_step(app, force=False)

    elif action == "force":

        run_step(app, force=True)


def run_step(app, force=False):

    idx = app.state.selected_step

    if app.state.executing_step is not None:
        return

    step = app.engine.steps[idx]

    if (
        app.engine._should_skip(step)
        and not force
    ):
        return

    app.state.executing_step = idx

    app.state.current_start_time = time.time()

    def _target():

        try:
            app.engine._execute_step(step)

        finally:
            app.state.executing_step = None

    thread = threading.Thread(
        target=_target,
        daemon=True,
    )

    app.state.executing_thread = thread

    thread.start()
