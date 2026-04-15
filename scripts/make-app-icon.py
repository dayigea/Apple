#!/usr/bin/env python3
"""
生成 1024×1024 的 App 图标，写到
  BabyTimeline/Assets.xcassets/AppIcon.appiconset/AppIcon.png

设计：暖奶油色背景 + 一颗真正「苹果形」的红苹果（两瓣叠出的双丘身形 +
顶部凹陷 + 棕色果柄 + 嫩绿叶子 + 左上高光）。只用 PIL 的基本几何，
不依赖任何位图素材或字体。

要求：
- 1024×1024
- PNG
- 没有 alpha 通道（iOS AppIcon 不允许）

跑一次：python3 scripts/make-app-icon.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "BabyTimeline" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024

# 暖奶油背景渐变：从浅米色到稍深的桃色，给红苹果当衬底
BG_TOP = (255, 247, 237)        # 奶油
BG_BOTTOM = (255, 221, 203)     # 浅桃

# 红苹果配色
APPLE_RED = (215, 50, 55)       # 主体红
APPLE_RED_DARK = (165, 28, 35)  # 暗面
APPLE_RED_HL = (246, 120, 118)  # 亮面（偏粉）

# 果柄
STEM_BROWN = (94, 58, 34)
STEM_BROWN_HL = (140, 90, 55)

# 叶子
LEAF_GREEN = (86, 170, 78)
LEAF_GREEN_DARK = (52, 120, 48)
LEAF_HL = (170, 220, 140)


def fast_vertical_gradient(width: int, height: int,
                           top: tuple[int, int, int],
                           bottom: tuple[int, int, int]) -> Image.Image:
    """从上到下的纯色渐变，用整行填色比 putpixel 快很多。"""
    base = Image.new("RGB", (width, height), top)
    draw = ImageDraw.Draw(base)
    for y in range(height):
        ratio = y / (height - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        draw.line([(0, y), (width, y)], fill=row)
    return base


def draw_apple_body(canvas: Image.Image, cx: int, cy: int, radius: int) -> None:
    """
    画一个真正像苹果的红色果身：两瓣圆叠加出双丘、顶部有凹陷、底部有凹陷。
    再覆上亮面 / 暗面阴影做立体。
    """
    # 所有苹果绘制放在一个专属 RGBA 图层上，然后 paste 到主画布
    L = radius * 3
    layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    lcx, lcy = L // 2, L // 2

    # —— 1. 身形：两个左右偏移的圆 ——
    # 每个圆代表苹果的一瓣，中间重叠形成「梨形 / 心形」轮廓
    lobe_r = int(radius * 0.78)
    offset_x = int(radius * 0.20)
    lobes = [
        (lcx - offset_x, lcy + int(radius * 0.05), lobe_r),
        (lcx + offset_x, lcy + int(radius * 0.05), lobe_r),
    ]
    for (bx, by, br) in lobes:
        d.ellipse((bx - br, by - br, bx + br, by + br), fill=APPLE_RED)

    # —— 2. 顶部凹陷（果柄窝） ——
    # 用背景色（transparent）的小椭圆「咬」掉一块，制造凹陷的视觉
    dimple_w = int(radius * 0.55)
    dimple_h = int(radius * 0.26)
    dimple_box = (
        lcx - dimple_w // 2,
        lcy - lobe_r - int(dimple_h * 0.25) + int(radius * 0.05),
        lcx + dimple_w // 2,
        lcy - lobe_r + int(dimple_h * 0.75) + int(radius * 0.05),
    )
    d.ellipse(dimple_box, fill=(0, 0, 0, 0))

    # 凹陷下方加一点点暗色阴影，看起来更立体
    shadow_w = int(dimple_w * 0.75)
    shadow_h = int(dimple_h * 0.45)
    sh_cx = lcx
    sh_cy = dimple_box[3] + int(shadow_h * 0.2)
    d.ellipse(
        (sh_cx - shadow_w // 2, sh_cy - shadow_h // 2,
         sh_cx + shadow_w // 2, sh_cy + shadow_h // 2),
        fill=APPLE_RED_DARK,
    )

    # —— 3. 暗面：右下角盖一个半透明暗红椭圆，模拟光从左上来 ——
    dark_layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dark_layer)
    dark_w = int(radius * 1.45)
    dark_h = int(radius * 1.55)
    dark_cx = lcx + int(radius * 0.30)
    dark_cy = lcy + int(radius * 0.25)
    dd.ellipse(
        (dark_cx - dark_w // 2, dark_cy - dark_h // 2,
         dark_cx + dark_w // 2, dark_cy + dark_h // 2),
        fill=APPLE_RED_DARK + (120,),
    )
    dark_layer = dark_layer.filter(ImageFilter.GaussianBlur(radius=radius * 0.12))
    # 只保留苹果身形内的暗部：用果身作为 mask
    body_mask = Image.new("L", (L, L), 0)
    bd = ImageDraw.Draw(body_mask)
    for (bx, by, br) in lobes:
        bd.ellipse((bx - br, by - br, bx + br, by + br), fill=255)
    dark_masked = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    dark_masked.paste(dark_layer, (0, 0), body_mask)
    layer = Image.alpha_composite(layer, dark_masked)

    # —— 4. 亮面 / 高光：左上角一小块模糊白 ——
    hl_layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl_layer)
    hl_w = int(radius * 0.75)
    hl_h = int(radius * 0.55)
    hl_cx = lcx - int(radius * 0.35)
    hl_cy = lcy - int(radius * 0.28)
    hd.ellipse(
        (hl_cx - hl_w // 2, hl_cy - hl_h // 2,
         hl_cx + hl_w // 2, hl_cy + hl_h // 2),
        fill=APPLE_RED_HL + (180,),
    )
    # 再一个更亮的小点
    sp_r = int(radius * 0.16)
    sp_cx = lcx - int(radius * 0.42)
    sp_cy = lcy - int(radius * 0.38)
    hd.ellipse(
        (sp_cx - sp_r, sp_cy - sp_r, sp_cx + sp_r, sp_cy + sp_r),
        fill=(255, 255, 255, 200),
    )
    hl_layer = hl_layer.filter(ImageFilter.GaussianBlur(radius=radius * 0.06))

    hl_masked = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    hl_masked.paste(hl_layer, (0, 0), body_mask)
    layer = Image.alpha_composite(layer, hl_masked)

    # —— 5. 整体投影：在下方贴一个软阴影 ——
    # 这一步在 canvas 上做，要在 paste 苹果之前画
    # 但为了顺序清爽，先构造好，后面再 paste
    shadow_canvas = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_canvas)
    sh_w = int(radius * 2.0)
    sh_h = int(radius * 0.4)
    sh_cx2 = lcx + int(radius * 0.05)
    sh_cy2 = lcy + lobe_r + int(radius * 0.35)
    sd.ellipse(
        (sh_cx2 - sh_w // 2, sh_cy2 - sh_h // 2,
         sh_cx2 + sh_w // 2, sh_cy2 + sh_h // 2),
        fill=(100, 40, 40, 90),
    )
    shadow_canvas = shadow_canvas.filter(ImageFilter.GaussianBlur(radius=radius * 0.12))

    # —— 把阴影和苹果一起贴到主画布 ——
    paste_x = cx - lcx
    paste_y = cy - lcy
    canvas.paste(shadow_canvas, (paste_x, paste_y), shadow_canvas)
    canvas.paste(layer, (paste_x, paste_y), layer)

    # 返回果柄窝中心坐标，给 draw_stem / draw_leaf 定位用
    return (cx, cy - lobe_r + int(radius * 0.05))


def draw_stem(canvas: Image.Image, anchor: tuple[int, int], radius: int) -> tuple[int, int]:
    """从果柄窝往上画一截略弯的棕色果柄。返回柄顶坐标。"""
    cx, cy = anchor
    stem_w = max(8, int(radius * 0.09))
    stem_h = int(radius * 0.28)

    # 用一个 RGBA 层画带渐变的柄
    L = stem_h * 3
    layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lcx, lcy = L // 2, L // 2

    # 主柄：从底部向上，稍微向右倾
    x1 = lcx - stem_w // 2
    y1 = lcy - stem_h // 2
    x2 = lcx + stem_w // 2
    y2 = lcy + stem_h // 2
    d.rounded_rectangle((x1, y1, x2, y2), radius=stem_w // 2, fill=STEM_BROWN)
    # 右侧高光
    d.line(
        (lcx + stem_w // 4, y1 + stem_w // 2, lcx + stem_w // 4, y2 - stem_w // 2),
        fill=STEM_BROWN_HL,
        width=max(2, stem_w // 4),
    )

    # 轻微向右倾一点
    layer = layer.rotate(-8, resample=Image.BICUBIC)

    stem_top_y = cy - stem_h + int(stem_h * 0.05)
    paste_x = cx - lcx
    paste_y = stem_top_y + (stem_h // 2) - lcy
    canvas.paste(layer, (paste_x, paste_y), layer)

    return (cx + int(stem_w * 0.2), stem_top_y)


def draw_leaf(canvas: Image.Image, stem_top: tuple[int, int], radius: int) -> None:
    """
    在果柄顶部画一片向右上方翘起的嫩绿叶子。

    不走 sub-layer + rotate 的老路（那个在屏幕坐标里很难算对锚点），
    改用直接三角函数：把不旋转的叶子轮廓点（root 在 (0,0)，tip 在右侧）
    围绕 root 旋转一个角度后直接画在主画布上。叶根一定准确贴在 stem_top。
    """
    cx, cy = stem_top

    leaf_len = int(radius * 0.85)
    leaf_wid = int(radius * 0.34)
    # 屏幕坐标里 y 向下，想让叶尖往上翘 → 用负角度
    tilt_deg = -32
    tilt_rad = math.radians(tilt_deg)
    cos_t = math.cos(tilt_rad)
    sin_t = math.sin(tilt_rad)

    def place(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
        """围绕 (0,0) 旋转 tilt_deg，再平移到 (cx, cy)。"""
        out: list[tuple[float, float]] = []
        for (x, y) in points:
            rx = x * cos_t - y * sin_t
            ry = x * sin_t + y * cos_t
            out.append((cx + rx, cy + ry))
        return out

    # 不旋转的叶身：以 root 为原点的椭圆，tip 在正 x 方向
    # 参数方程：(leaf_len/2 * (1 - cos(t)), leaf_wid/2 * sin(t)),  t ∈ [0, 2π)
    # 这样 t=0 时 (0, 0) = root，t=π 时 (leaf_len, 0) = tip
    num = 48
    raw_outline: list[tuple[float, float]] = []
    for i in range(num):
        t = i * 2 * math.pi / num
        x = (leaf_len / 2) * (1 - math.cos(t))
        y = (leaf_wid / 2) * math.sin(t)
        raw_outline.append((x, y))

    outline = place(raw_outline)

    draw = ImageDraw.Draw(canvas)

    # 投影（叶子下方稍暗一圈）—— 画在主轮廓之下
    raw_shadow: list[tuple[float, float]] = []
    for (x, y) in raw_outline:
        raw_shadow.append((x, y + leaf_wid * 0.10))
    shadow_outline = place(raw_shadow)
    draw.polygon(shadow_outline, fill=LEAF_GREEN_DARK)

    # 主叶身
    draw.polygon(outline, fill=LEAF_GREEN)

    # 顶面高光：一个更瘦的椭圆，偏上
    raw_highlight: list[tuple[float, float]] = []
    for i in range(num):
        t = i * 2 * math.pi / num
        x = (leaf_len * 0.40) + (leaf_len * 0.30) * (1 - math.cos(t))
        y = -(leaf_wid * 0.06) + (leaf_wid * 0.14) * math.sin(t)
        raw_highlight.append((x, y))
    highlight_outline = place(raw_highlight)
    draw.polygon(highlight_outline, fill=LEAF_HL)

    # 叶脉：从靠近 root 到靠近 tip 的一条直线
    vein_pts = place([(leaf_len * 0.10, 0), (leaf_len * 0.92, 0)])
    draw.line(
        vein_pts,
        fill=LEAF_GREEN_DARK,
        width=max(2, int(leaf_wid * 0.10)),
    )


def main() -> None:
    # 背景
    img = fast_vertical_gradient(SIZE, SIZE, BG_TOP, BG_BOTTOM)

    # 苹果略微偏上
    apple_cx = SIZE // 2
    apple_cy = int(SIZE * 0.54)
    apple_radius = int(SIZE * 0.30)

    # 依次画：果身 → 柄 → 叶子
    stem_anchor = draw_apple_body(img, apple_cx, apple_cy, apple_radius)
    stem_top = draw_stem(img, stem_anchor, apple_radius)
    draw_leaf(img, stem_top, apple_radius)

    # iOS 1024 图标必须是 RGB 没透明度
    img = img.convert("RGB")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUTPUT, "PNG", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}  ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
