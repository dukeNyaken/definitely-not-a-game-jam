#!/usr/bin/env python3
"""Процедурные тайлящиеся текстуры 64×64 в гримдарк-палитре (только стандартная библиотека).

python3 tools/gen_textures.py
"""
import math
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
S = 64


# ---------------------------------------------------------------- PNG

def write_png(name, px, w=S, h=S):
    """px[y][x] = (r, g, b) или (r, g, b, a), компоненты 0..1."""
    os.makedirs(OUT, exist_ok=True)
    alpha = len(px[0][0]) == 4
    raw = bytearray()
    for row in px:
        raw.append(0)
        for p in row:
            raw += bytes(max(0, min(255, int(round(c * 255)))) for c in p)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6 if alpha else 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print("  ", name)


# ---------------------------------------------------------------- шум

def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(cell, seed):
    r = random.Random(seed)
    g = S // cell
    grid = [[r.random() for _ in range(g)] for _ in range(g)]
    out = [[0.0] * S for _ in range(S)]
    for y in range(S):
        gy = y / cell
        y0 = int(gy) % g
        y1 = (y0 + 1) % g
        fy = smooth(gy - int(gy))
        for x in range(S):
            gx = x / cell
            x0 = int(gx) % g
            x1 = (x0 + 1) % g
            fx = smooth(gx - int(gx))
            a = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * fx
            b = grid[y1][x0] + (grid[y1][x1] - grid[y1][x0]) * fx
            out[y][x] = a + (b - a) * fy
    return out


def fbm(seed, cells=(16, 8, 4, 2), weights=(0.5, 0.25, 0.15, 0.1)):
    layers = [value_noise(c, seed + i * 17) for i, c in enumerate(cells)]
    return [[sum(l[y][x] * wt for l, wt in zip(layers, weights)) for x in range(S)] for y in range(S)]


def wrap_d(a, b):
    d = abs(a - b)
    return min(d, S - d)


def voronoi(count, seed):
    """Возвращает (id ближайшей точки, d1, d2) для каждого пикселя."""
    r = random.Random(seed)
    pts = [(r.uniform(0, S), r.uniform(0, S)) for _ in range(count)]
    out = []
    for y in range(S):
        row = []
        for x in range(S):
            best = (1e9, -1)
            second = 1e9
            for i, (px, py) in enumerate(pts):
                d = math.hypot(wrap_d(x, px), wrap_d(y, py))
                if d < best[0]:
                    second = best[0]
                    best = (d, i)
                elif d < second:
                    second = d
            row.append((best[1], best[0], second))
        out.append(row)
    return out


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def scratch_lines(px, count, color, seed, length=(4, 12)):
    r = random.Random(seed)
    for _ in range(count):
        x, y = r.uniform(0, S), r.uniform(0, S)
        a = r.uniform(0, math.tau)
        L = r.randint(*length)
        for t in range(L):
            xi = int(x + math.cos(a) * t) % S
            yi = int(y + math.sin(a) * t) % S
            px[yi][xi] = lerp3(px[yi][xi], color, 0.6)


# ---------------------------------------------------------------- текстуры

def stone():
    """Брусчатка арены."""
    v = voronoi(22, 1)
    n = fbm(2)
    r = random.Random(3)
    tints = [r.uniform(0.92, 1.06) for _ in range(22)]
    base = (0.46, 0.42, 0.38)
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            i, d1, d2 = v[y][x]
            edge = d2 - d1
            k = tints[i] * (0.75 + 0.5 * n[y][x])
            c = shade(base, k)
            if edge < 1.4:
                c = shade(c, 0.62)
            elif edge < 2.4:
                c = shade(c, 0.84)
            row.append(c)
        px.append(row)
    write_png("stone", px)


