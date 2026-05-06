import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import signal
import time
import threading

# Add to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from lfs_builder_ui import GingerEngine


class TestPackageStepping(unittest.TestCase):
    def setUp(self):
        self.engine = GingerEngine()
        self.engine.package_stepping = True

    @patch("select.select")
    @patch("os.kill")
    @patch("subprocess.Popen")
    @patch("builtins.open", new_callable=unittest.mock.mock_open)
    def test_package_pause_signal(self, mock_open, mock_popen, mock_kill, mock_select):
        # Mock process
        mock_proc = MagicMock()
        mock_proc.pid = 1234

        # Mock select to return the process stdout as ready
        mock_select.return_value = ([mock_proc.stdout], [], [])

        mock_proc.stdout.readline.side_effect = [
            "__GINGER_PKG_MARKER__: test-pkg\n",
            "",
        ]
        mock_proc.poll.return_value = 0
        mock_proc.returncode = 0
        mock_popen.return_value = mock_proc

        step = self.engine.steps[0]

        # We need to run this in a thread because _execute_step will block
        def run_step():
            self.engine._execute_step(step)

        t = threading.Thread(target=run_step)
        t.start()

        # Give it a moment to hit the pause
        time.sleep(0.5)

        # Verify SIGSTOP was sent
        mock_kill.assert_any_call(1234, signal.SIGSTOP)
        self.assertTrue(self.engine.paused_for_package)

        # Resume
        self.engine.resume_package()

        # Verify SIGCONT was sent
        mock_kill.assert_any_call(1234, signal.SIGCONT)

        t.join(timeout=2)
        self.assertFalse(self.engine.paused_for_package)


if __name__ == "__main__":
    unittest.main()
