#!/usr/bin/env python3
"""Static regression checks for the generated systemd networking configuration."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
NETWORK_SCRIPT = ROOT / "lfs" / "phase3-system" / "90-network.sh"


class NetworkConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = NETWORK_SCRIPT.read_text(encoding="utf-8")

    def test_uses_systemd_resolved_stub(self):
        self.assertIn(
            "ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf",
            self.script,
        )

    def test_does_not_hardcode_public_dns(self):
        self.assertNotIn("nameserver 8.8.8.8", self.script)
        self.assertNotIn("nameserver 8.8.4.4", self.script)

    def test_enables_dhcp_for_expected_interfaces(self):
        self.assertIn("Name=en* eth* ens* eno* wlp* wlan*", self.script)
        self.assertIn("DHCP=ipv4", self.script)


if __name__ == "__main__":
    unittest.main()
