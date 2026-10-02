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
                app="BRUMCLASSICSMobile", cpu=0x0100000C, executable_mode=True, include_core=True,
                include_skyemu=True, include_geolith=True, include_gearsystem=True,
                include_nestopia=True, include_beetle_pce=True, include_beetle_wswan=True, include_bsnes=True, include_licenses=True):
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
            if include_core:
                core = zipfile.ZipInfo(root + "Frameworks/mgba_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_skyemu:
                core = zipfile.ZipInfo(root + "Frameworks/skyemu_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_geolith:
                core = zipfile.ZipInfo(root + "Frameworks/geolith_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_gearsystem:
                core = zipfile.ZipInfo(root + "Frameworks/gearsystem_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_nestopia:
                core = zipfile.ZipInfo(root + "Frameworks/nestopia_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_beetle_pce:
                core = zipfile.ZipInfo(root + "Frameworks/mednafen_pce_fast_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_bsnes:
                core = zipfile.ZipInfo(root + "Frameworks/bsnes_mercury_performance_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_beetle_wswan:
                core = zipfile.ZipInfo(root + "Frameworks/mednafen_wswan_libretro_ios.dylib")
                core.create_system = 3
                core.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(core, struct.pack("<IIIIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
            if include_licenses:
                archive.writestr(root + "Frameworks/BRUMCLASSICS-Mobile-GPL-3.0.txt", "GPLv3\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/mGBA-LICENSE.txt", "MPL2\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/SkyEmu-LICENSE.txt", "MIT\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/Geolith-LICENSE.txt", "BSD3\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/Gearsystem-LICENSE.txt", "GPLv3\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/Nestopia-LICENSE.txt", "GPLv2+\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/Beetle-PCE-Fast-LICENSE.txt", "GPLv2+\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/Beetle-WonderSwan-LICENSE.txt", "GPLv2+\n" + "x" * 2_000)
                archive.writestr(root + "Frameworks/bsnes-mercury-LICENSE.txt", "GPLv3\n" + "x" * 2_000)
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

    def test_rejects_missing_integrated_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "mGBA core is absent"):
                validate_ipa(self.fixture(folder, include_core=False))

    def test_rejects_missing_skyemu_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "SkyEmu core is absent"):
                validate_ipa(self.fixture(folder, include_skyemu=False))

    def test_rejects_missing_geolith_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Geolith core is absent"):
                validate_ipa(self.fixture(folder, include_geolith=False))

    def test_rejects_missing_gearsystem_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Gearsystem core is absent"):
                validate_ipa(self.fixture(folder, include_gearsystem=False))

    def test_rejects_missing_mobile_license(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "license is absent"):
                validate_ipa(self.fixture(folder, include_licenses=False))

    def test_rejects_missing_nestopia_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Nestopia core is absent"):
                validate_ipa(self.fixture(folder, include_nestopia=False))

    def test_rejects_missing_beetle_pce_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Beetle PCE Fast core is absent"):
                validate_ipa(self.fixture(folder, include_beetle_pce=False))

    def test_rejects_missing_bsnes_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "bsnes-mercury core is absent"):
                validate_ipa(self.fixture(folder, include_bsnes=False))

    def test_rejects_missing_beetle_wswan_core(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Beetle WonderSwan core is absent"):
                validate_ipa(self.fixture(folder, include_beetle_wswan=False))

if __name__ == "__main__":
    unittest.main()
