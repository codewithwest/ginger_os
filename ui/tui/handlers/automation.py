# ui/tui/handlers/automation.py

from ui.tui.handlers.actions import run_step


def process_auto_mode(app):

    if not app.state.auto_all:
        return

    if app.state.executing_step is not None:
        return

    for idx, step in enumerate(app.engine.steps):

        if not app.engine._should_skip(step):

            app.state.selected_step = idx

            run_step(app)

            break
