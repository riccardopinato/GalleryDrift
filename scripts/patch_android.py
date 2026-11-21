from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
permissions = """
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
"""
if "READ_MEDIA_IMAGES" not in text:
    text = text.replace("<application", permissions + "    <application",1)
text = text.replace('android:label="gallerydrift"', 'android:label="Gallery Drift"')
manifest.write_text(text, encoding="utf-8")
print("GalleryDrift Android manifest: image permissions, no MANAGE_EXTERNAL_STORAGE")
