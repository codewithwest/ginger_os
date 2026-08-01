import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import signal
import time
import threading

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from server.engine import GingerEngine


class TestPackageStepping(unittest.TestCase):
    def setUp(self):
        patcher = patch("builtins.open", unittest.mock.mock_open())
        patcher.start()
        self.addCleanup(patcher.stop)
        self.engine = GingerEngine(dry_run=True)
        self.engine.package_stepping = True

    @patch("os.kill")
    def test_package_pause_and_resume_signals(self, mock_kill):
        self.engine.current_process = MagicMock()
        self.engine.current_process.pid = 1234

        def do_pause():
            self.engine.process_monitor._handle_package_stepping("test-pkg")

        t = threading.Thread(target=do_pause)
        t.start()

        time.sleep(0.3)

        mock_kill.assert_any_call(1234, signal.SIGSTOP)
        self.assertTrue(self.engine.paused_for_package)

        self.engine.current_pkg = "test-pkg"
        self.engine.resume_package()

        time.sleep(0.3)

        mock_kill.assert_any_call(1234, signal.SIGCONT)
        self.assertFalse(self.engine.paused_for_package)

        t.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
