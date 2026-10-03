"""Картинки после prep.py и их проекция на сетку — общее для bake.py и dress.py (Blender).

Проекция ортогональная: рамка силуэта на картинке совмещается с рамкой сетки
(X — ширина, Z — высота). Вид спереди смотрит в +Y (право картинки — +X), вид
сзади — в -Y (право картинки — -X).
"""
from pathlib import Path

import bpy
import numpy as np


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def load_rgba(path, linear=True):
    """Картинка с залитым фоном и маска фигуры — обе пишет prep.py рядом с исходником.

    Цвет переводится в линейный: запекание пишет линейные значения, а PNG
    сохраняется в sRGB — без перевода всё светлеет (тёмный костюм выходил светло-серым).
    linear=False — значения как в файле: для текстуры, которая сама идёт в модель.
    """
    img = bpy.data.images.load(str(Path(path).with_name(Path(path).stem + "_fill.png")))
    w, h = img.size
    rgb = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]   # строка 0 — верх
    if linear and img.colorspace_settings.name == "sRGB":
        rgb = srgb_to_linear(rgb)
    mask_path = Path(path).with_name(Path(path).stem + "_prep.mask.png")
    m = bpy.data.images.load(str(mask_path))
    mask = np.array(m.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, 0] > 0.5
    ys, xs = np.nonzero(mask)
    return rgb, mask, (xs.min(), xs.max() + 1, ys.min(), ys.max() + 1)


def project(co, rgb, box, lo, hi, mirror):
    """Цвет точки картинки, куда попадает вершина при совмещении рамок силуэта."""
    x0, x1, y0, y1 = box
    u = (co[:, 0] - lo[0]) / (hi[0] - lo[0])
    if mirror:                       # вид сзади: право картинки — это -X
        u = 1 - u
    v = (hi[2] - co[:, 2]) / (hi[2] - lo[2])
    px = np.clip((x0 + u * (x1 - x0)).astype(int), 0, rgb.shape[1] - 1)
    py = np.clip((y0 + v * (y1 - y0)).astype(int), 0, rgb.shape[0] - 1)
    return rgb[py, px]
