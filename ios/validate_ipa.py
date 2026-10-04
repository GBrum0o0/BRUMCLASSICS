"""Validate the actual unsigned iPhone IPA, not just its source files."""
import argparse
import json
import plistlib
import stat
import struct
import zipfile
from pathlib import PurePosixPath

def validate_ipa(path, expected_version=None):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP entries")
        for name in names:
            entry = PurePosixPath(name)
            if entry.is_absolute() or ".." in entry.parts or "\\" in name:
                raise ValueError("Unsafe ZIP path")
        infos = [n for n in names if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(infos) != 1:
            raise ValueError("Expected exactly one Payload application")
        info_path = infos[0]
        root = info_path.removesuffix("Info.plist")
        if not root.isascii():
            raise ValueError("Application directory must be ASCII")
        info = plistlib.loads(archive.read(info_path))
        executable = info.get("CFBundleExecutable")
        if not isinstance(executable, str) or not executable or not executable.isascii() or "/" in executable or "\\" in executable or "$(" in executable:
            raise ValueError("Missing or invalid CFBundleExecutable")
        executable_path = root + executable
        if executable_path not in names:
            raise ValueError("Referenced executable is absent")
        binary = archive.read(executable_path)
        if len(binary) < 32:
            raise ValueError("Truncated Mach-O executable")
        magic, cpu, _, filetype = struct.unpack_from("<IIII", binary)
        if magic != 0xFEEDFACF or cpu != 0x0100000C or filetype != 2:
            raise ValueError("Expected an arm64 Mach-O iPhone executable")
        mode = archive.getinfo(executable_path).external_attr >> 16
        if not mode & stat.S_IXUSR:
            raise ValueError("Executable permission missing from ZIP")
        integrated_cores = {
            "mGBA": root + "Frameworks/mgba_libretro_ios.dylib",
            "SkyEmu": root + "Frameworks/skyemu_libretro_ios.dylib",
            "Geolith": root + "Frameworks/geolith_libretro_ios.dylib",
            "Gearsystem": root + "Frameworks/gearsystem_libretro_ios.dylib",
            "Nestopia": root + "Frameworks/nestopia_libretro_ios.dylib",
            "Beetle PCE Fast": root + "Frameworks/mednafen_pce_fast_libretro_ios.dylib",
            "Beetle WonderSwan": root + "Frameworks/mednafen_wswan_libretro_ios.dylib",
            "bsnes-mercury": root + "Frameworks/bsnes_mercury_performance_libretro_ios.dylib",
        }
        experimental = info.get("BRUMExperimentalBackends", False)
        if not isinstance(experimental, bool):
            raise ValueError("Invalid experimental backend flag")
        build_number = info.get("CFBundleVersion", "")
        if experimental and (not isinstance(build_number, str) or not build_number.isdecimal() or int(build_number) < 36):
            raise ValueError("Invalid experimental build number")
        expanded_experimental = experimental and int(build_number) >= 37
        if experimental:
            integrated_cores.update({
                "Beetle PSX": root + "Frameworks/mednafen_psx_libretro_ios.dylib",
                "Stella2014": root + "Frameworks/stella2014_libretro_ios.dylib",
            })
        if expanded_experimental:
            integrated_cores.update({
                "Mupen64Plus-Next": root + "Frameworks/mupen64plus_next_libretro_ios.dylib",
                "Beetle Saturn": root + "Frameworks/mednafen_saturn_libretro_ios.dylib",
            })
        for core_name, core_path in integrated_cores.items():
            if core_path not in names:
                raise ValueError(f"Integrated {core_name} core is absent")
            core = archive.read(core_path)
            if len(core) < 32:
                raise ValueError(f"Truncated integrated {core_name} core")
            core_magic, core_cpu, _, core_filetype = struct.unpack_from("<IIII", core)
            if core_magic != 0xFEEDFACF or core_cpu != 0x0100000C or core_filetype != 6:
                raise ValueError(f"Expected an arm64 Mach-O {core_name} dynamic library")
            core_mode = archive.getinfo(core_path).external_attr >> 16
            if not core_mode & stat.S_IXUSR:
                raise ValueError("Integrated core executable permission missing from ZIP")
        required_licenses = [
            root + "Frameworks/BRUMCLASSICS-Mobile-GPL-3.0.txt",
            root + "Frameworks/mGBA-LICENSE.txt",
            root + "Frameworks/SkyEmu-LICENSE.txt",
            root + "Frameworks/Geolith-LICENSE.txt",
            root + "Frameworks/Gearsystem-LICENSE.txt",
            root + "Frameworks/Nestopia-LICENSE.txt",
            root + "Frameworks/Beetle-PCE-Fast-LICENSE.txt",
            root + "Frameworks/Beetle-WonderSwan-LICENSE.txt",
            root + "Frameworks/bsnes-mercury-LICENSE.txt",
        ]
        if experimental:
            required_licenses += [root + "Frameworks/Beetle-PSX-LICENSE.txt",
                                  root + "Frameworks/Stella2014-LICENSE.txt"]
        if expanded_experimental:
            required_licenses += [root + "Frameworks/Mupen64Plus-Next-LICENSE.txt",
                                  root + "Frameworks/Beetle-Saturn-LICENSE.txt"]
        for license_path in required_licenses:
            if license_path not in names or len(archive.read(license_path)) < 1_000:
                raise ValueError("Required mobile or core license is absent")
        if info.get("CFBundleIdentifier") != "com.brumclassics.mobile.ios":
            raise ValueError("Unexpected bundle identifier")
        if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
            raise ValueError("Package is not an iPhoneOS build")
        if expected_version and info.get("CFBundleShortVersionString") != expected_version:
            raise ValueError("Unexpected version")
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC check failed")
        return {"ok": True, "version": info.get("CFBundleShortVersionString"),
                "build": info.get("CFBundleVersion"), "bundleId": info["CFBundleIdentifier"],
                "executable": executable_path, "architecture": "arm64", "integratedCores": [name + " arm64" for name in integrated_cores],
                "experimentalBackends": experimental,
                "signing": "unsigned; requires AltStore or Sideloadly", "entries": len(names)}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    parser.add_argument("--version")
    args = parser.parse_args()
    print(json.dumps(validate_ipa(args.ipa, args.version), indent=2))
