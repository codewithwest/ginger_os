import unittest
from ui.tui import GingerTUI


class TestTUILogic(unittest.TestCase):
    def setUp(self):
        # Initialize TUI in dry_run mode to avoid impacting host
        self.tui = GingerTUI(dry_run=True)

    def test_tui_initial_state(self):
        self.assertEqual(self.tui.selected_step, 0)
        self.assertFalse(self.tui.state.auto_all)
        self.assertIsNone(self.tui.state.executing_step)

    def test_navigation_logic(self):
        # In Textual, selected_step is updated via ListView highlights.
        # We can test the reactive property directly.
        self.tui.selected_step = 1
        self.assertEqual(self.tui.selected_step, 1)

        self.tui.selected_step = 0
        self.assertEqual(self.tui.selected_step, 0)


if __name__ == "__main__":
    unittest.main()

