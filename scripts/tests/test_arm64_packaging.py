import sys
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from enforce_arm64_gradle import configure_gradle, ARM64_BLOCK
from verify_arm64_apk import verify_apk, REQUIRED_NATIVE

TEMPLATE = """
plugins {
    id("com.android.application")
}
android {
    namespace = "com.riccardopinato.gallerydrift"
    defaultConfig {
        applicationId = "com.riccardopinato.gallerydrift"
        minSdk = flutter.minSdkVersion
    }
}
"""

class Arm64PackagingTests(unittest.TestCase):
    def test_gradle_arm64_abi_filter_injection_is_idempotent(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "build.gradle.kts"
            path.write_text(TEMPLATE)
            self.assertTrue(configure_gradle(path))
            self.assertIn(ARM64_BLOCK, path.read_text())
            self.assertFalse(configure_gradle(path))

    def test_gradle_rejects_conflicting_filters(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "build.gradle.kts"
            path.write_text(TEMPLATE.replace('defaultConfig {', 'defaultConfig {\n        ndk { abiFilters.add("x86_64") }'))
            with self.assertRaisesRegex(ValueError, "ARM64_ABI_ALREADY_DEFINED"):
                configure_gradle(path)

    def make_apk(self, folder, foreign=False, missing=False):
        path = Path(folder) / "app-release.apk"
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
