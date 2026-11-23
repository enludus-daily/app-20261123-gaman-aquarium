#!/usr/bin/env python3
"""がまん水族館のアイコン（1024x1024、透過なし）。夜の水・上から差す光の筋・砂の上の光る卵と、そばを泳ぐ光る魚。
使い方: python3 scripts/make-icon-aquarium.py"""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def hx(v):
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, mid, low = hx("123B5E"), hx("0B2546"), hx("06142B")
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=lerp(top, mid, t * 2) if t < 0.5 else lerp(mid, low, (t - 0.5) * 2))

# 光の筋
beams = Image.new("RGB", (S, S), (0, 0, 0))
bd = ImageDraw.Draw(beams)
for x0, shift in [(120, 140), (420, -90), (700, 120)]:
    bd.polygon([(x0, 0), (x0 + 80, 0), (x0 + shift + 220, 830), (x0 + shift, 830)], fill=(40, 70, 85))
beams = beams.filter(ImageFilter.GaussianBlur(30))

img = ImageChops.add(img, beams)
d = ImageDraw.Draw(img)

# 砂
d.ellipse([-300, 800, 1324, 1400], fill=hx("6F8599"))
d.ellipse([-300, 830, 1324, 1430], fill=hx("4E6378"))

# 卵の光
glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([330, 470, 700, 880], fill=(150, 90, 50))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img = ImageChops.add(img, glow)
d = ImageDraw.Draw(img)

# 卵
egg = Image.new("L", (S, S), 0)
ed = ImageDraw.Draw(egg)
ed.ellipse([400, 520, 630, 840], fill=255)
ed.ellipse([425, 480, 605, 720], fill=255)
egg = egg.filter(ImageFilter.GaussianBlur(2))
eggcol = Image.new("RGB", (S, S), hx("FFC9A6"))
img = Image.composite(eggcol, img, egg)
d = ImageDraw.Draw(img)
d.ellipse([470, 560, 540, 630], fill=hx("FFF4EA"))

# 魚（光る）
fglow = Image.new("RGB", (S, S), (0, 0, 0))
fg = ImageDraw.Draw(fglow)
fg.ellipse([560, 200, 900, 400], fill=(30, 110, 120))
fglow = fglow.filter(ImageFilter.GaussianBlur(50))
img = ImageChops.add(img, fglow)
d = ImageDraw.Draw(img)
d.polygon([(600, 300), (540, 230), (555, 300), (540, 370)], fill=hx("C4F0FF"))
d.ellipse([580, 245, 860, 355], fill=hx("6FD3FF"))
d.line([(610, 297), (835, 297)], fill=hx("FFFFFF"), width=8)
d.ellipse([800, 275, 822, 297], fill=hx("0B1426"))

# 泡
for x, y, r in [(250, 520, 14), (270, 430, 10), (240, 350, 18), (262, 260, 9)]:
    d.ellipse([x - r, y - r, x + r, y + r], outline=hx("CFE6F5"), width=4)

img.save(OUT)
print("wrote", OUT)
