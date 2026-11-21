"""Prepare pinned PPSSPP assets and notices without distributing its old jpn0 font."""
import argparse
import hashlib
from pathlib import Path
import shutil
import urllib.request

FONT_REVISION = "77c1e96588718b83527fac9dfe395c2e5eddf4f7"
FONT_URL = f"https://raw.githubusercontent.com/hrydgard/ppsspp/{FONT_REVISION}/assets/flash0/font/jpn0.pgf"
FONT_SHA256 = "521e8c40955da80e28354ac2adff243f9dff071b177cdc72461376a837a92639"


def download_font():
    with urllib.request.urlopen(FONT_URL, timeout=90) as response:
        font = response.read()
    if hashlib.sha256(font).hexdigest() != FONT_SHA256:
        raise ValueError("Replacement Ume font SHA-256 mismatch")
    return font


def prepare_assets(source, frameworks, font_notices, android=False):
    source, frameworks, font_notices = Path(source), Path(frameworks), Path(font_notices)
    # Download and validate before creating any distributable font tree.
    replacement = download_font()
    assets = source / "assets"
    for path in assets.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"Symbolic link is not a distributable PPSSPP asset: {path.name}")
    destination = frameworks / ("system/PPSSPP" if android else "CoreAssets/PPSSPP")
    shutil.copytree(source / "assets", destination,
                    ignore=lambda _directory, names: {"jpn0.pgf", ".git", ".DS_Store"} & set(names), dirs_exist_ok=True)
    (destination / "flash0/font/jpn0.pgf").write_bytes(replacement)
    notices = ["PPSSPP libretro source: https://github.com/libretro/ppsspp\n"
               "Revision: 7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8\n"
               "BRUM changes dated 2026-11-21: platform/CMake integration.\n"
               "Only iOS uses the interpreter-only CPU patch; Android CPU selection is independent.\n"
               f"Japanese PGF replaced by Ume Gothic S5 from {FONT_URL}\nSHA-256: {FONT_SHA256}\n",
               font_notices.read_text(encoding="utf-8")]
    # Include vendor notices, including initialized submodules. Never inspect Git metadata.
    for path in sorted(source.rglob("*")):
        if not path.is_file() or ".git" in path.relative_to(source).parts:
            continue
        name = path.name.lower()
        if name.startswith(("license", "copying", "notice", "copyright")) or path.relative_to(source).as_posix() in (
                "ext/zlib/zlib.h", "ext/native/README.md", "README.md"):
            contents = path.read_bytes()
            if b"\0" not in contents:
                notices.append(f"\n--- {path.relative_to(source).as_posix()} ---\n" + contents.decode("utf-8", errors="replace"))
    licenses = frameworks / "core-licenses" if android else frameworks
    licenses.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source / "LICENSE.TXT", licenses / "PPSSPP-LICENSE.txt")
    (licenses / "PPSSPP-THIRD-PARTY.txt").write_text("\n".join(notices), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("frameworks", type=Path)
    parser.add_argument("--android", action="store_true", help="Write system/PPSSPP and core-licenses below Android assets")
    args = parser.parse_args()
    prepare_assets(args.source, args.frameworks, Path(__file__).parent / "licenses/PPSSPP-FONTS.txt", args.android)
