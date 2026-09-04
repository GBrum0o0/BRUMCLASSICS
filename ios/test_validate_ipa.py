import plistlib
import stat
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from validate_ipa import validate_ipa

class PackageValidationTests(unittest.TestCase):
    def fixture(self, folder, *, executable="BRUMCLASSICSMobile", include_binary=True,
                app="BRUMCLASSICSMobile", cpu=0x0100000C, executable_mode=True):
        path = Path(folder) / "test.ipa"
        root = f"Payload/{app}.app/"
        info = {"CFBundleIdentifier": "com.brumclassics.mobile.ios",
                "CFBundleShortVersionString": "0.2.1", "CFBundleVersion": "4",
                "CFBundleSupportedPlatforms": ["iPhoneOS"]}
        if executable is not None:
            info["CFBundleExecutable"] = executable
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(root + "Info.plist", plistlib.dumps(info))
            if include_binary:
                entry = zipfile.ZipInfo(root + "BRUMCLASSICSMobile")
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | (0o755 if executable_mode else 0o644)) << 16
                archive.writestr(entry, struct.pack("<IIIIIIII", 0xFEEDFACF, cpu, 0, 2, 0, 0, 0, 0))
        return path

    def test_valid_package(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertTrue(validate_ipa(self.fixture(folder), "0.2.1")["ok"])

    def test_rejects_missing_executable_key(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "CFBundleExecutable"):
                validate_ipa(self.fixture(folder, executable=None))

    def test_rejects_wrong_reference(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "absent"):
                validate_ipa(self.fixture(folder, executable="wrong"))

    def test_rejects_missing_binary(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "absent"):
                validate_ipa(self.fixture(folder, include_binary=False))

    def test_rejects_non_ascii_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "ASCII"):
                validate_ipa(self.fixture(folder, app="BRUMCLASSICS MÓVEL"))

    def test_rejects_wrong_architecture(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "arm64"):
                validate_ipa(self.fixture(folder, cpu=0x01000007))

    def test_rejects_non_executable_zip_mode(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "permission"):
                validate_ipa(self.fixture(folder, executable_mode=False))

if __name__ == "__main__":
    unittest.main()
