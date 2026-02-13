import unittest
import os
import re
from unittest.mock import MagicMock, patch
from lfs_builder_ui.engine import GingerEngine

class TestGingerEngine(unittest.TestCase):
    def setUp(self):
        # Prevent GingerEngine.__init__ from doing too much if needed
        # but for now we'll just let it run
        self.engine = GingerEngine()

    def test_ansi_escape(self):
        raw = "\x1b[31mError\x1b[0m"
        clean = self.engine.ansi_escape.sub('', raw)
        self.assertEqual(clean, "Error")

    def test_non_printable_filter(self):
        # \x01 is SOH (non-printable), \n and \t should be kept
        raw = "Hello\x01\nWorld\t!"
        clean = self.engine.non_printable.sub('', raw)
        self.assertEqual(clean, "Hello\nWorld\t!")

    def test_get_script_pkg_name(self):
        # Mocking open() to simulate reading a script
        script_content = 'PKG_NAME="test-package-1.2.3"\necho "Build started"'
        with patch("builtins.open", unittest.mock.mock_open(read_data=script_content)):
            pkg_name = self.engine._get_script_pkg_name("dummy_path.sh")
            self.assertEqual(pkg_name, "test-package-1.2.3")

    def test_get_script_pkg_name_missing(self):
        script_content = 'echo "No package name here"'
        with patch("builtins.open", unittest.mock.mock_open(read_data=script_content)):
            pkg_name = self.engine._get_script_pkg_name("dummy_path_no_name.sh")
            self.assertIsNone(pkg_name)

    @patch("lfs_builder_ui.engine.MASTER_LOG", "/tmp/ginger_master.log")
    @patch("lfs_builder_ui.engine.LOG_DIR", "/tmp")
    def test_rotate_logs_logic(self):
        with patch("os.path.exists", return_value=True), \
             patch("os.path.getsize", return_value=60 * 1024 * 1024), \
             patch("shutil.move") as mock_move, \
             patch("builtins.open", unittest.mock.mock_open()):
            
            # Re-call _rotate_logs to trigger rotation
            self.engine._rotate_logs()
            
            # Check if move (backup) was called
            mock_move.assert_called()

if __name__ == "__main__":
    unittest.main()
