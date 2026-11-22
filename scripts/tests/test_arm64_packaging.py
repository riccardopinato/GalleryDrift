"""Regression tests for optimized ARM64 APK packaging and size policy."""
import sys
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_arm64_apk import verify_apk, REQUIRED_NATIVE

class Arm64PackagingTests(unittest.TestCase):
    def test_all_android_workflows_use_split_per_abi(self):
        root = Path(__file__).resolve().parents[2]
        for filename in ("release-signed.yml", "android.yml"):
            workflow = (root / ".github/workflows" / filename).read_text(encoding="utf-8")
            self.assertIn("flutter build apk --release --split-per-abi --target-platform android-arm64", workflow)
            self.assertIn("build/app/outputs/flutter-apk/app-arm64-v8a-release.apk", workflow)
            self.assertNotIn("build/app/outputs/flutter-apk/app-release.apk", workflow)
            self.assertNotIn("enforce_arm64_gradle.py", workflow)

    def make_apk(self, folder, foreign=False, missing=False):
        path = Path(folder) / "app-arm64-v8a-release.apk"
        with ZipFile(path, "w", compression=ZIP_STORED) as archive:
            for name in REQUIRED_NATIVE:
                if missing and name.endswith("/libflutter.so"):
                    continue
                archive.writestr(name, b"test")
            if foreign:
                archive.writestr("lib/x86_64/libmlkitcommonpipeline.so", b"test")
        return path

    def test_arm64_only_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            apk = self.make_apk(folder)
            self.assertEqual(verify_apk(apk)["abis"], frozenset({"arm64-v8a"}))

    def test_foreign_abi_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            apk = self.make_apk(folder, foreign=True)
            with self.assertRaisesRegex(ValueError, "APK_FOREIGN_ABI_FAIL"):
                verify_apk(apk)

    def test_missing_flutter_engine_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            apk = self.make_apk(folder, missing=True)
            with self.assertRaisesRegex(ValueError, "APK_REQUIRED_LIBRARY_MISSING"):
                verify_apk(apk)

    def test_budget_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            apk = self.make_apk(folder)
            with self.assertRaisesRegex(ValueError, "APK_SIZE_BUDGET_FAIL"):
                verify_apk(apk, max_mib=0.000001)

if __name__ == "__main__":
    unittest.main()
