"""Blender: сырая сетка Hunyuan + картинка -> лоу-поли glb с текстурой.

    blender -b --python bake.py -- <сырая.glb> <картинка.png> <выход.glb> <body|item> [картинка_сзади.png] [tris=N] [tex=N] [height=М] [sym=0]

1. Масштаб и место: рост из settings (у вещи — как есть), стопы на z=0, центр по X/Y.
2. Цвет на вершины подробной сетки: проекция картинки спереди (и сзади, если
   есть) по рамке силуэта, только для вершин, видимых с этой стороны (луч не
   упирается в саму сетку). Вес стороны — насколько грань к ней повёрнута.
   Невидимым ниоткуда вершинам цвет растекается от соседей.
3. Упрощение (collapse, симметрия по X) до бюджета треугольников.
4. UV smart project, запекание цвета подробной сетки на простую (Cycles,
   selected-to-active), текстура без сглаживания.
Печатает: треугольники до/после, размер текстуры, долю вершин без цвета и
IoU силуэта сетки с маской картинки (меньше ~0.9 — проекция съехала).
"""
import json
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from imgproj import load_rgba, project  # noqa: E402  (рядом лежащий модуль: Blender не кладёт папку скрипта в путь)
L = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["lowpoly"]
argv = sys.argv[sys.argv.index("--") + 1:]
POS = [a for a in argv if "=" not in a]
RAW, FRONT, OUT = (str(Path(a).resolve()) for a in POS[:3])
KIND = POS[3]
BACK = str(Path(POS[4]).resolve()) if len(POS) > 4 else None
# tris=, tex=, height= поверх бюджета из settings.json — их задаёт узел ComfyUI
B = {**L[KIND], **{k: float(v) if k == "height" else int(v) for k, v in (a.split("=", 1) for a in argv if "=" in a)}}


def import_raw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RAW)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = obs[0]
    for o in obs:
        o.select_set(True)
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)
    s = B["height"] / (hi[2] - lo[2]) if "height" in B else 1.0
    co = (co - [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]]) * s
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    # пересборка вокселями: сырая сетка неманифолдна, и упрощение на ней застревает
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = L["remesh_voxel_frac"] * max(ob.dimensions)
    bpy.ops.object.modifier_apply(modifier="remesh")
    return ob


def visible(ob, co, direction):
    """Видна ли вершина с бесконечно далёкой камеры в направлении direction."""
    bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    d = Vector(direction)
    eps = 1e-3
    return np.array([bvh.ray_cast(Vector(p) + d * eps, d)[0] is None for p in co])


def silhouette_iou(co, faces, mask, box, lo, hi):
    """IoU силуэта сетки спереди и маски картинки внутри рамки фигуры."""
    x0, x1, y0, y1 = box
    sub = mask[y0:y1, x0:x1]
    h, w = sub.shape
    canvas = np.zeros((h, w), bool)
    u = (co[:, 0] - lo[0]) / (hi[0] - lo[0]) * (w - 1)
    v = (hi[2] - co[:, 2]) / (hi[2] - lo[2]) * (h - 1)
    for f in faces:                  # заливка треугольников по их рамке и знакам барицентров
        a, b, c = f
        xs, ys = np.array([u[a], u[b], u[c]]), np.array([v[a], v[b], v[c]])
        bx0, bx1 = int(xs.min()), int(np.ceil(xs.max())) + 1
        by0, by1 = int(ys.min()), int(np.ceil(ys.max())) + 1
        gx, gy = np.meshgrid(np.arange(bx0, bx1), np.arange(by0, by1))
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-9:
            continue
        l1 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        l2 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
        inside = (l1 >= 0) & (l2 >= 0) & (l1 + l2 <= 1)
        canvas[gy[inside].clip(0, h - 1), gx[inside].clip(0, w - 1)] = True
    return (canvas & sub).sum() / max((canvas | sub).sum(), 1)


