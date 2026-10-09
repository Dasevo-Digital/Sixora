#!/usr/bin/env python3
"""Draws the Sixora app icon (a shield with six dots, one per code digit)
and writes it in the native shape of every platform.

    python3 tool/make_icons.py      # from the app/ directory; needs Pillow
"""
import json
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

TOP = (99, 102, 241)  # indigo 500
BOTTOM = (67, 56, 202)  # indigo 700
DOT = (67, 56, 202, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling for smooth edges

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def path(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def gradient(size):
    """Vertical indigo gradient."""
    g = Image.new("RGBA", (1, 256))
    for y in range(256):
        t = y / 255
        g.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,))
    return g.resize((size, size), Image.BILINEAR)


def superellipse(size, box, n=5.0):
    """Mask of Apple's continuous-corner squircle inside [box]."""
    x0, y0, x1, y1 = box
    cx, cy, a, b = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    pts = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + a * math.copysign(abs(c) ** (2 / n), c),
                    cy + b * math.copysign(abs(s) ** (2 / n), s)))
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def rounded(size, box, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def shield_points(cx, top, w):
    """Shield outline, [w] wide, starting at [top]."""
    h = w * 1.2
    pts = [(cx, top), (cx + w / 2, top + h * 0.15), (cx + w / 2, top + h * 0.48)]
    for i in range(1, 41):
        t = i / 40
        pts.append((cx + w / 2 * (1 - t) ** 1.2, top + h * (0.48 + 0.52 * math.sin(t * math.pi / 2))))
    for i in range(39, 0, -1):
        t = i / 40
        pts.append((cx - w / 2 * (1 - t) ** 1.2, top + h * (0.48 + 0.52 * math.sin(t * math.pi / 2))))
    pts += [(cx - w / 2, top + h * 0.48), (cx - w / 2, top + h * 0.15)]
    return pts


def glyph(size, scale=1.0, dot=DOT, knockout=False):
    """White shield with six dots on a transparent canvas of [size] px.

    [scale] is the glyph width relative to the canvas. With [knockout] the
    dots are cut out (single-color silhouettes such as themed icons).
    """
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = size * scale * 0.8
    cx = size / 2
    top = size / 2 - w * 0.6
    d.polygon(shield_points(cx, top, w), fill=WHITE)
    r = w * 0.075
    dots = [(cx + (col - 1) * w * 0.27, top + w * (0.5 + row * 0.3)) for row in range(2) for col in range(3)]
    if knockout:
        mask = Image.new("L", (size, size), 0)
        md = ImageDraw.Draw(mask)
        for x, y in dots:
            md.ellipse([x - r, y - r, x + r, y + r], fill=255)
        im.putalpha(ImageChops.subtract(im.getchannel("A"), mask))
    else:
        for x, y in dots:
            d.ellipse([x - r, y - r, x + r, y + r], fill=dot)
    return im


def compose(size, shape_mask, glyph_scale, shadow=None):
    """Gradient tile clipped by [shape_mask], glyph on top, optional shadow."""
    tile = gradient(size)
    tile.alpha_composite(glyph(size, glyph_scale))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if shadow:
        blur, dy, alpha = shadow
        sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sh.putalpha(shape_mask.point(lambda v: v * alpha // 255))
        sh = sh.transform(sh.size, Image.AFFINE, (1, 0, 0, 0, 1, -dy)).filter(ImageFilter.GaussianBlur(blur))
        out.alpha_composite(sh)
    tile.putalpha(shape_mask)
    out.alpha_composite(tile)
    return out


def render(px, draw):
    """Draws at [px]*SS and downsamples for anti-aliasing."""
    return draw(px * SS).resize((px, px), Image.LANCZOS)


# --- platform shapes ---------------------------------------------------------

def macos(px):
    # Apple grid: 824/1024 squircle body, soft drop shadow.
    def draw(s):
        k = s / 1024
        mask = superellipse(s, (100 * k, 92 * k, 924 * k, 916 * k))
        return compose(s, mask, 0.56 * 824 / 1024, shadow=(14 * k, 10 * k, 80))
    return render(px, draw)


def tile(px, margin):
    """Rounded square used on Windows, Linux and legacy Android."""
    def draw(s):
        m = s * margin
        return compose(s, rounded(s, (m, m, s - m, s - m), (s - 2 * m) * 0.23), 0.62 * (1 - 2 * margin))
    return render(px, draw)


def android_foreground(px):
    # 108dp canvas; launchers show the inner 72dp, keep the glyph in 66dp.
    return render(px, lambda s: glyph(s, 0.42))


def template(px):
    """Black silhouette for the macOS menu bar (template image)."""
    im = render(px, lambda s: glyph(s, 1.05, knockout=True))
    black = Image.new("RGBA", im.size, (0, 0, 0, 255))
    black.putalpha(im.getchannel("A"))
    return black


def android_monochrome(px):
    return render(px, lambda s: glyph(s, 0.42, knockout=True))


def ios(px):
    """Full square without transparency: iOS rounds the corners itself."""
    def draw(s):
        tile = gradient(s)
        tile.alpha_composite(glyph(s, 0.62))
        return tile
    return render(px, draw).convert("RGB")


def save_ico(file, sizes):
    images = [tile(s, 0.0 if s <= 32 else 0.04) for s in sizes]
    images[-1].save(file, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[:-1])


def main():
    tile(1024, 0.0).save(path("assets/icon/app_icon.png"))

    # macOS
    for s in (16, 32, 64, 128, 256, 512, 1024):
        macos(s).save(path(f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{s}.png"))

    # iOS: every size the asset catalog lists.
    catalog = path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    with open(os.path.join(catalog, "Contents.json")) as f:
        for entry in json.load(f)["images"]:
            if "filename" not in entry:
                continue
            px = round(float(entry["size"].split("x")[0]) * int(entry["scale"][0]))
            ios(px).save(os.path.join(catalog, entry["filename"]))

    # Windows: all sizes Explorer and the taskbar ask for.
    save_ico(path("windows/runner/resources/app_icon.ico"), [16, 20, 24, 32, 40, 48, 64, 96, 128, 256])

    # Android: legacy icon plus adaptive and themed (monochrome) layers.
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    res = "android/app/src/main/res"
    for name, f in densities.items():
        tile(round(48 * f), 0.06).save(path(f"{res}/mipmap-{name}/ic_launcher.png"))
        android_foreground(round(108 * f)).save(path(f"{res}/drawable-{name}/ic_launcher_foreground.png"))
        android_monochrome(round(108 * f)).save(path(f"{res}/drawable-{name}/ic_launcher_monochrome.png"))
    with open(path(f"{res}/mipmap-anydpi-v26/ic_launcher.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
            '</adaptive-icon>\n'
        )
    with open(path(f"{res}/values/ic_launcher_background.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            '    <color name="ic_launcher_background">#4F46E5</color>\n</resources>\n'
        )
    # Tray / menu bar: macOS template (black, the system tints it), a small
    # tile for Linux and an ICO for the Windows notification area.
    template(36).save(path("assets/tray/tray_template.png"))
    tile(64, 0.0).save(path("assets/tray/tray.png"))
    images = [tile(sz, 0.0) for sz in (16, 20, 24, 32, 48)]
    images[-1].save(path("assets/tray/tray.ico"), format="ICO",
                    sizes=[(sz, sz) for sz in (16, 20, 24, 32, 48)], append_images=images[:-1])
    print("icons written")


if __name__ == "__main__":
    main()
