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
                include_nestopia=True, include_beetle_pce=True, include_beetle_wswan=True, include_bsnes=True, include_licenses=True,
                experimental=False, include_n64=True, include_psx=True, include_saturn=True,
                include_stella=True, include_ppsspp=True, include_flycast=True, include_blastem=True,
                include_mame=True, include_dolphin=True, include_dolphin_assets=True,
                include_azahar=True,
                include_arcade_gc_notices=True,
                include_ppsspp_assets=True, candidate_cpu=0x0100000C, candidate_licenses=True,
                include_blastem_vendor_licenses=True,
                experimental_build="37"):
        path = Path(folder) / "test.ipa"
        root = f"Payload/{app}.app/"
        info = {"CFBundleIdentifier": "com.brumclassics.mobile.ios",
                "CFBundleShortVersionString": "0.2.1", "CFBundleVersion": "4",
                "CFBundleSupportedPlatforms": ["iPhoneOS"]}
        if executable is not None:
            info["CFBundleExecutable"] = executable
        info["BRUMExperimentalBackends"] = experimental
        if experimental is True:
            info["CFBundleVersion"] = experimental_build
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(root + "Info.plist", plistlib.dumps(info))
            if experimental is True:
                candidates = [
                    (include_n64, "mupen64plus_next_libretro_ios.dylib", "Mupen64Plus-Next-LICENSE.txt"),
                    (include_psx, "mednafen_psx_libretro_ios.dylib", "Beetle-PSX-LICENSE.txt"),
                    (include_saturn, "mednafen_saturn_libretro_ios.dylib", "Beetle-Saturn-LICENSE.txt"),
                    (include_stella, "stella2014_libretro_ios.dylib", "Stella2014-LICENSE.txt"),
                ]
                if int(experimental_build) >= 39:
                    candidates += [
                        (include_ppsspp, "ppsspp_libretro_ios.dylib", "PPSSPP-LICENSE.txt"),
                        (include_flycast, "flycast_libretro_ios.dylib", "Flycast-LICENSE.txt"),
                    ]
                    if include_ppsspp_assets:
                        archive.writestr(root + "Frameworks/CoreAssets/PPSSPP/lang/en_US.ini", "language fixture")
                if int(experimental_build) >= 40:
                    candidates.append((include_blastem, "blastem_libretro_ios.dylib", "BlastEm-LICENSE.txt"))
                    if include_blastem_vendor_licenses:
                        for notice in ["BlastEm-libchdr-LICENSE.txt", "BlastEm-LZMA-LICENSE.txt", "BlastEm-zlib-LICENSE.txt"]:
                            archive.writestr(root + "Frameworks/" + notice, "license fixture")
                if int(experimental_build) >= 44:
                    candidates += [
                        (include_mame, "mamearcade2016_libretro_ios.dylib", "MAME2016-LICENSE.md"),
                        (include_dolphin, "dolphin_libretro_ios.dylib", "Dolphin-LICENSE.txt"),
                    ]
                    if include_dolphin_assets:
                        archive.writestr(root + "Frameworks/CoreAssets/dolphin-emu/Sys/GC/font_sjis.bin", "asset fixture")
                    if include_arcade_gc_notices:
                        for notice in ("MAME2016-THIRD-PARTY.md", "MAME2016-softfloat-NOTICE.txt",
                                       "MAME2016-expat-LICENSE.txt", "MAME2016-FLAC-LICENSE.txt",
                                       "MAME2016-libuv-LICENSE.txt", "MAME2016-http-parser-LICENSE.txt",
                                       "MAME2016-LZMA-NOTICE.txt", "Dolphin-COPYING.txt",
                                       "Dolphin-BSD-3-Clause.txt", "Dolphin-CC0-1.0.txt", "Dolphin-MIT.txt"):
                            archive.writestr(root + "Frameworks/" + notice, "license fixture")
                if int(experimental_build) >= 45:
                    candidates.append((include_azahar, "azahar_libretro_ios.dylib", "Azahar-LICENSE.txt"))
                for enabled, filename, license_name in candidates:
                    if enabled:
                        entry = zipfile.ZipInfo(root + "Frameworks/" + filename)
                        entry.create_system = 3
                        entry.external_attr = (stat.S_IFREG | 0o755) << 16
                        archive.writestr(entry, struct.pack("<IIIIIIII", 0xFEEDFACF, candidate_cpu, 0, 6, 0, 0, 0, 0))
                    if candidate_licenses:
                        archive.writestr(root + "Frameworks/" + license_name, "license fixture " * 100)
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

    def test_experimental_package_requires_all_candidates(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True))
            self.assertTrue(result["experimentalBackends"])
            self.assertEqual(len(result["integratedCores"]), 12)
            for option in ["include_n64", "include_psx", "include_saturn", "include_stella"]:
                with self.assertRaisesRegex(ValueError, "core is absent"):
                    validate_ipa(self.fixture(folder, experimental=True, **{option: False}))

    def test_previous_experimental_build_remains_valid(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True, experimental_build="36",
                                               include_n64=False, include_saturn=False))
            self.assertEqual(len(result["integratedCores"]), 10)

    def test_heavy_experimental_build_requires_both_cores_and_assets(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True, experimental_build="39"))
            self.assertEqual(len(result["integratedCores"]), 14)
            for option in ["include_ppsspp", "include_flycast"]:
                with self.assertRaisesRegex(ValueError, "core is absent"):
                    validate_ipa(self.fixture(folder, experimental=True, experimental_build="39", **{option: False}))
            with self.assertRaisesRegex(ValueError, "assets are absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="39", include_ppsspp_assets=False))

    def test_sega_experimental_build_requires_blastem_and_vendor_notices(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True, experimental_build="40"))
            self.assertEqual(len(result["integratedCores"]), 15)
            with self.assertRaisesRegex(ValueError, "BlastEm core is absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="40", include_blastem=False))
            with self.assertRaisesRegex(ValueError, "BlastEm-libchdr-LICENSE.txt is absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="40", include_blastem_vendor_licenses=False))

    def test_arcade_gamecube_experimental_build_requires_cores_assets_and_notices(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True, experimental_build="44"))
            self.assertEqual(len(result["integratedCores"]), 17)
            for option in ["include_mame", "include_dolphin"]:
                with self.assertRaisesRegex(ValueError, "core is absent"):
                    validate_ipa(self.fixture(folder, experimental=True, experimental_build="44", **{option: False}))
            with self.assertRaisesRegex(ValueError, "Dolphin core assets are absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="44", include_dolphin_assets=False))
            with self.assertRaisesRegex(ValueError, "MAME2016-THIRD-PARTY.md is absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="44", include_arcade_gc_notices=False))

    def test_azahar_experimental_build_requires_core_and_license(self):
        with tempfile.TemporaryDirectory() as folder:
            result = validate_ipa(self.fixture(folder, experimental=True, experimental_build="45"))
            self.assertEqual(len(result["integratedCores"]), 18)
            with self.assertRaisesRegex(ValueError, "Azahar core is absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="45", include_azahar=False))
            with self.assertRaisesRegex(ValueError, "license is absent"):
                validate_ipa(self.fixture(folder, experimental=True, experimental_build="45", candidate_licenses=False))

    def test_experimental_package_rejects_wrong_cpu_and_missing_license(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "arm64"):
                validate_ipa(self.fixture(folder, experimental=True, candidate_cpu=0x01000007))
            with self.assertRaisesRegex(ValueError, "license is absent"):
                validate_ipa(self.fixture(folder, experimental=True, candidate_licenses=False))
            with self.assertRaisesRegex(ValueError, "Invalid experimental"):
                validate_ipa(self.fixture(folder, experimental="true"))

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
