import unittest
from unittest.mock import patch, MagicMock
import os
import sys

# Add to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from lfs_builder_ui import GingerEngine
from lfs_builder_ui.models import BuildStep

class TestDryRun(unittest.TestCase):
    def setUp(self):
        self.engine = GingerEngine(dry_run=True)

    @patch("subprocess.Popen")
    @patch("builtins.open", new_callable=unittest.mock.mock_open)
    @patch("os.path.join", side_effect=lambda *args: "/".join(args))
    @patch("os.path.exists", return_value=False)
    def test_dry_run_no_popen(self, mock_exists, mock_join, mock_open, mock_popen):
        step = self.engine.steps[0]
        self.engine._execute_step(step)
        
        # Verify Popen was NOT called
        mock_popen.assert_not_called()
        
        # Verify status is completed
        self.assertEqual(step.status, "completed")
        
        # Verify logs contain [DRY-RUN]
        found = any("[DRY-RUN]" in log_entry for log_entry, style in self.engine.logs)
        self.assertTrue(found, "Dry-run log marker not found in engine logs")

    # Removed test_dry_run_full_loop as GingerEngine doesn't have a run() method.
    # Control loop is managed by the TUI or external orchestrator.

if __name__ == "__main__":
    unittest.main()