def brick():
    """Каменная кладка: колонны, стены."""
    n = fbm(5)
    r = random.Random(6)
    px = []
    bh, bw = 16, 32
    tints = {}
    for y in range(S):
        row = []
        for x in range(S):
            ry = y // bh
            off = (bw // 2) * (ry % 2)
            rx = ((x + off) % S) // bw
            key = (rx, ry)
            if key not in tints:
                tints[key] = r.uniform(0.8, 1.15)
            lx = (x + off) % bw
            ly = y % bh
            c = shade((0.42, 0.39, 0.37), tints[key] * (0.7 + 0.6 * n[y][x]))
            if lx < 2 or ly < 2:
                c = shade(c, 0.4)
            row.append(c)
        px.append(row)
    write_png("brick", px)


def metal(name, base, rust_amount, seed):
    n = fbm(seed)
    rn = fbm(seed + 50, (8, 4, 2, 2))
    rust_c = (0.45, 0.22, 0.1)
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            k = 0.8 + 0.4 * n[y][x]
            c = shade(base, k)
            if rn[y][x] > 1.0 - rust_amount:
                t = min(1.0, (rn[y][x] - (1.0 - rust_amount)) * 4.0)
                c = lerp3(c, shade(rust_c, 0.7 + 0.6 * n[y][x]), t)
            row.append(c)
        px.append(row)
    scratch_lines(px, 26, shade(base, 1.9), seed + 9)
    write_png(name, px)


def leather():
    n = fbm(11, (8, 4, 2, 2), (0.4, 0.3, 0.2, 0.1))
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            c = shade((0.42, 0.27, 0.17), 0.7 + 0.55 * n[y][x])
            if (y % 32) in (6, 7) and (x // 3) % 2 == 0:
                c = (0.62, 0.5, 0.36)
            row.append(c)
        px.append(row)
    write_png("leather", px)


def cloth(name, base, holes, seed):
    n = fbm(seed)
    hn = fbm(seed + 3, (8, 4, 2, 2))
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            weave = 0.9 + 0.1 * ((x + y) % 2) - 0.08 * ((x // 2 + y // 2) % 2)
            c = shade(base, weave * (0.75 + 0.5 * n[y][x]))
            a = 1.0
            if holes and hn[y][x] > 0.68:
                a = 0.0
            elif holes and hn[y][x] > 0.63:
                c = shade(c, 0.5)
            row.append(c + (a,) if holes else c)
        px.append(row)
    write_png(name, px)


def skin():
    n = fbm(21, (16, 8, 4, 2), (0.45, 0.3, 0.15, 0.1))
    px = [[shade((0.8, 0.62, 0.52), 0.85 + 0.25 * n[y][x]) for x in range(S)] for y in range(S)]
    scratch_lines(px, 6, (0.55, 0.32, 0.3), 22, (6, 14))
    write_png("skin", px)


def bone():
    n = fbm(31)
    px = [[shade((0.86, 0.81, 0.68), 0.75 + 0.35 * n[y][x]) for x in range(S)] for y in range(S)]
    scratch_lines(px, 14, (0.35, 0.3, 0.22), 32, (5, 16))
    write_png("bone", px)


def wood():
    n = fbm(41, (16, 8, 4, 2))
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            grain = 0.5 + 0.5 * math.sin((x + n[y][x] * 18.0) * 0.8)
            c = shade((0.32, 0.22, 0.14), 0.7 + 0.3 * grain + 0.2 * n[y][x])
            if x % 16 == 0:
                c = shade(c, 0.45)
            row.append(c)
        px.append(row)
    write_png("wood", px)


def flesh():
    v = voronoi(14, 51)
    n = fbm(52)
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            i, d1, d2 = v[y][x]
            edge = d2 - d1
            c = shade((0.5, 0.18, 0.17), 0.7 + 0.6 * n[y][x])
            if edge < 1.5:
                c = (0.22, 0.05, 0.12)
            elif d1 < 2.2:
                c = shade(c, 1.35)
            row.append(c)
        px.append(row)
    write_png("flesh", px)


def gold():
    n = fbm(61)
    px = [[shade((0.66, 0.5, 0.24), 0.7 + 0.5 * n[y][x]) for x in range(S)] for y in range(S)]
    scratch_lines(px, 16, (0.95, 0.8, 0.45), 62)
    write_png("gold", px)


def dirt():
    n = fbm(71)
    m = fbm(72, (8, 4, 2, 2))
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            c = shade((0.3, 0.24, 0.19), 0.7 + 0.5 * n[y][x])
            if m[y][x] > 0.66:
                c = lerp3(c, (0.26, 0.08, 0.06), 0.6)
            row.append(c)
        px.append(row)
    write_png("dirt", px)


def blood():
    """Пятно крови с прозрачностью — для декалей на полу."""
    n = fbm(81, (8, 4, 2, 2))
    r = random.Random(82)
    blobs = [(32 + r.uniform(-6, 6), 32 + r.uniform(-6, 6), r.uniform(8, 16)) for _ in range(5)]
    drops = [(r.uniform(4, 60), r.uniform(4, 60), r.uniform(1.5, 3.5)) for _ in range(14)]
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            f = 0.0
            for bx, by, br in blobs:
                f = max(f, 1.0 - math.hypot(x - bx, y - by) / br)
            for bx, by, br in drops:
                f = max(f, 1.0 - math.hypot(x - bx, y - by) / br)
            f += (n[y][x] - 0.5) * 0.5
            a = 1.0 if f > 0.15 else 0.0
            c = shade((0.36, 0.04, 0.04), 0.7 + 0.5 * n[y][x])
            row.append(c + (a,))
        px.append(row)
    write_png("blood", px)


def fur():
    n = fbm(91, (16, 8, 4, 2))
    px = []
    for y in range(S):
        row = []
        for x in range(S):
            streak = 0.5 + 0.5 * math.sin(x * 1.7 + n[y][x] * 9.0)
            row.append(shade((0.2, 0.17, 0.15), 0.65 + 0.35 * streak + 0.2 * n[y][x]))
        px.append(row)
    write_png("fur", px)


if __name__ == "__main__":
    print("Textures:")
    stone()
    brick()
    metal("iron", (0.27, 0.27, 0.3), 0.12, 101)
    metal("rust", (0.3, 0.25, 0.22), 0.55, 111)
    leather()
    cloth("cloth", (0.3, 0.26, 0.23), False, 121)
    cloth("rags", (0.16, 0.14, 0.14), True, 131)
    skin()
    bone()
    wood()
    flesh()
    gold()
    dirt()
    blood()
    fur()
