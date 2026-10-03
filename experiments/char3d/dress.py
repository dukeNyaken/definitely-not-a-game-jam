"""Blender: тело со скелетом + лоу-поли вещи -> одетый персонаж одним glb.

    blender -b --python dress.py -- <тело.glb> <выход.glb> <слот>=<вещь.glb> ... [variant=<комплект>]

Правила посадки — data/equipment.json (+ поправки комплекта variants). Размеры —
доли роста тела или метры, умноженные на рост / ref_height: одни и те же вещи
садятся и на героя, и на босса. Каждая вещь — отдельная сетка
item_<слот> (у парных — item_<слот>_L и _R) на том же скелете, что и тело.
Поэтому ретаргет в Godot обработает вещи так же, как тело, а «надеть/снять»
там — показать/спрятать сетку. Действия тела (если есть) сохраняются.
Печатает по каждой вещи: треугольники, масштаб, размер и (у wrap) долю
вершин области тела, накрытых вещью: луч из вершины наружу по нормали
упирается в вещь ближе 10 см. Меньше ~0.8 — вещь мала, съехала или тело проступает.
Части тела под вещами (hide) вырезаются в сетки hide_<слот>: игра прячет их,
пока вещь надета, — тело не может проступить сквозь неё ни в одной позе.
Вещь из нескольких частей (part_of: поножи — часть доспеха) даёт сетки
item_<слот>__<часть>: в игре это один слот. Облегающее (fit shell: кираса,
поножи) — не сетка Hunyuan, а оболочка из самого тела, раздутая на отступ и
развёрнутая прямо на картинки вещи спереди и сзади: сидит без зазоров, гнётся
с телом, тело сквозь неё не видно. Подложка (underlay) — такая же оболочка под
вещью из Hunyuan: в её дырах видна она, а не кожа.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import imgproj  # noqa: E402  (рядом лежащий модуль: Blender не кладёт папку скрипта в путь)

_EQ = json.loads((HERE / "data" / "equipment.json").read_text(encoding="utf-8"))
argv = sys.argv[sys.argv.index("--") + 1:]
BODY, OUT = str(Path(argv[0]).resolve()), str(Path(argv[1]).resolve())
OPT = dict(a.split("=", 1) for a in argv[2:] if a.startswith("variant="))
ITEMS = [(a.split("=", 1)[0], str(Path(a.split("=", 1)[1]).resolve())) for a in argv[2:] if not a.startswith("variant=")]
VARIANT = OPT.get("variant", "")
EQ = {slot: {**rule, **_EQ["variants"].get(VARIANT, {}).get(slot, {})} for slot, rule in _EQ["slots"].items()}
K = 1.0          # рост тела / ref_height — множитель для всех размеров в метрах (задаётся в main)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def load_body():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    new = import_glb(BODY)
    arm = next(o for o in new if o.type == "ARMATURE")
    body = next(o for o in new if o.type == "MESH" and o.parent == arm and
                not any(c.name == "glTF_not_exported" for c in o.users_collection))
    arm.data.pose_position = "REST"            # посадка — по позе покоя
    bpy.context.view_layer.update()
    return arm, body


def verts(ob):
    co = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    m = np.array(ob.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


def region(body, bones, frame=None):
    """Вершины тела с весом >= 0.5 у костей region (в мире или в повёрнутой системе frame)."""
    idx = {body.vertex_groups[b].index for b in bones if b in body.vertex_groups}
    sel = [v.index for v in body.data.vertices if any(g.group in idx and g.weight >= 0.5 for g in v.groups)]
    p = verts(body)[sel]
    if frame is not None:
        p = p @ np.array(frame)          # строки на матрицу = координаты в базисе frame
    return p


def bone_world(arm, name):
    b = arm.data.bones[name]
    return arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local


def rot_down_to(d):
    """Поворот, переводящий -Z вещи в направление d (вещь «низом по кости»)."""
    return Vector((0, 0, -1)).rotation_difference(d.normalized()).to_matrix()


def place(item, M):
    item.matrix_world = M @ item.matrix_world
    bpy.context.view_layer.objects.active = item
    for o in bpy.context.selected_objects:
        o.select_set(False)
    item.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def flatten(item, frac):
    """Сжимает вещь по глубине (Y) до frac её высоты, вокруг середины."""
    p = verts(item)
    lo, hi = p.min(0), p.max(0)
    k = min(1.0, frac * (hi[2] - lo[2]) / max(hi[1] - lo[1], 1e-6))
    c = (lo + hi) / 2
    place(item, Matrix.Translation(Vector(c)) @ Matrix.Diagonal((1, k, 1, 1)) @ Matrix.Translation(-Vector(c)))
    return k


def fit(item, slot, arm, body):
    r = EQ[slot]
    flat = flatten(item, r["flatten"]) if "flatten" in r else 1.0
    p = verts(item)
    ilo, ihi = p.min(0), p.max(0)
    ic = (ilo + ihi) / 2
    report = {}
    if r["fit"] == "wrap":
        R = Matrix.Identity(3)
        if r.get("frame") == "bone":
            h, t = bone_world(arm, r["bone"])
            R = rot_down_to(t - h)
        reg = region(body, r["region"], R)
        rlo, rhi = reg.min(0), reg.max(0)
        rhi[2] += r.get("extend_up", 0.0) * K
        ratios = {"width": (rhi[0] - rlo[0]) / (ihi[0] - ilo[0]), "depth": (rhi[1] - rlo[1]) / (ihi[1] - ilo[1]),
                  "height": (rhi[2] - rlo[2]) / (ihi[2] - ilo[2])}
        # по умолчанию — больший из размеров (вещь накрывает область в обе стороны);
        # сапог — по длине стопы: у сапога из Hunyuan длина/ширина 2.4 против 1.3 у стопы,
        # и по ширине он выходил 0.7 м в длину; ширину доберёт послойное расширение
        s = r["scale"] * (ratios[r["scale_by"]] if "scale_by" in r else max(ratios.values()))
        rc = (rlo + rhi) / 2
        z = {"top": rhi[2] - s * (ihi[2] - ic[2]), "bottom": rlo[2] + s * (ic[2] - ilo[2]),
             "center": rc[2]}[r["anchor"]] + r.get("lift", 0.0) * K
        target = Vector((rc[0], rc[1], z))
        # в системе frame: сдвиг центра вещи в target и масштаб; потом поворот frame в мир
        M = R.to_4x4() @ Matrix.Translation(target) @ Matrix.Scale(s, 4) @ Matrix.Translation(-Vector(ic))
        place(item, M)
        report = {"масштаб": round(s, 3)}
        if r.get("align_front"):
            # перед вещи — к самому переднему месту области (носок): кончики пальцев
            # весят на кости меньше 0.5, в область не входят и торчали из сапога
            idx = {body.vertex_groups[b].index for b in r["region"] if b in body.vertex_groups}
            tip = min(v.co.y for v in body.data.vertices if any(g.group in idx and g.weight > 0.05 for g in v.groups))
            dy = (tip - r["align_front"] * K) - verts(item)[:, 1].min()
            place(item, Matrix.Translation(Vector((0, dy, 0))))
            report["сдвиг к носку"] = f"{dy * 100:+.0f} см"
    elif r["fit"] == "hold":
        s = r["length_frac"] * K * _EQ["ref_height"] / (ihi[2] - ilo[2])
        grip = Vector((ic[0], ic[1], ilo[2] + r["grip"] * (ihi[2] - ilo[2])))
        h, t = bone_world(arm, r["bone"])
        palm = (h + t) / 2
        # плашмя к бокам (Rz 90), клинок вперёд (-Y): Rx 90 переводит +Z в -Y
        rot = Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Rotation(math.radians(90), 4, "Z")
        M = Matrix.Translation(palm) @ rot @ Matrix.Scale(s, 4) @ Matrix.Translation(-grip)
        place(item, M)
        report = {"масштаб": round(s, 3), "длина": f"{r['length_frac'] * K * _EQ['ref_height']:.2f} м"}
    elif r["fit"] == "strap":
        s = r["height_frac"] * K * _EQ["ref_height"] / (ihi[2] - ilo[2])
        h, t = bone_world(arm, r["bone"])
        d = (t - h).normalized()
        side = Vector((1 if h.x > 0 else -1, 0, 0))
        out = (side - d * side.dot(d)).normalized()          # наружу от тела, поперёк предплечья
        # оси вещи: длинная (+Z) — к локтю вдоль предплечья, лицо (-Y) — наружу
        z_ax, y_ax = -d, -out
        rot = Matrix((y_ax.cross(z_ax), y_ax, z_ax)).transposed().to_4x4()
        # вынос: толщина предплечья (дальняя от оси кости вершина) + зазор + полтолщины щита
        reg = region(body, [r["bone"]])
        rel = reg - np.array(h)
        dn = np.array(d)
        radial = rel - np.outer(rel @ dn, dn)
        arm_r = float(np.linalg.norm(radial, axis=1).max()) if len(reg) else 0.06
        off = arm_r + r["gap"] * K + s * (ihi[1] - ilo[1]) / 2
        pos = (h + t) / 2 + out * off
        M = Matrix.Translation(pos) @ rot @ Matrix.Scale(s, 4) @ Matrix.Translation(-Vector(ic))
        place(item, M)
        report = {"масштаб": round(s, 3), "вынос от кости": f"{off:.2f} м (рука {arm_r:.2f})", "сжат по глубине": f"x{flat:.2f}"}
    elif r["fit"] == "chest":
        s = r["size_frac"] * K * _EQ["ref_height"] / max(ihi - ilo)
        _, neck = bone_world(arm, r["bone"])
        z = neck.z - r["drop"] * K
        bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
        hit = bvh.ray_cast(Vector((0, -5, z)), Vector((0, 1, 0)))[0]
        y = (hit.y if hit else neck.y) - s * (ihi[1] - ilo[1]) / 2 - 0.005
        M = Matrix.Translation(Vector((0, y, z))) @ Matrix.Scale(s, 4) @ Matrix.Translation(-Vector(ic))
        place(item, M)
        report = {"масштаб": round(s, 3)}
    return report


def widen(item, body, limit=0.05, k_max=1.6, k_max_y=None, bins=10):
    """Раздвигает вещь по горизонтали послойно и отдельно по ширине (X) и длине (Y):
    по высоте вещь режется на bins слоёв; в слое множитель по X ищется по вершинам,
    смотрящим вбок, по Y — смотрящим вперёд/назад, пока их внутри тела не останется
    меньше limit; между слоями — плавно. Толщина стенки сохраняется. Зазор до тела
    даёт потом push_out: если требовать его здесь, вершины, законно лежащие у тела
    (подошва сапога под стопой), раздували вещь до предела.
    Раньше вещь раздвигалась целиком и одинаково: голенище у́же икры — и сапог
    вместе со стопой вырастал до 0.7 м в длину."""
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    co0 = np.array([v.co for v in item.data.vertices])
    nrm = np.array([v.normal for v in item.data.vertices])
    z0, z1 = co0[:, 2].min(), co0[:, 2].max()
    edges = np.linspace(z0, z1 + 1e-6, bins + 1)
    mids = (edges[:-1] + edges[1:]) / 2
    which = np.clip(np.searchsorted(edges, co0[:, 2], side="right") - 1, 0, bins - 1)
    ks = np.ones((bins, 2))
    centers = np.zeros((bins, 2))

    def inside(i, c, kx, ky):
        pt = Vector((c[0] + (co0[i, 0] - c[0]) * kx, c[1] + (co0[i, 1] - c[1]) * ky, co0[i, 2]))
        loc, n, _, _ = bvh.find_nearest(pt)
        return loc is not None and (pt - loc).dot(n) < 0.0

    for b in range(bins):
        sel = which == b
        if not sel.any():
            continue
        c = co0[sel, :2].mean(0)
        centers[b] = c
        out = sel & (np.einsum("ij,ij->i", nrm[:, :2], co0[:, :2] - c) > 0)   # смотрят от оси слоя наружу
        side = out & (np.abs(nrm[:, 0]) >= np.abs(nrm[:, 1]))
        front = out & (np.abs(nrm[:, 0]) < np.abs(nrm[:, 1]))
        for axis, group in ((0, side), (1, front)):
            k = 1.0
            top = k_max if axis == 0 or k_max_y is None else k_max_y
            while k <= top and group.any():
                kk = (k, 1.0) if axis == 0 else (1.0, k)
                bad = sum(inside(i, c, *kk) for i in np.nonzero(group)[0])
                if bad / group.sum() < limit:
                    break
                k += 0.02
            ks[b, axis] = min(k, top)
    filled = [b for b in range(bins) if (which == b).any()]
    for b in range(bins):                      # пустые слои — центр соседнего
        if b not in filled:
            centers[b] = centers[min(filled, key=lambda f: abs(f - b))]
    kx = np.interp(co0[:, 2], mids, ks[:, 0])
    ky = np.interp(co0[:, 2], mids, ks[:, 1])
    cx = np.interp(co0[:, 2], mids, centers[:, 0])
    cy = np.interp(co0[:, 2], mids, centers[:, 1])
    co = co0.copy()
    co[:, 0] = cx + (co0[:, 0] - cx) * kx
    co[:, 1] = cy + (co0[:, 1] - cy) * ky
    for v, c in zip(item.data.vertices, co):
        v.co = c
    item.data.update()
    return ks


def push_out(item, body, gap):
    """Вершины вещи внутри тела или ближе gap к нему — наружу по нормали тела."""
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    moved = 0
    for v in item.data.vertices:
        loc, nrm, _, _ = bvh.find_nearest(v.co)
        if loc is not None and (v.co - loc).dot(nrm) < gap:
            v.co = loc + nrm * gap
            moved += 1
    item.data.update()
    return moved / len(item.data.vertices)


def coverage(item, body, bones):
    """Доля вершин тела в области, у которых вещь лежит снаружи ближе 10 см."""
    bvh = BVHTree.FromObject(item, bpy.context.evaluated_depsgraph_get())
    idx = {body.vertex_groups[b].index for b in bones if b in body.vertex_groups}
    vs = [v for v in body.data.vertices if any(g.group in idx and g.weight >= 0.5 for g in v.groups)]
    hit = sum(1 for v in vs if bvh.ray_cast(v.co + v.normal * 1e-4, v.normal, 0.1)[0] is not None)
    return hit / max(len(vs), 1)


def skin(item, slot, arm, body, bone):
    for vg in list(item.vertex_groups):
        item.vertex_groups.remove(vg)
    if EQ[slot]["skin"] == "rigid":
        vg = item.vertex_groups.new(name=bone)
        vg.add(range(len(item.data.vertices)), 1.0, "REPLACE")
    else:
        for g in body.vertex_groups:
            item.vertex_groups.new(name=g.name)
        dt = item.modifiers.new("dt", "DATA_TRANSFER")
        dt.object = body
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        bpy.context.view_layer.objects.active = item
        bpy.ops.object.modifier_apply(modifier="dt")
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    mod = item.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    item.parent = arm
    item.matrix_parent_inverse = arm.matrix_world.inverted()


def mirror(item, slot):
    m = item.copy()
    m.data = item.data.copy()
    bpy.context.scene.collection.objects.link(m)
    m.data.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
    bm = bmesh.new()
    bm.from_mesh(m.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)       # отражение выворачивает грани
    bm.to_mesh(m.data)
    bm.free()
    item.name, m.name = f"{item.name}_L", f"{item.name}_R"
    return m


def covered_faces(body, items, ray):
    """Индексы граней тела, у которых луч из каждой вершины наружу по нормали упирается в вещь ближе ray."""
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(o, dg) for o in items]
    me = body.data
    hit = np.zeros(len(me.vertices), bool)
    for v in me.vertices:
        o = v.co + v.normal * 1e-4
        hit[v.index] = any(t.ray_cast(o, v.normal, ray)[0] is not None for t in trees)
    return {f.index for f in me.polygons if all(hit[i] for i in f.vertices)}


def bone_faces(body, bones, min_weight=0.5):
    """Грани, все вершины которых весят на этих костях (в сумме) не меньше min_weight (вся стопа, вся кисть)."""
    idx = {body.vertex_groups[b].index for b in bones if b in body.vertex_groups}
    on = {v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in idx) >= min_weight}
    return {f.index for f in body.data.polygons if all(i in on for i in f.vertices)}


def split_hidden(body, faces_by_slot):
    """Вырезает грани тела в отдельные сетки hide_<слот> с теми же весами, UV и материалом."""
    taken = set()
    out = []
    for slot, faces in faces_by_slot.items():
        faces = faces - taken
        taken |= faces
        if not faces:
            continue
        part = body.copy()
        part.data = body.data.copy()
        part.name = part.data.name = f"hide_{slot}"
        bpy.context.scene.collection.objects.link(part)
        bm = bmesh.new()
        bm.from_mesh(part.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in faces], context="FACES")
        bm.to_mesh(part.data)
        bm.free()
        out.append((slot, len(faces)))
    if taken:
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.faces[i] for i in taken], context="FACES")
        bm.to_mesh(body.data)
        bm.free()
    return out


def game_name(slot):
    """Имя слота в игре: часть вещи (поножи доспеха) — <слот>__<часть>, игра берёт до «__»."""
    r = EQ[slot]
    return f"{r['part_of']}__{r['part']}" if "part_of" in r else slot


def load_item(path, slot):
    new = import_glb(path)
    obs = [o for o in new if o.type == "MESH"]
    for o in new:
        if o not in obs:
            bpy.data.objects.remove(o)
    item = obs[0]
    item.parent = None
    item.name = f"item_{game_name(slot)}"
    item.data.name = item.name
    return item


def shell_faces(body, rule, arm):
    """Грани тела под оболочкой: на костях rule.bones (сумма весов >= min_weight) или пояс zone."""
    if "zone" not in rule:
        return bone_faces(body, rule["bones"], rule.get("min_weight", 0.5))
    # пояс по высоте между началами двух костей, кроме граней рук и головы: по весам
    # живот не отбирался — туда при расчёте весов затекает бедро, и подложка шла дырами
    zn = rule["zone"]
    z0 = bone_world(arm, zn["from"])[0].z - zn.get("margin", 0.0) * K
    z1 = bone_world(arm, zn["to"])[0].z + zn.get("margin_top", zn.get("margin", 0.0)) * K
    idx = {body.vertex_groups[b].index for b in zn["exclude"] if b in body.vertex_groups}
    off_limits = {v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in idx) >= 0.5}
    mw = body.matrix_world
    # ширина: не дальше от оси тела, чем начало кости half_width (плечевой сустав).
    # Руки отсекаются так, а не по весам: у коренастого тела веса рук растекаются на
    # широчайшие и грудь, и на спине под кирасой оставалась кожа
    hw = zn.get("half_width")
    x_max = abs(bone_world(arm, hw["bone"])[0].x) + hw.get("margin", 0.0) * K if hw else math.inf
    faces = {f.index for f in body.data.polygons
             if z0 <= (mw @ f.center).z <= z1 and abs((mw @ f.center).x) <= x_max
             and not any(i in off_limits for i in f.vertices)}
    if "caps" in zn:
        # наплечники: грани вокруг начала костей caps.bones (плечевой сустав) — без них
        # плечи под кирасой оставались голыми, а наплечники с картинки сжимались на торс
        cp = zn["caps"]
        heads = [bone_world(arm, b)[0] for b in cp["bones"]]
        r = cp["radius"] * K
        idx = {body.vertex_groups[b].index for b in cp.get("exclude", []) if b in body.vertex_groups}
        neck = {v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in idx) >= 0.5}
        faces |= {f.index for f in body.data.polygons if any(((mw @ f.center) - h).length < r for h in heads)
                  and not any(i in neck for i in f.vertices)}
    return faces


def make_shell(body, faces, offset, name):
    """Копия граней тела, раздутая на offset по нормали. Веса и привязка к скелету —
    как у тела (это его копия), поэтому сидит и гнётся без зазоров."""
    shell = body.copy()
    shell.data = body.data.copy()
    shell.name = shell.data.name = name
    bpy.context.scene.collection.objects.link(shell)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in faces], context="FACES")
    # glTF режет тело по швам развёртки: без сшивки края островов раздувались по разным
    # нормалям (щели в оболочке), а развёртка оболочки рассыпалась на островки в 1-2 грани
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    bm.to_mesh(shell.data)
    bm.free()
    return shell


def _resize(rgb, w, h):
    """Уменьшение картинки (строка 0 — верх) усреднением по клеткам."""
    ys = np.linspace(0, rgb.shape[0], h + 1).astype(int)
    xs = np.linspace(0, rgb.shape[1], w + 1).astype(int)
    out = np.empty((h, w, 3))
    for j in range(h):
        for i in range(w):
            out[j, i] = rgb[ys[j]:max(ys[j + 1], ys[j] + 1), xs[i]:max(xs[i + 1], xs[i] + 1)].mean((0, 1))
    return out


def image_shell(shell, folder, mirror_x, tex_h):
    """Развёртка оболочки прямо на картинки вещи (front/back после prep.py в folder): грань,
    смотрящая вперёд, ложится ортогональной проекцией на вид спереди (левая часть
    текстуры), назад — на вид сзади (правая). Рамка силуэта картинки — на рамку оболочки.
    Текстура — сами картинки, обрезанные по силуэту, высотой tex_h: без запекания и без
    мелких островов развёртки (с ними рисунок рассыпался в шум). mirror_x — оболочка из
    двух половин (обе ноги): у каждой своя рамка, половина на -X видит картинку
    отражённой (одна поножь на картинке — обе на теле)."""
    views = []
    for side in ("front", "back"):
        f = folder / f"{side}.png"
        if not Path(str(f).replace(".png", "_fill.png")).exists():
            f = folder / "front.png"                 # нет вида сзади — спина как перед
        rgb, _, (x0, x1, y0, y1) = imgproj.load_rgba(f, linear=False)
        crop = rgb[y0:y1, x0:x1]
        # ширина кратна 4: сжатие текстур в Godot идёт блоками 4x4
        w = max(4, 4 * round(tex_h * crop.shape[1] / crop.shape[0] / 4))
        views.append(_resize(crop, w, tex_h))
    atlas = np.hstack(views)                        # строка 0 — верх
    W = atlas.shape[1]
    img = bpy.data.images.new(shell.name + "_tex", W, tex_h)
    img.pixels.foreach_set(np.dstack([atlas[::-1], np.ones((tex_h, W))]).ravel().astype(np.float32))
    img.pack()

    me = shell.data
    mw = shell.matrix_world
    co = verts(shell)
    halves = [co[:, 0] >= 0, co[:, 0] < 0] if mirror_x else [np.ones(len(co), bool)]
    boxes = [(co[h].min(0), co[h].max(0)) if h.any() else (co.min(0), co.max(0)) for h in halves]
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uv = me.uv_layers.new(name="UVMap").data
    rot = mw.to_3x3()
    offs = [0, views[0].shape[1]]
    for f in me.polygons:
        n = rot @ f.normal
        back = n.y > 0
        c = mw @ f.center
        half = 1 if mirror_x and c.x < 0 else 0
        lo, hi = boxes[half]
        flip = (half == 1) != back                  # вид сзади и половина на -X — зеркально
        vw = views[back].shape[1]
        for li in f.loop_indices:
            p = co[me.loops[li].vertex_index]
            u = np.clip((p[0] - lo[0]) / (hi[0] - lo[0]), 0, 1)
            u = 1 - u if flip else u
            u = 0.5 / vw + u * (1 - 1 / vw)        # полпикселя от края — без затекания соседнего вида
            v = np.clip((p[2] - lo[2]) / (hi[2] - lo[2]), 0, 1)
            uv[li].uv = ((offs[back] + u * vw) / W, v)
    _textured(shell, img)
    return f"текстура {W}x{tex_h} (виды спереди и сзади)"


def _textured(ob, img):
    """Один материал: текстура img без сглаживания, как у остальных сеток модели."""
    mat = bpy.data.materials.new(ob.name)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    mat.node_tree.nodes.active = tex
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def main():
    global K
    arm, body = load_body()
    zs = verts(body)[:, 2]
    height = float(zs.max() - zs.min())
    K = height / _EQ["ref_height"]
    lines = [f"рост тела {height:.2f} м (размеры x{K:.2f}), комплект {VARIANT or '-'}"]
    hide = {}
    # оболочки (fit shell, подложки) строятся после всех вещей: из граней тела, ещё не
    # спрятанных под другими вещами — поножи кончаются там, где начинается сапог
    shells = []
    for slot, path in ITEMS:
        name = game_name(slot)
        if EQ[slot]["fit"] == "shell":
            shells.append((slot, name, EQ[slot], Path(path).parent, f"item_{name}"))
            continue
        item = load_item(path, slot)
        rep = fit(item, slot, arm, body)
        if EQ[slot].get("skin") == "transfer" and "push" in EQ[slot]:
            ks = widen(item, body, k_max=EQ[slot].get("widen_max", 1.6), k_max_y=EQ[slot].get("widen_max_y"))
            rep["расширено"] = f"в ширину x{ks[:, 0].min():.2f}..{ks[:, 0].max():.2f}, в длину x{ks[:, 1].min():.2f}..{ks[:, 1].max():.2f}"
        if "push" in EQ[slot]:
            rep["сдвинуто наружу"] = f"{push_out(item, body, EQ[slot]['push'] * K):.0%} вершин"
        if EQ[slot]["fit"] == "wrap":
            rep["накрывает"] = f"{coverage(item, body, EQ[slot]['region']):.0%}"
        bone = EQ[slot]["bone"]
        parts = [(item, bone)]
        if EQ[slot].get("pair"):
            other = mirror(item, slot)
            parts.append((other, bone.replace("Left", "Right")))
        if EQ[slot].get("hide"):
            hide[name] = covered_faces(body, [o for o, _ in parts], EQ[slot]["hide_ray"] * K)
            if "hide_bones" in EQ[slot]:
                hide[name] |= bone_faces(body, EQ[slot]["hide_bones"])
        if "underlay" in EQ[slot]:
            shells.append((slot, name, EQ[slot]["underlay"], Path(path).parent, f"item_{name}_under"))
        for ob, b in parts:
            skin(ob, slot, arm, body, b)
        d = item.dimensions
        tris = sum(len(p.vertices) - 2 for p in item.data.polygons) * len(parts)
        lines.append(f"{slot}: {tris} треуг., {d.x:.2f}x{d.y:.2f}x{d.z:.2f} м, кость {bone}, "
                     f"{EQ[slot]['skin']}" + "".join(f", {k} {v}" for k, v in rep.items()))
    for slot, name, rule, folder, mesh_name in shells:
        others = set().union(*(f for n, f in hide.items() if n != name))
        faces = shell_faces(body, rule, arm) - others
        shell = make_shell(body, faces, rule["offset"] * K, mesh_name)
        tex = image_shell(shell, folder, rule.get("mirror_x", False), rule["tex"])
        hide[name] = hide.get(name, set()) | faces
        lines.append(f"{slot}: оболочка {mesh_name}, {len(shell.data.polygons)} гр., {tex}")
    total_faces = len(body.data.polygons)
    cut = split_hidden(body, hide)
    lines.append("под вещами спрятано: " + (", ".join(f"{sl} {n} гр. ({n / total_faces:.0%} тела)" for sl, n in cut) or "ничего"))
    arm.data.pose_position = "POSE"
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if not any(c.name == "glTF_not_exported" for c in o.users_collection):
            o.select_set(True)
    for a in bpy.data.actions:
        a.use_fake_user = True
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animation_mode="ACTIONS")
    total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.selected_objects if o.type == "MESH")
    print(f"DRESS {Path(OUT).name}: всего {total} треугольников; " + "; ".join(lines))


main()
