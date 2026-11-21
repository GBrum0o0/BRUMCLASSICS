import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_ppsspp_assets import prepare_assets


class PSPAssetTests(unittest.TestCase):
    def test_replaces_unverified_font_and_preserves_notices_and_original(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "source"
            font = source / "assets/flash0/font/jpn0.pgf"
            font.parent.mkdir(parents=True)
            font.write_bytes(b"unverified old font")
            (source / "assets/ppge_atlas.zim").write_bytes(b"atlas")
            (source / "assets/.git").write_text("gitdir: /private/source")
            (source / "assets/.DS_Store").write_bytes(b"metadata")
            (source / "LICENSE.TXT").write_text("core license")
            vendor = source / "ext/vendor"
            vendor.mkdir(parents=True)
            (vendor / "COPYING").write_text("vendor license")
            notices = root / "fonts.txt"
            notices.write_text("font license")
            with patch("prepare_ppsspp_assets.download_font", return_value=b"verified replacement"):
                prepare_assets(source, root / "output", notices)
            self.assertEqual(font.read_bytes(), b"unverified old font")
            self.assertFalse((root / "output/CoreAssets/PPSSPP/.git").exists())
            self.assertFalse((root / "output/CoreAssets/PPSSPP/.DS_Store").exists())
            self.assertEqual((root / "output/CoreAssets/PPSSPP/flash0/font/jpn0.pgf").read_bytes(), b"verified replacement")
            text = (root / "output/PPSSPP-THIRD-PARTY.txt").read_text()
            for notice in ("core license", "vendor license", "font license"):
                self.assertIn(notice, text)

    def test_refuses_font_download_with_wrong_digest(self):
        from prepare_ppsspp_assets import download_font
        from io import BytesIO
        with patch("urllib.request.urlopen", return_value=BytesIO(b"wrong")):
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                download_font()


if __name__ == "__main__":
    unittest.main()