def paint_vertices(ob):
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    nrm = np.empty(n * 3); me.vertices.foreach_get("normal", nrm); nrm = nrm.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)

    rgb_f, mask_f, box_f = load_rgba(FRONT)
    col = np.zeros((n, 3)); wsum = np.zeros(n)
    vis_f = visible(ob, co, (0, -1, 0))
    w = np.clip(-nrm[:, 1], 0, 1) * vis_f + 1e-3 * vis_f      # 1e-3: грань боком всё же берёт цвет
    col += project(co, rgb_f, box_f, lo, hi, False) * w[:, None]; wsum += w
    if BACK:
        rgb_b, _, box_b = load_rgba(BACK)
        vis_b = visible(ob, co, (0, 1, 0))
        w = np.clip(nrm[:, 1], 0, 1) * vis_b + 1e-3 * vis_b
        col += project(co, rgb_b, box_b, lo, hi, True) * w[:, None]; wsum += w
    else:
        # без вида сзади спина берёт цвет того же места спереди — заглушка до картинки сзади
        vis_b = visible(ob, co, (0, 1, 0))
        w = np.clip(nrm[:, 1], 0, 1) * vis_b * 0.5
        col += project(co, rgb_f, box_f, lo, hi, False) * w[:, None]; wsum += w

    known = wsum > 0
    col[known] /= wsum[known, None]
    missing = (~known).mean()
    # растекание цвета на невидимые вершины по рёбрам
    ed = np.empty(len(me.edges) * 2, dtype=np.int64); me.edges.foreach_get("vertices", ed); ed = ed.reshape(-1, 2)
    for _ in range(200):
        if known.all():
            break
        acc = np.zeros((n, 3)); cnt = np.zeros(n)
        for a, b in ((0, 1), (1, 0)):
            src, dst = ed[:, a], ed[:, b]
            ok = known[src] & ~known[dst]
            np.add.at(acc, dst[ok], col[src[ok]]); np.add.at(cnt, dst[ok], 1)
        new = cnt > 0
        col[new] = acc[new] / cnt[new, None]
        known |= new

    attr = me.color_attributes.new("proj", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.hstack([col, np.ones((n, 1))]).ravel())
    return missing


def low_iou(low):
    """IoU силуэта простой сетки спереди с маской картинки — проверка и проекции, и упрощения."""
    me = low.data
    co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    me.calc_loop_triangles()
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tri)
    _, mask, box = load_rgba(FRONT)
    return silhouette_iou(co, tri.reshape(-1, 3), mask, box, co.min(0), co.max(0))


def decimate(src):
    low = src.copy()
    low.data = src.data.copy()
    low.name = "body" if KIND == "body" else "item"
    bpy.context.scene.collection.objects.link(low)
    tris0 = sum(len(p.vertices) - 2 for p in src.data.polygons)   # после пересборки грани четырёхугольные
    mod = low.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = B["tris"] / tris0
    # sym=0 — без симметрии: существо, снятое сбоку, по X идёт от морды к хвосту
    mod.use_symmetry = bool(B.get("sym", 1))
    mod.symmetry_axis = "X"
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.modifier_apply(modifier="dec")
    low.data.color_attributes.remove(low.data.color_attributes["proj"])
    return low


def _uv_area(f, uv):
    a = [lp[uv].uv for lp in f.loops]
    return abs(sum(a[i].x * a[i - 1].y - a[i - 1].x * a[i].y for i in range(len(a)))) / 2


def head_faces(low):
    """Грани выше head_from доли роста — голова (только у тела; у вещи пусто)."""
    me = low.data
    n = len(me.polygons)
    if "head_from" not in B:
        return np.zeros(n, bool)
    c = np.empty(n * 3); me.polygons.foreach_get("center", c)
    z = c.reshape(-1, 3)[:, 2]
    return z > B["head_from"] * B["height"]


