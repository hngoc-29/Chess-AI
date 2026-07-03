#!/usr/bin/env python3
"""Generate polished Android launcher icons for a chess app.

This version intentionally avoids a flat, basic silhouette. It builds a premium
icon with:
- a deep gradient background,
- a subtle chessboard floor,
- a tilted metallic king piece,
- glow, rim light, shadow, and jewel accents.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter


BG_TOP = (78, 24, 53)
BG_BOTTOM = (16, 9, 18)

METAL_LIGHT = (255, 236, 182)
METAL_MID = (209, 160, 82)
METAL_DARK = (108, 66, 24)

OUTLINE = (45, 24, 12)
SHADOW = (0, 0, 0)
GLOW = (255, 196, 98)

ACCENT_GOLD = (255, 210, 118)
ACCENT_RED = (177, 35, 52)
ACCENT_BLUE = (54, 93, 192)

CHECK_LIGHT = (210, 182, 133, 56)
CHECK_DARK = (32, 18, 24, 88)

SUPERSAMPLE = {48: 8, 72: 6, 96: 5, 144: 4, 192: 4}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = lerp(top, bottom, t)
        for x in range(w):
            px[x, y] = (*c, 255)
    return img


def radial_gradient(size, inner, outer, center=None, radius=0.9):
    w, h = size
    cx, cy = center if center else (w * 0.5, h * 0.45)
    img = Image.new("RGBA", size, outer + (255,))
    px = img.load()
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / (w * radius)
            dy = (y - cy) / (h * radius)
            t = min(1.0, (dx * dx + dy * dy) ** 0.5)
            c = lerp(inner, outer, t)
            px[x, y] = (*c, 255)
    return img


def rounded_mask(size, radius_frac=0.22):
    w, h = size
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    r = int(min(w, h) * radius_frac)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m


def gradient_fill(size, mask, c1, c2, angle=0):
    grad = vertical_gradient(size, c1, c2)
    if angle:
        grad = grad.rotate(angle, resample=Image.Resampling.BICUBIC, expand=False)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def polygon_mask(size, pts):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.polygon(pts, fill=255)
    return m


def king_body_layer(size):
    """Create a stylized king silhouette on its own layer."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))

    # Main body silhouette: slight asymmetry to feel angled and less basic.
    pts = [
        (0.34 * w, 0.84 * h),
        (0.29 * w, 0.73 * h),
        (0.27 * w, 0.62 * h),
        (0.28 * w, 0.52 * h),
        (0.31 * w, 0.43 * h),
        (0.34 * w, 0.34 * h),
        (0.39 * w, 0.25 * h),
        (0.46 * w, 0.18 * h),
        (0.53 * w, 0.15 * h),
        (0.60 * w, 0.17 * h),
        (0.66 * w, 0.22 * h),
        (0.71 * w, 0.30 * h),
        (0.75 * w, 0.40 * h),
        (0.78 * w, 0.52 * h),
        (0.80 * w, 0.64 * h),
        (0.77 * w, 0.76 * h),
        (0.73 * w, 0.84 * h),
        (0.68 * w, 0.86 * h),
        (0.33 * w, 0.86 * h),
    ]

    body_mask = polygon_mask(size, pts)
    body_mask = body_mask.rotate(-12, resample=Image.Resampling.BICUBIC, expand=False, center=(w * 0.5, h * 0.55))

    # Outline first.
    outline = Image.new("RGBA", size, (*OUTLINE, 255))
    outline_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    outline_layer.paste(outline, (0, 0), body_mask.filter(ImageFilter.MaxFilter(9)))
    layer = Image.alpha_composite(layer, outline_layer)

    # Metallic fill.
    fill = gradient_fill(size, body_mask, METAL_LIGHT, METAL_DARK, angle=25)
    layer = Image.alpha_composite(layer, fill)

    # Inner highlight strip.
    hi_mask = Image.new("L", size, 0)
    hd = ImageDraw.Draw(hi_mask)
    hd.polygon([
        (0.42 * w, 0.20 * h),
        (0.48 * w, 0.18 * h),
        (0.55 * w, 0.22 * h),
        (0.51 * w, 0.70 * h),
        (0.46 * w, 0.72 * h),
        (0.40 * w, 0.56 * h),
    ], fill=255)
    hi_mask = hi_mask.rotate(-12, resample=Image.Resampling.BICUBIC, expand=False, center=(w * 0.5, h * 0.55))
    highlight = Image.new("RGBA", size, (255, 255, 255, 0))
    highlight.paste(Image.new("RGBA", size, (255, 255, 255, 95)), (0, 0), hi_mask)
    layer = Image.alpha_composite(layer, highlight)

    # Base ring and foot.
    ring = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([0.31 * w, 0.78 * h, 0.73 * w, 0.89 * h], outline=(*OUTLINE, 190), width=max(1, int(w * 0.018)))
    rd.ellipse([0.35 * w, 0.81 * h, 0.69 * w, 0.87 * h], fill=(*METAL_DARK, 210))
    layer = Image.alpha_composite(layer, ring)

    # Neck cut for depth.
    cut = Image.new("L", size, 0)
    cd = ImageDraw.Draw(cut)
    cd.ellipse([0.42 * w, 0.36 * h, 0.63 * w, 0.60 * h], fill=255)
    cut = cut.rotate(-12, resample=Image.Resampling.BICUBIC, expand=False, center=(w * 0.5, h * 0.55))
    cut_rgb = Image.new("RGBA", size, (0, 0, 0, 0))
    cut_rgb.paste(Image.new("RGBA", size, (38, 20, 10, 150)), (0, 0), cut)
    layer = Image.alpha_composite(layer, cut_rgb)

    return layer


