#!/usr/bin/env python3
"""Inject stable release signing into a freshly generated Flutter Android shell.

Always keep standard internal builds separate: this script is only called by
the manual, secret-gated release workflow. Never persist signing material.
"""
from pathlib import Path
import os
import re

ROOT = Path(__file__).resolve().parents[1]
required = (
    "ANDROID_SIGNING_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD",
)
if any(not os.environ.get(name) for name in required):
    raise SystemExit("PRODUCTION_SIGNING_BLOCKED: missing required environment")
path = Path(os.environ["ANDROID_SIGNING_KEYSTORE_PATH"])
if not path.is_file():
    raise SystemExit("PRODUCTION_SIGNING_BLOCKED: keystore unavailable")
gradle = ROOT / "android/app/build.gradle.kts"
if not gradle.exists():
    raise SystemExit("PRODUCTION_SIGNING_BLOCKED: expected Flutter Kotlin Gradle DSL")
text = gradle.read_text(encoding="utf-8")
if 'signingConfigs.getByName("debug")' not in text or 'android {' not in text:
    raise SystemExit("PRODUCTION_SIGNING_BLOCKED: Flutter Gradle template changed")
insert = '''
    signingConfigs {
        create("driftStable") {
            storeFile = file(System.getenv("ANDROID_SIGNING_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
'''
text = text.replace("android {", "android {" + insert, 1)
text = text.replace('signingConfig = signingConfigs.getByName("debug")',
                    'signingConfig = signingConfigs.getByName("driftStable")', 1)
gradle.write_text(text, encoding="utf-8")
print("DRIFT_STABLE_SIGNING_CONFIGURED")
