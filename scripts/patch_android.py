from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
permissions = """
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
"""
if "READ_MEDIA_IMAGES" not in text:
    text = text.replace("<application", permissions + "    <application",1)
text = text.replace('android:label="gallerydrift"', 'android:label="Gallery Drift"')
manifest.write_text(text, encoding="utf-8")
package_dir = Path("android/app/src/main/kotlin/com/riccardopinato/gallerydrift")
package_dir.mkdir(parents=True, exist_ok=True)
source = Path("scripts/android/MainActivity.kt")
(package_dir / "MainActivity.kt").write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
print("GalleryDrift Android manifest + MediaStore trash review and OS confirmation bridge")
