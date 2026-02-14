import unittest
import time
from ginger_os import GingerTUI

class TestTUILogic(unittest.TestCase):
    def setUp(self):
        # Initialize TUI in dry_run mode to avoid impacting host
        self.tui = GingerTUI(dry_run=True)

    def test_format_time(self):
        self.assertEqual(self.tui.format_time(0), "00:00")
        self.assertEqual(self.tui.format_time(60), "01:00")
        self.assertEqual(self.tui.format_time(3661), "61:01") # Modified current logic uses mins:secs only

    def test_get_neural_pulsar(self):
        pulsar = self.tui.get_neural_pulsar()
        self.assertIn(pulsar, ["|", "/", "-", "\\"])

    def test_tui_initial_state(self):
        self.assertEqual(self.tui.selected_step, 0)
        self.assertFalse(self.tui.auto_all)
        self.assertIsNone(self.tui.executing_step)

    def test_navigation_logic(self):
        # Simulate 'j' key (down)
        self.tui.handle_key('j')
        self.assertEqual(self.tui.selected_step, 1)
        
        # Simulate 'k' key (up)
        self.tui.handle_key('k')
        self.assertEqual(self.tui.selected_step, 0)
        
        # Test boundaries (assuming more than 1 step exists)
        self.tui.selected_step = 0
        self.tui.handle_key('k')
        self.assertEqual(self.tui.selected_step, 0)

if __name__ == "__main__":
    unittest.main()
