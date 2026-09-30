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
        core_path = root + "Frameworks/mgba_libretro_ios.dylib"
        if core_path not in names:
            raise ValueError("Integrated mGBA core is absent")
        core = archive.read(core_path)
        if len(core) < 32:
            raise ValueError("Truncated integrated mGBA core")
        core_magic, core_cpu, _, core_filetype = struct.unpack_from("<IIII", core)
        if core_magic != 0xFEEDFACF or core_cpu != 0x0100000C or core_filetype != 6:
            raise ValueError("Expected an arm64 Mach-O mGBA dynamic library")
        core_mode = archive.getinfo(core_path).external_attr >> 16
        if not core_mode & stat.S_IXUSR:
            raise ValueError("Integrated core executable permission missing from ZIP")
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
                "executable": executable_path, "architecture": "arm64", "integratedCore": "mGBA arm64",
                "signing": "unsigned; requires AltStore or Sideloadly", "entries": len(names)}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    parser.add_argument("--version")
    args = parser.parse_args()
    print(json.dumps(validate_ipa(args.ipa, args.version), indent=2))