def king_crown_layer(size):
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Crown band.
    band = [(0.39 * w, 0.20 * h), (0.62 * w, 0.17 * h), (0.66 * w, 0.26 * h), (0.42 * w, 0.28 * h)]
    d.polygon(band, fill=(*OUTLINE, 255))
    d.polygon(band, fill=(*METAL_MID, 255))

    # Three spikes with asymmetry for a more refined silhouette.
    spikes = [
        [(0.41 * w, 0.20 * h), (0.47 * w, 0.06 * h), (0.52 * w, 0.21 * h)],
        [(0.50 * w, 0.18 * h), (0.58 * w, 0.01 * h), (0.64 * w, 0.20 * h)],
        [(0.59 * w, 0.18 * h), (0.68 * w, 0.08 * h), (0.73 * w, 0.24 * h)],
    ]
    for pts in spikes:
        d.polygon(pts, fill=(*OUTLINE, 255))
        d.polygon(pts, fill=(*METAL_LIGHT, 255))

    # Cross on top.
    cross = Image.new("RGBA", size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(cross)
    cx, cy = 0.58 * w, 0.005 * h
    cd.rounded_rectangle([cx - 0.015 * w, cy, cx + 0.015 * w, cy + 0.10 * h], radius=max(1, int(0.01 * w)), fill=(*METAL_LIGHT, 255))
    cd.rounded_rectangle([cx - 0.045 * w, cy + 0.03 * h, cx + 0.045 * w, cy + 0.055 * h], radius=max(1, int(0.008 * w)), fill=(*METAL_LIGHT, 255))
    layer = Image.alpha_composite(layer, cross)

    # Jewels.
    for x, y, color in [
        (0.47 * w, 0.23 * h, ACCENT_BLUE),
        (0.58 * w, 0.23 * h, ACCENT_RED),
        (0.66 * w, 0.21 * h, ACCENT_GOLD),
    ]:
        r = 0.017 * w
        d.ellipse([x - r, y - r, x + r, y + r], fill=(*OUTLINE, 255))
        d.ellipse([x - r * 0.82, y - r * 0.82, x + r * 0.82, y + r * 0.82], fill=(*color, 255))
        d.ellipse([x - r * 0.26, y - r * 0.26, x + r * 0.05, y + r * 0.05], fill=(255, 255, 255, 210))

    return layer.rotate(-12, resample=Image.Resampling.BICUBIC, expand=False, center=(w * 0.5, h * 0.34))


def chess_floor_layer(size):
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Perspective chess floor in the bottom portion.
    cols, rows = 8, 3
    x_left, x_right = 0.12 * w, 0.88 * w
    y_top, y_bot = 0.83 * h, 0.98 * h
    for r in range(rows):
        t0, t1 = r / rows, (r + 1) / rows
        y0 = y_top + (y_bot - y_top) * t0
        y1 = y_top + (y_bot - y_top) * t1
        inset0 = (0.16 - 0.03 * r) * w
        inset1 = (0.16 - 0.01 * r) * w
        xl0, xr0 = x_left + inset0, x_right - inset0
        xl1, xr1 = x_left + inset1, x_right - inset1
        for c in range(cols):
            u0, u1 = c / cols, (c + 1) / cols
            x0 = xl0 + (xr0 - xl0) * u0
            x1 = xl0 + (xr0 - xl0) * u1
            x2 = xl1 + (xr1 - xl1) * u1
            x3 = xl1 + (xr1 - xl1) * u0
            pts = [(x0, y0), (x1, y0), (x2, y1), (x3, y1)]
            d.polygon(pts, fill=CHECK_LIGHT if (r + c) % 2 == 0 else CHECK_DARK)

    return layer.filter(ImageFilter.GaussianBlur(int(min(w, h) * 0.0035)))


def vignette_layer(size):
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(30, 0, -1):
        pad = int(min(w, h) * (0.012 * i))
        alpha = int(12 * (1 - i / 30) ** 1.8)
        d.rounded_rectangle([pad, pad, w - 1 - pad, h - 1 - pad], radius=int(min(w, h) * 0.2), outline=(0, 0, 0, alpha))
    return layer.filter(ImageFilter.GaussianBlur(int(min(w, h) * 0.01)))


def glow_ring_layer(size):
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = 0.56 * w, 0.48 * h
    for i in range(26, 0, -1):
        r = int(min(w, h) * (0.08 + 0.012 * i))
        a = int(85 * (1 - i / 26) ** 1.7)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*GLOW, a), width=max(1, int(w * 0.004)))
    return layer.filter(ImageFilter.GaussianBlur(int(min(w, h) * 0.018)))


