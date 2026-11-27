"""Regression: the shared Core sync must never rewrite historical SHAs."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


class DriftCoreSyncTest(unittest.TestCase):
    def test_exact_live_pin_updates_without_editing_history(self):
        path = Path(__file__).resolve().parents[1] / "sync_drift_core.py"
        spec = importlib.util.spec_from_file_location("core_sync", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        old = "a" * 40
        new = "b" * 40
        with tempfile.TemporaryDirectory() as d:
            pub = Path(d) / "pubspec.yaml"
            doc = Path(d) / "doc.md"
            pub.write_text(
                "dependencies:\n  drift_core:\n    git:\n"
                "      url: https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery.git\n"
                f"      ref: {old}\n"
                "      path: packages/drift_core\n", encoding="utf-8")
            doc.write_text(f"Pinned core source commit: {old}\n"
                           f"Archived historical commit: {old}\n",
                           encoding="utf-8")
            with patch.object(mod, "PUB", pub), patch.object(mod, "DOC", doc):
                self.assertTrue(mod.update_pin(new))
                self.assertFalse(mod.update_pin(new))
            self.assertIn(f"      ref: {new}", pub.read_text())
            self.assertIn(f"Pinned core source commit: {new}", doc.read_text())
            self.assertIn(f"Archived historical commit: {old}", doc.read_text())


if __name__ == "__main__":
    unittest.main()
