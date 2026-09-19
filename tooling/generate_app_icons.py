#!/usr/bin/env python3
"""Generate Page-a-Diddle launcher icons (1024 master + adaptive foreground)."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icons"
OUT.mkdir(parents=True, exist_ok=True)

BG = (17, 18, 20)  # AppColors.stage
ACCENT = (255, 72, 0)
WHITE = (255, 255, 255)


def draw_mark(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    w = right - left
    h = bottom - top
    cx = (left + right) / 2
    cy = (top + bottom) / 2
    # Stylized score page + accent beat bar (forScore-inspired minimal mark)
    page_w = w * 0.62
    page_h = h * 0.78
    px = cx - page_w / 2
    py = cy - page_h / 2
    draw.rounded_rectangle(
        (px, py, px + page_w, py + page_h),
        radius=int(w * 0.06),
        fill=WHITE,
    )
    bar_w = page_w * 0.14
    bar_x = px + page_w * 0.18
    heights = [0.35, 0.55, 0.42, 0.68, 0.48]
    gap = page_w * 0.11
    for i, frac in enumerate(heights):
        x = bar_x + i * gap
        bar_h = page_h * frac
        y = py + page_h - bar_h - page_h * 0.12
        draw.rounded_rectangle(
            (x, y, x + bar_w, py + page_h - page_h * 0.12),
            radius=int(bar_w * 0.35),
            fill=ACCENT,
        )


def make_icon(size: int, padding: float, with_bg: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if with_bg:
        draw.rounded_rectangle(
            (0, 0, size, size),
            radius=int(size * 0.22),
            fill=BG,
        )
    pad = int(size * padding)
    draw_mark(draw, (pad, pad, size - pad, size - pad))
    return img


master = make_icon(1024, 0.18, True)
fg = make_icon(432, 0.22, False)
master.save(OUT / "app_icon.png")
fg.save(OUT / "app_icon_foreground.png")
print(f"Wrote {OUT / 'app_icon.png'} and foreground")
