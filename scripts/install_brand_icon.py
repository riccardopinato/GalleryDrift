#!/usr/bin/env python3
"""Install a product-specific launcher icon into the Flutter-generated Android shell.
Source of truth: assets/branding/* SVG (original hand-authored vector marks).
Requires CairoSVG==2.7.1 as a build-time tool only; not packaged in the app.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

import cairosvg

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets/branding"
RES = ROOT / "android/app/src/main/res"
if not RES.exists():
    raise SystemExit("Create Android shell before running icon generator")

master = BRAND / "app_icon_master.svg"
foreground = BRAND / "app_icon_foreground.svg"
monochrome = BRAND / "app_icon_monochrome.svg"
for file in (master, foreground, monochrome):
    if not file.is_file():
        raise SystemExit(f"Missing branded master asset: {file}")
    ET.parse(file)

for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                      "xxhdpi": 144, "xxxhdpi": 192}.items():
    dst = RES / f"mipmap-{density}" / "ic_launcher.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(master), write_to=str(dst),
                     output_width=size, output_height=size)
    if dst.stat().st_size < 100:
        raise SystemExit("Generated launcher icon invalid")

drawable = RES / "drawable-nodpi"
drawable.mkdir(parents=True, exist_ok=True)
for source, filename in ((foreground, "drift_icon_foreground.png"),
                         (monochrome, "drift_icon_monochrome.png")):
    cairosvg.svg2png(url=str(source), write_to=str(drawable / filename),
                     output_width=432, output_height=432)
background = (BRAND / "app_icon_background.txt").read_text().strip()
if len(background) != 7 or not background.startswith("#"):
    raise SystemExit("Invalid background color")
values = RES / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "drift_icon_colors.xml").write_text(
    f'<resources><color name="drift_brand_background">{background}</color></resources>',
    encoding="utf-8")
adaptive = RES / "mipmap-anydpi-v26"
adaptive.mkdir(parents=True, exist_ok=True)
(adaptive / "ic_launcher.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/drift_brand_background" />
    <foreground android:drawable="@drawable/drift_icon_foreground" />
    <monochrome android:drawable="@drawable/drift_icon_monochrome" />
</adaptive-icon>
""", encoding="utf-8")
print("APP_ICON_PRODUCT_ASSETS_INSTALLED")