def render_king_icon(size, ss=None):
    ss = ss or SUPERSAMPLE.get(size, 4)
    S = size * ss

    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg = vertical_gradient((S, S), BG_TOP, BG_BOTTOM)
    bg = Image.alpha_composite(bg, radial_gradient((S, S), (92, 34, 61), BG_BOTTOM, center=(S * 0.43, S * 0.35), radius=0.92))
    mask = rounded_mask((S, S), 0.22)
    canvas.paste(bg, (0, 0), mask)

    # Large elegant halo.
    canvas = Image.alpha_composite(canvas, glow_ring_layer((S, S)))

    # Subtle floor.
    canvas = Image.alpha_composite(canvas, chess_floor_layer((S, S)))

    # Piece shadow.
    body = king_body_layer((S, S))
    body_mask = body.split()[-1]
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sm = body_mask.filter(ImageFilter.GaussianBlur(int(S * 0.012)))
    shadow.paste(Image.new("RGBA", (S, S), (*SHADOW, 150)), (int(S * 0.012), int(S * 0.03)), sm)
    canvas = Image.alpha_composite(canvas, shadow)

    # Main body and crown.
    canvas = Image.alpha_composite(canvas, body)
    canvas = Image.alpha_composite(canvas, king_crown_layer((S, S)))

    # Rim light and sparkle.
    rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.arc([0.28 * S, 0.12 * S, 0.78 * S, 0.80 * S], start=220, end=320, fill=(255, 255, 255, 70), width=max(1, int(S * 0.008)))
    rd.arc([0.34 * S, 0.20 * S, 0.69 * S, 0.83 * S], start=215, end=325, fill=(255, 230, 178, 55), width=max(1, int(S * 0.006)))
    canvas = Image.alpha_composite(canvas, rim)

    spark = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    for x, y, r in [(0.74 * S, 0.29 * S, 0.022 * S), (0.23 * S, 0.62 * S, 0.016 * S)]:
        sd.polygon(
            [(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28),
             (x, y + r), (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)],
            fill=(255, 232, 165, 190)
        )
    spark = spark.filter(ImageFilter.GaussianBlur(int(S * 0.002)))
    canvas = Image.alpha_composite(canvas, spark)

    # Vignette and edge polish.
    canvas = Image.alpha_composite(canvas, vignette_layer((S, S)))

    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def generate_launcher_icons():
    icons = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    base_path = "./android/app/src/main/res"
    print("Generating Android launcher icons...")

    for density, size in icons.items():
        dir_path = os.path.join(base_path, density)
        os.makedirs(dir_path, exist_ok=True)

        icon_path = os.path.join(dir_path, "ic_launcher.png")
        img = render_king_icon(size)
        img.save(icon_path, "PNG")
        print(f"✓ Created {density}/ic_launcher.png ({size}x{size})")

    print("\n✓ All launcher icons generated successfully!")
    return True


if __name__ == "__main__":
    try:
        success = generate_launcher_icons()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
