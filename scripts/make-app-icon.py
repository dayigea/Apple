#!/usr/bin/env python3
"""
生成 1024×1024 的 App 图标，写到
  BabyTimeline/Assets.xcassets/AppIcon.appiconset/AppIcon.png

设计：粉色渐变背景 + 一颗白色苹果 + 一片绿叶 + 底部「苹果长大了」字样。
苹果用纯几何图形画（两个圆叠出果身 + 三角叶 + 小柄），不依赖任何插画素材。

不需要任何模型/网络资源，PIL 就够。
重新跑只要：python3 scripts/make-app-icon.py
"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "BabyTimeline" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
BG_TOP = (255, 192, 203)        # 浅粉
BG_BOTTOM = (255, 105, 135)     # 桃红
APPLE_FILL = (255, 252, 248)    # 暖白
APPLE_SHADOW = (240, 215, 220)  # 苹果阴影色
LEAF_FILL = (134, 200, 122)     # 嫩绿
LEAF_SHADOW = (102, 170, 92)
STEM_FILL = (120, 80, 50)       # 棕色柄


def vertical_gradient(width: int, height: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """从上到下的纯色渐变。"""
    base = Image.new("RGB", (width, height), top)
    top_arr = list(top)
    bottom_arr = list(bottom)
    for y in range(height):
        ratio = y / (height - 1)
        row = tuple(int(top_arr[i] + (bottom_arr[i] - top_arr[i]) * ratio) for i in range(3))
        for x in range(width):
            base.putpixel((x, y), row)
    return base


def fast_vertical_gradient(width: int, height: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """putpixel 太慢，改用整行填色。"""
    base = Image.new("RGB", (width, height), top)
    draw = ImageDraw.Draw(base)
    for y in range(height):
        ratio = y / (height - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        draw.line([(0, y), (width, y)], fill=row)
    return base


def draw_apple(canvas: Image.Image, cx: int, cy: int, radius: int) -> None:
    """画一个白色苹果。圆心在 (cx, cy)，半径大约是 radius。"""
    draw = ImageDraw.Draw(canvas)

    # 果身：稍扁的椭圆（横向略宽）
    body_w = int(radius * 2.05)
    body_h = int(radius * 2.0)
    body_box = (cx - body_w // 2, cy - body_h // 2, cx + body_w // 2, cy + body_h // 2)

    # 偏移阴影制造立体感
    shadow_offset = max(4, int(radius * 0.05))
    shadow_box = tuple(v + shadow_offset for v in body_box)
    draw.ellipse(shadow_box, fill=APPLE_SHADOW)
    draw.ellipse(body_box, fill=APPLE_FILL)

    # 苹果柄：从顶部中央伸出来
    stem_w = int(radius * 0.10)
    stem_h = int(radius * 0.30)
    stem_top_y = cy - body_h // 2 - int(stem_h * 0.55)
    draw.rounded_rectangle(
        (cx - stem_w // 2, stem_top_y, cx + stem_w // 2, stem_top_y + stem_h),
        radius=stem_w // 2,
        fill=STEM_FILL,
    )

    # 叶子：单独画到一个 RGBA 层上再旋转贴回来
    leaf_layer = Image.new("RGBA", (radius * 3, radius * 3), (0, 0, 0, 0))
    leaf_draw = ImageDraw.Draw(leaf_layer)
    lw, lh = int(radius * 1.15), int(radius * 0.55)
    lcx, lcy = leaf_layer.width // 2, leaf_layer.height // 2
    leaf_box = (lcx - lw // 2, lcy - lh // 2, lcx + lw // 2, lcy + lh // 2)
    # 阴影
    leaf_shadow_box = tuple(v + max(2, int(radius * 0.025)) for v in leaf_box)
    leaf_draw.ellipse(leaf_shadow_box, fill=LEAF_SHADOW)
    leaf_draw.ellipse(leaf_box, fill=LEAF_FILL)
    # 叶脉
    leaf_draw.line(
        (lcx - lw // 2 + int(lw * 0.15), lcy, lcx + lw // 2 - int(lw * 0.15), lcy),
        fill=LEAF_SHADOW,
        width=max(2, int(radius * 0.025)),
    )
    leaf_layer = leaf_layer.rotate(-28, resample=Image.BICUBIC)

    # 把叶子贴在苹果柄的右上方
    leaf_anchor_x = cx + int(radius * 0.20)
    leaf_anchor_y = stem_top_y - int(radius * 0.02)
    paste_pos = (leaf_anchor_x - leaf_layer.width // 2, leaf_anchor_y - leaf_layer.height // 2)
    canvas.paste(leaf_layer, paste_pos, leaf_layer)

    # 苹果上的高光：左上角一小块半透明白
    highlight = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    hw, hh = int(body_w * 0.34), int(body_h * 0.22)
    h_draw.ellipse(
        (int(body_w * 0.16), int(body_h * 0.18), int(body_w * 0.16) + hw, int(body_h * 0.18) + hh),
        fill=(255, 255, 255, 130),
    )
    canvas.paste(highlight, (cx - body_w // 2, cy - body_h // 2), highlight)


def find_chinese_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def main() -> None:
    img = fast_vertical_gradient(SIZE, SIZE, BG_TOP, BG_BOTTOM)
    draw = ImageDraw.Draw(img)

    # 苹果略微偏上，给底部文字留位置
    apple_cx = SIZE // 2
    apple_cy = int(SIZE * 0.44)
    apple_radius = int(SIZE * 0.26)
    draw_apple(img, apple_cx, apple_cy, apple_radius)

    # 底部「苹果长大了」
    text = "苹果长大了"
    font = find_chinese_font(int(SIZE * 0.11))
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (SIZE - text_w) // 2 - bbox[0]
    text_y = int(SIZE * 0.80) - bbox[1]
    # 文字阴影
    shadow_offset = max(2, int(SIZE * 0.004))
    draw.text(
        (text_x + shadow_offset, text_y + shadow_offset),
        text,
        font=font,
        fill=(180, 60, 90),
    )
    draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255))

    # iOS 1024 图标必须是 RGB 没透明度
    img = img.convert("RGB")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUTPUT, "PNG", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}  ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