def unwrap_and_bake(high, low):
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    head = head_faces(low)
    bpy.ops.object.mode_set(mode="EDIT")
    # голова и тело развёртываются порознь, чтобы острова не шли через шею,
    # потом острова головы увеличиваются и всё пакуется заново: при упаковке
    # соотношение размеров островов сохраняется, и голова получает больше точек
    for part in (~head, head) if head.any() else (None,):
        bm = bmesh.from_edit_mesh(low.data)
        for f in bm.faces:
            f.select = True if part is None else bool(part[f.index])
        bmesh.update_edit_mesh(low.data)
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=L["uv_island_margin"])
    if head.any():
        # каждая развёртка разложена на весь квадрат сама по себе — масштаб между
        # головой и телом потерян. Возвращаем одинаковую плотность (площадь UV
        # пропорциональна площади в 3D) и только потом увеличиваем голову.
        bm = bmesh.from_edit_mesh(low.data)
        uv = bm.loops.layers.uv.active
        a3 = np.array([f.calc_area() for f in bm.faces])
        auv = np.array([_uv_area(f, uv) for f in bm.faces])
        for part, k in ((~head, 1.0), (head, B["head_texel_scale"])):
            s = k * np.sqrt(a3[part].sum() / auv[part].sum())
            for f in bm.faces:
                if part[f.index]:
                    for lp in f.loops:
                        lp[uv].uv *= s
        bmesh.update_edit_mesh(low.data)
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(margin=L["uv_island_margin"], rotate=True)
    bm = bmesh.from_edit_mesh(low.data)
    uv = bm.loops.layers.uv.active
    areas = np.array([_uv_area(f, uv) for f in bm.faces])
    head_share = areas[head].sum() / areas.sum() if head.any() else 0.0
    used = areas.sum()
    bpy.ops.object.mode_set(mode="OBJECT")

    size = B["tex"]
    img = bpy.data.images.new(low.name + "_albedo", size, size)
    mat = bpy.data.materials.new(low.name)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    nt.nodes.active = tex
    low.data.materials.clear()
    low.data.materials.append(mat)

    hm = bpy.data.materials.new("proj")
    hm.use_nodes = True
    hn = hm.node_tree
    for nd in list(hn.nodes):
        hn.nodes.remove(nd)
    attr = hn.nodes.new("ShaderNodeAttribute"); attr.attribute_name = "proj"
    emit = hn.nodes.new("ShaderNodeEmission")
    out = hn.nodes.new("ShaderNodeOutputMaterial")
    hn.links.new(attr.outputs["Color"], emit.inputs["Color"])
    hn.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    high.data.materials.clear()
    high.data.materials.append(hm)

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.device = "CPU"
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    # выдавливание и луч — доля размера модели: простая сетка местами лежит внутри подробной
    ext = 0.02 * max(low.dimensions)
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=ext,
                        max_ray_distance=ext * 2, margin=L["bake_margin"])
    # картинка в sRGB: запечённое — линейные значения цвета, перевод делает сохранение
    png = str(Path(OUT).with_suffix(".png"))
    img.filepath_raw = png
    img.file_format = "PNG"
    img.save()
    return png, head_share, used


def main():
    high = import_raw()
    tris_raw = sum(len(p.vertices) - 2 for p in high.data.polygons)   # после пересборки вокселями
    missing = paint_vertices(high)
    low = decimate(high)
    iou = low_iou(low)
    tris_low = sum(len(p.vertices) - 2 for p in low.data.polygons)
    png, head_share, used = unwrap_and_bake(high, low)
    bpy.data.objects.remove(high)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format="GLB",
                              export_image_format="AUTO", export_apply=True)
    d = low.dimensions
    print(f"BAKE {Path(OUT).name}: {tris_raw} -> {tris_low} треугольников; текстура {B['tex']}x{B['tex']} ({Path(png).name}); "
          f"атлас занят на {used:.0%}, голова — {head_share:.0%} занятого; "
          f"размер {d.x:.2f} x {d.y:.2f} x {d.z:.2f} м; без цвета до растекания {missing:.1%}; IoU силуэта {iou:.3f}")


main()
