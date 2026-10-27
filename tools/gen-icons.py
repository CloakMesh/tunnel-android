#!/usr/bin/env python3
"""生成 CloakMesh Android 图标（盾形 + 网状节点），输出到白标资源目录。"""
import math, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "app/src/cloakmesh/res")

BG = (11, 22, 34)          # #0B1622 深蓝
GLYPH = (46, 230, 197)     # #2EE6C5 青绿
NODE = (245, 255, 253)     # 近白
SS = 4                     # 超采样倍数


def shield_points(cx, cy, w, h):
    """盾形轮廓：上宽下尖，顶部略平。"""
    return [
        (cx, cy - h * 0.50),
        (cx + w * 0.42, cy - h * 0.36),
        (cx + w * 0.50, cy - h * 0.10),
        (cx + w * 0.46, cy + h * 0.12),
        (cx + w * 0.26, cy + h * 0.36),
        (cx, cy + h * 0.50),
        (cx - w * 0.26, cy + h * 0.36),
        (cx - w * 0.46, cy + h * 0.12),
        (cx - w * 0.50, cy - h * 0.10),
        (cx - w * 0.42, cy - h * 0.36),
    ]


def draw_art(size, bg=True, rounded=True, circle=False, scale=1.0):
    """size: 输出像素；scale: 前景相对画布的比例（自适应图标留安全区）。"""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if bg:
        if circle:
            d.ellipse([0, 0, S - 1, S - 1], fill=BG)
        elif rounded:
            d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=BG)
        else:
            d.rectangle([0, 0, S - 1, S - 1], fill=BG)

    cx = cy = S / 2
    w = h = S * 0.56 * scale
    pts = shield_points(cx, cy, w, h)

    # 盾牌描边
    lw = max(2, int(S * 0.028 * scale))
    d.polygon(pts, fill=(0, 0, 0, 0))
    d.line(pts + [pts[0]], fill=GLYPH, width=lw, joint="curve")

    # 内部网格：3 个节点 + 连线
    nodes = [
        (cx, cy - h * 0.20),
        (cx - w * 0.20, cy + h * 0.14),
        (cx + w * 0.20, cy + h * 0.14),
    ]
    nw = max(1, int(S * 0.016 * scale))
    for i in range(len(nodes)):
        for j in range(i + 1, len(nodes)):
            d.line([nodes[i], nodes[j]], fill=GLYPH, width=nw)

    r = S * 0.045 * scale
    for (x, y) in nodes:
        d.ellipse([x - r, y - r, x + r, y + r], fill=NODE)

    return img.resize((size, size), Image.LANCZOS)


def save(img, rel):
    p = os.path.join(RES, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, "PNG", optimize=True)
    print("wrote", rel, img.size)


# 传统 mipmap（API < 26 用；minSdk 28 实际不会用到，但保留避免个别 OEM 回退缺图）
for dens, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    save(draw_art(px), f"mipmap-{dens}/ic_launcher.png")
    save(draw_art(px, circle=True), f"mipmap-{dens}/ic_launcher_round.png")

# 自适应图标前景（108dp，四周留安全区，故 glyph 缩到 0.6）
for dens, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
    save(draw_art(px, bg=False, scale=0.60), f"drawable-{dens}/cloakmesh_ic_foreground.png")

# 应用内 logo（dashboard 背景图，上游是 537x537 的 Z 图标）
save(draw_art(537, rounded=False), "drawable/appicon.png")

print("done")
