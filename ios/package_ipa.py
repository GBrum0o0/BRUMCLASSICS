"""Create a deterministic-layout IPA with ASCII paths and Unix permissions."""
import hashlib
import json
import plistlib
import stat
import sys
import zipfile
from pathlib import Path
from validate_ipa import validate_ipa

app = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
if not app.is_dir() or app.suffix != ".app" or not app.name.isascii():
    raise SystemExit("Expected an ASCII-named .app directory")
info = plistlib.loads((app / "Info.plist").read_bytes())
executable = info.get("CFBundleExecutable")
if not executable or not (app / executable).is_file():
    raise SystemExit("CFBundleExecutable does not resolve to a file")
version = info["CFBundleShortVersionString"]
output.mkdir(parents=True, exist_ok=True)
ipa = output / f"BRUMCLASSICS-MOVEL-IOS-{version}.ipa"
with zipfile.ZipFile(ipa, "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob("*")):
        if file.is_symlink():
            raise SystemExit("Symlinks are not expected in this app")
        if not file.is_file():
            continue
        relative = file.relative_to(app).as_posix()
        entry = zipfile.ZipInfo(f"Payload/{app.name}/{relative}")
        entry.create_system = 3
        entry.compress_type = zipfile.ZIP_DEFLATED
        permissions = 0o755 if relative == executable else 0o644
        entry.external_attr = (stat.S_IFREG | permissions) << 16
        archive.writestr(entry, file.read_bytes())
result = validate_ipa(ipa, version)
digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
(ipa.with_suffix(".ipa.sha256")).write_text(f"{digest}  {ipa.name}\n", encoding="utf-8")
(output / "IPA-VALIDATION.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
