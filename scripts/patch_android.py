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
text = text.replace('android:label="gallerydrift"', 'android:label="Gallery Drift AI Lab"')
if "android.permission.INTERNET" not in text:
    text = text.replace("<application", '    <uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
manifest.write_text(text, encoding="utf-8")
package_dir = Path("android/app/src/main/kotlin/com/riccardopinato/gallerydrift")
package_dir.mkdir(parents=True, exist_ok=True)
source = Path("scripts/android/MainActivity.kt")
(package_dir / "MainActivity.kt").write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
# Preserve canonical Kotlin namespace for MainActivity, but install a separate lab
# applicationId so the production Gallery Drift app and private data are untouched.
gradle = Path("android/app/build.gradle.kts")
code = gradle.read_text(encoding="utf-8")
original = 'applicationId = "com.riccardopinato.gallerydrift"'
assert original in code, "Unexpected Android application ID; stop before building"
code = code.replace(original,
    'applicationId = "com.riccardopinato.gallerydrift.lab"')
gradle.write_text(code, encoding="utf-8")
print("Gallery Drift AI Lab: separate Android appId and no production data access")
