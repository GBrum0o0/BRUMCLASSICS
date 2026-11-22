import json
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

import generate_sidestore_source as gss


def make_test_ipa(
    path: Path,
    *,
    version: str = "0.25.0",
    build: str = "58",
    bundle_id: str = gss.OFFICIAL_BUNDLE_ID,
    min_os: str = "16.0",
    experimental: bool = False,
) -> Path:
    plist_data = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "MinimumOSVersion": min_os,
    }
    if experimental:
        plist_data["BRUMExperimentalBackends"] = True
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("Payload/BRUMCLASSICSMobile.app/Info.plist", plistlib.dumps(plist_data))
        archive.writestr("Payload/BRUMCLASSICSMobile.app/BRUMCLASSICSMobile", b"stub-macho")
    return path


class SideStoreSourceTests(unittest.TestCase):
    def test_generates_valid_source_and_merges_versions_newest_first(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ipa24 = make_test_ipa(root / "BRUMCLASSICS-MOVEL-IOS-0.24.0.ipa", version="0.24.0", build="57")
            ipa25 = make_test_ipa(root / "BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa", version="0.25.0", build="58")
            val25 = root / "IPA-VALIDATION.json"
            val25.write_text(
                json.dumps({"ok": True, "version": "0.25.0", "build": "58", "bundleId": gss.OFFICIAL_BUNDLE_ID, "experimentalBackends": False}),
                encoding="utf-8",
            )
            out = root / "sidestore-source.json"

            self.assertEqual(
                gss.main([
                    "--ipa", str(ipa24),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.24.0/BRUMCLASSICS-MOVEL-IOS-0.24.0.ipa",
                    "--date", "2026-11-22T09:20:00Z",
                    "--notes", "Release 0.24.0",
                    "-o", str(out),
                ]),
                0,
            )
            self.assertEqual(
                gss.main([
                    "--ipa", str(ipa25),
                    "--validation-json", str(val25),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.25.0/BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa",
                    "--date", "2026-11-22T10:30:00Z",
                    "--notes", "Release 0.25.0 SideStore",
                    "--existing-source", str(out),
                    "-o", str(out),
                ]),
                0,
            )

            doc = json.loads(out.read_text(encoding="utf-8"))
            gss.validate_source_document(doc)
            app = doc["apps"][0]
            self.assertEqual(app["version"], "0.25.0")
            self.assertEqual([v["version"] for v in app["versions"]], ["0.25.0", "0.24.0"])
            self.assertEqual(app["versions"][0]["buildVersion"], "58")
            self.assertEqual(app["versions"][0]["minOSVersion"], "16.0")

    def test_rejects_releases_latest_android_and_experimental_ipa(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ipa = make_test_ipa(root / "BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa")
            exp_ipa = make_test_ipa(root / "exp.ipa", experimental=True)
            wrong_bundle = make_test_ipa(root / "wrong.ipa", bundle_id="com.example.other")
            out = root / "sidestore-source.json"

            with self.assertRaises(ValueError):
                gss.main([
                    "--ipa", str(ipa),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/latest/download/BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa",
                    "-o", str(out),
                ])
            with self.assertRaises(ValueError):
                gss.main([
                    "--ipa", str(ipa),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/android-v0.34.0/BRUMCLASSICS-MOVEL-0.34.0.apk",
                    "-o", str(out),
                ])
            with self.assertRaises(ValueError):
                gss.main([
                    "--ipa", str(exp_ipa),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.25.0/BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa",
                    "-o", str(out),
                ])
            with self.assertRaises(ValueError):
                gss.main([
                    "--ipa", str(wrong_bundle),
                    "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.25.0/BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa",
                    "-o", str(out),
                ])
            self.assertFalse(out.exists())

    def test_remote_verification_failure_preserves_existing_valid_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ipa24 = make_test_ipa(root / "BRUMCLASSICS-MOVEL-IOS-0.24.0.ipa", version="0.24.0", build="57")
            ipa25 = make_test_ipa(root / "BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa", version="0.25.0", build="58")
            out = root / "sidestore-source.json"
            gss.main([
                "--ipa", str(ipa24),
                "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.24.0/BRUMCLASSICS-MOVEL-IOS-0.24.0.ipa",
                "-o", str(out),
            ])
            preserved_before = out.read_text(encoding="utf-8")

            with mock.patch.object(gss, "_urlopen_strict", side_effect=OSError("network down")):
                with self.assertRaises(OSError):
                    gss.main([
                        "--ipa", str(ipa25),
                        "--download-url", "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.25.0/BRUMCLASSICS-MOVEL-IOS-0.25.0.ipa",
                        "--existing-source", str(out),
                        "--verify-remote",
                        "-o", str(out),
                    ])
            self.assertEqual(out.read_text(encoding="utf-8"), preserved_before)


if __name__ == "__main__":
    unittest.main()
