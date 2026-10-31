"""The GRUB boot loader is reinstalled once, and only when it is safe."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "usr/share/libalpm/scripts/install-grub-once"
SECURE_BOOT = "sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa8c-00e098cbc137"
MARKER = "var/lib/comm-improve-compatibility/install-grub-done"


class InstallGrubOnceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.root = base / "root"
        self.bin = base / "bin"
        self.calls = base / "calls"
        self.bin.mkdir()
        self.root.mkdir()
        self.fake("systemd-detect-virt", "exit 1")
        self.fake("install-grub", f'echo run >> "{self.calls}"')

    def tearDown(self):
        self.tmp.cleanup()

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def grub(self, path="boot/grub/x86_64-efi/core.efi"):
        core = self.root / path
        core.parent.mkdir(parents=True, exist_ok=True)
        core.touch()

    def secure_boot(self, value):
        var = self.root / SECURE_BOOT
        var.parent.mkdir(parents=True, exist_ok=True)
        var.write_bytes(bytes([6, 0, 0, 0, value]))

    def run_script(self):
        env = {**os.environ, "ROOT_DIR": str(self.root), "INSTALL_GRUB": str(self.bin / "install-grub"),
               "PATH": f"{self.bin}:{os.environ['PATH']}"}
        return subprocess.run(["bash", str(SCRIPT)], env=env, check=True, capture_output=True, text=True)

    def runs(self):
        return len(self.calls.read_text().splitlines()) if self.calls.exists() else 0

    def test_efi_loader_is_reinstalled_only_once(self):
        self.grub()
        self.secure_boot(0)
        self.run_script()
        self.run_script()
        self.assertEqual(self.runs(), 1)
        self.assertTrue((self.root / MARKER).exists())

    def test_bios_loader_is_reinstalled(self):
        self.grub("boot/grub/i386-pc/core.img")
        self.run_script()
        self.assertEqual(self.runs(), 1)

    def test_failure_is_retried_on_the_next_update(self):
        self.grub()
        self.fake("install-grub", f'echo run >> "{self.calls}"; exit 1')
        self.assertIn("retried", self.run_script().stdout)
        self.assertFalse((self.root / MARKER).exists())
        self.run_script()
        self.assertEqual(self.runs(), 2)

    def test_system_without_grub_is_left_alone(self):
        self.run_script()
        self.assertEqual(self.runs(), 0)
        self.assertTrue((self.root / MARKER).exists())

    def test_secure_boot_is_left_alone(self):
        self.grub()
        self.secure_boot(1)
        self.assertIn("Secure Boot", self.run_script().stdout)
        self.assertEqual(self.runs(), 0)

    def test_image_builds_are_left_alone(self):
        self.grub()
        self.fake("systemd-detect-virt", "exit 0")
        self.run_script()
        self.assertEqual(self.runs(), 0)
        self.assertTrue((self.root / MARKER).exists())


if __name__ == "__main__":
    unittest.main()
