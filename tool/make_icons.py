#!/usr/bin/env python3
"""Generate Android launcher icons (legacy mipmap + adaptive) from design/icon_src.png."""
import os
import sys

from PIL import Image

WS = os.path.abspath(sys.argv[1])
RES = os.path.join(WS, "vshape_app", "android", "app", "src", "main", "res")
SRC = os.path.join(WS, "vshape_app", "design", "icon_src.png")
BG = (11, 16, 32, 255)  # #0B1020

src = Image.open(SRC).convert("RGBA")
# make it square by center-cropping
w, h = src.size
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
src = src.crop((left, top, left + side, top + side))

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
PLAY = 512

for d, size in LEGACY.items():
    folder = os.path.join(RES, "mipmap-" + d)
    os.makedirs(folder, exist_ok=True)
    src.resize((size, size), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"))
    print("legacy", d, size)

# adaptive icons: 108dp canvas, safe zone ~66dp
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
for d, size in ADAPTIVE.items():
    folder = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(os.path.join(RES, "drawable-" + d), exist_ok=True)
    # background
    Image.new("RGBA", (size, size), BG).save(
        os.path.join(RES, "drawable-" + d, "ic_launcher_background.png"))
    # foreground: design scaled to the 66/108 safe zone, centred
    inner = int(round(size * 66 / 108))
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scaled = src.resize((inner, inner), Image.LANCZOS)
    fg.paste(scaled, ((size - inner) // 2, (size - inner) // 2), scaled)
    fg.save(os.path.join(RES, "drawable-" + d, "ic_launcher_foreground.png"))
    print("adaptive", d, size)

os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w") as f:
    f.write(xml)

out = os.path.join(WS, "vshape_app", "design", "play_store_icon.png")
src.resize((PLAY, PLAY), Image.LANCZOS).save(out)
print("play icon", out)
print("ICONS_DONE")
