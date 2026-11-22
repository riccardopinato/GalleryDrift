#!/usr/bin/env python3
"""Guard against accidental package collision or bundling Apple model weights."""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml").read_text()
gradle = Path("android/app/build.gradle.kts").read_text()
assert 'applicationId = "com.riccardopinato.gallerydrift.lab"' in gradle
assert 'android:name="com.riccardopinato.gallerydrift.MainActivity"' in manifest
assert 'android:label="Gallery Drift AI Lab"' in manifest
assert "android.permission.INTERNET" in manifest
assert "MANAGE_EXTERNAL_STORAGE" not in manifest
assert not list(Path("assets").rglob("*.onnx")), "Apple model weights must not ship"
assert not list(Path("assets").rglob("*.gguf")), "Captioning weights must not ship"
print("GALLERY_DRIFT_AI_LAB_IDENTITY_ISOLATED")
