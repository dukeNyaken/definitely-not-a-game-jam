"""Картинка -> вход для image-to-3D: фигура на белом в квадратном кадре.

    python prep.py <картинка.png> [выход.png]
    python prep.py <сзади.png> --back-of <спереди.png>

Второй вариант для вида сзади (img_edit.py ... back): та же подготовка и
IoU отражённой маски с маской вида спереди. bake.py проецирует вид сзади
по его собственной рамке, но если силуэт не совпал (ниже ~0.85), поза
поехала, и на модель ляжет чужая рука.

Цвет фона берётся по углам кадра (промпт просит ровный серый фон, и углы —
единственное место, где фигуры точно нет). Фоном считается всё, что связано
с краем кадра и ближе к этому цвету, чем bg_tolerance: заливка от края, а не
порог по всему кадру — иначе серые места на самой фигуре (костюм того же
тона, что фон) стали бы дырами.
Hunyuan учили на объектах на белом и по центру, отсюда белый фон и поле.
Ещё пишет <имя>_fill.png: исходник, где фон и полупрозрачный край фигуры
залиты ближайшим цветом фигуры. С него bake.py берёт цвет: проекция на
краю силуэта иначе попадает в фон и даёт светлые полосы по бокам.
Печатает долю фигуры в кадре и её рамку — по ним видно, не обрезано ли что.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).parent
P = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["prep"]


def mask_of(rgb):
    """Маска фигуры. Фон — то, что дотягивается от краёв кадра по плавным местам,
    близким к цвету фона: мягкая тень на полу и затенённый фон у тела плавные и
    входят, а край фигуры резкий и останавливает рост. Замкнутые плавные пятна
    цвета фона (просветы между руками и телом, между ногами) крупнее
    enclosed_bg_frac кадра — тоже фон; дыры в фигуре заливаются только мелкие,
    иначе заливка возвращала эти просветы обратно."""
    h, w, _ = rgb.shape
    k = max(4, min(h, w) // 40)
    corners = np.concatenate([rgb[:k, :k], rgb[:k, -k:], rgb[-k:, :k], rgb[-k:, -k:]]).reshape(-1, 3)
    bg = np.median(corners, axis=0)
    f = rgb.astype(np.float32)
    dist = np.linalg.norm(f - bg, axis=2)
    lum = ndimage.gaussian_filter(f.mean(axis=2), 1.5)
    grad = np.hypot(ndimage.sobel(lum, 0), ndimage.sobel(lum, 1)) / 8.0
    # мягкий фон — это тень: темнее фона и почти без цвета; светлая одежда цвета
    # фона (льняная рубаха) сюда не попадает и держится резким краем, как раньше
    shade = (f.mean(axis=2) < bg.mean() - 3) & (f.max(axis=2) - f.min(axis=2) < P["bg_shade_chroma"])
    cand = (dist < P["bg_tolerance"]) | ((dist < P["bg_loose_tolerance"]) & (grad < P["bg_smooth_grad"]) & shade)
    lab, n = ndimage.label(cand)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    sizes = ndimage.sum(cand, lab, range(1, n + 1))
    big = np.nonzero(sizes > P["enclosed_bg_frac"] * cand.size)[0] + 1
    fg = ~np.isin(lab, np.union1d(edge[edge > 0], big))
    # одна крупнейшая связная фигура: отсекает пылинки и шум у края
    lab, n = ndimage.label(fg)
    if n > 1:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = lab == (1 + int(np.argmax(sizes)))
    holes, n = ndimage.label(~fg)
    if n:
        sizes = ndimage.sum(~fg, holes, range(1, n + 1))
        small = np.nonzero(sizes < P["enclosed_bg_frac"] * fg.size)[0] + 1
        fg |= np.isin(holes, small)
    return fg, bg


def prep(src, dst):
    rgb = np.asarray(Image.open(src).convert("RGB"))
    fg, bg = mask_of(rgb)
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    touches = [n for n, t in (("верх", y0 == 0), ("низ", y1 == rgb.shape[0]),
                              ("лево", x0 == 0), ("право", x1 == rgb.shape[1])) if t]

    rgba = np.dstack([rgb, (fg * 255).astype(np.uint8)])[y0:y1, x0:x1]
    side = int(max(y1 - y0, x1 - x0) / (1 - 2 * P["margin"]))
    canvas = Image.new("RGBA", (side, side), (255, 255, 255, 255))
    crop = Image.fromarray(rgba, "RGBA")
    canvas.alpha_composite(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    canvas.convert("RGB").resize((P["size"], P["size"]), Image.LANCZOS).save(dst)
    # маска рядом: ею же потом проверяется проекция текстуры
    Image.fromarray((fg * 255).astype(np.uint8)).save(Path(dst).with_suffix(".mask.png"))
    core = ndimage.binary_erosion(fg, iterations=P["fill_erode"])
    _, (iy, ix) = ndimage.distance_transform_edt(~core, return_indices=True)
    Image.fromarray(rgb[iy, ix]).save(Path(src).with_name(Path(src).stem + "_fill.png"))

    print(f"{Path(src).name}: фон {bg.round().astype(int).tolist()}, фигура {fg.mean():.1%} кадра, "
          f"рамка {x1 - x0}x{y1 - y0} точек" + (f"; КАСАЕТСЯ КРАЯ: {', '.join(touches)}" if touches else ""))
    return dst


def back_iou(back, front):
    """IoU масок внутри их рамок: сзади отражается по горизонтали, обе приводятся к одному размеру."""
    def crop(path, flip):
        m = np.asarray(Image.open(Path(path).with_name(Path(path).stem + "_prep.mask.png"))) > 127
        ys, xs = np.nonzero(m)
        m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        return np.asarray(Image.fromarray(m[:, ::-1] if flip else m).resize((256, 512), Image.NEAREST))
    a, b = crop(front, False), crop(back, True)
    return (a & b).sum() / (a | b).sum()


if __name__ == "__main__":
    src = Path(sys.argv[1])
    if "--back-of" in sys.argv:
        prep(src, src.with_name(src.stem + "_prep.png"))
        print(f"IoU с отражённым видом спереди: {back_iou(src, sys.argv[sys.argv.index('--back-of') + 1]):.3f}")
    else:
        prep(src, Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_name(src.stem + "_prep.png"))
