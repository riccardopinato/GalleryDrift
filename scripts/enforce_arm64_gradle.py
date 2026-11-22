#!/usr/bin/env python3
"""Constrain generated Flutter Android app to native ARM64 libraries.

Flutter's --target-platform limits its AOT engine/asset compilation, but
third-party JNI libraries can still be packaged for unrelated ABIs.
Apply an explicit defaultConfig NDK ABI filter to the generated app module
before Gradle evaluates variants; do not rewrite the Flutter SDK.
"""
from pathlib import Path
import sys

ARM64_BLOCK = """defaultConfig {
        // App Factory: ARM64-only APK; exclude unused ML Kit JNI ABIs.
        ndk {
            abiFilters.addAll(listOf("arm64-v8a"))
        }
"""
DEFAULT_CONFIG = "defaultConfig {"

def configure_gradle(path: Path) -> bool:
    source = path.read_text(encoding="utf-8")
    if source.count(DEFAULT_CONFIG) != 1 or "com.android.application" not in source:
        raise ValueError("ARM64_ABI_TEMPLATE_UNEXPECTED: generated Flutter app Gradle DSL has changed")
    if "abiFilters" in source:
        if ARM64_BLOCK in source:
            return False
        raise ValueError("ARM64_ABI_ALREADY_DEFINED: review existing ABI filters before editing")
    result = source.replace(DEFAULT_CONFIG, ARM64_BLOCK, 1)
    path.write_text(result, encoding="utf-8")
    print("ARM64_ONLY_GRADLE_ABI_FILTER_ENABLED")
    return True

if __name__ == "__main__":
    gradle = Path(sys.argv[1]) if len(sys.argv) == 2 else Path("android/app/build.gradle.kts")
    if not gradle.is_file():
        raise SystemExit("ARM64_ABI_GRADLE_MISSING: " + str(gradle))
    configure_gradle(gradle)
