"""Blender: скелет с именами Mixamo под лоу-поли тело + автоматические веса.

    blender -b --python rig.py -- <тело.glb> <картинка.png> <выход.glb>

Суставы — точки DWPose (keypoints.py -> <картинка>_pose.json), перенесённые
на сетку тем же совмещением рамок, что и текстура (bake.py): рамка маски
картинки = рамка сетки спереди. Глубина сустава — середина сечения тела
по лучу спереди назад через эту точку. Левая и правая половины
усредняются зеркально: сетка симметрична (упрощалась с симметрией), так
точнее, чем одна сторона. Пальцев нет — на 1500 треугольниках кисть одна.
Веса — Blender «с автоматическими весами» (тепловая диффузия).
Печатает число костей, вершин без веса и наибольшее число влияний на вершину.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).parent
R = json.loads((HERE / "data" / "rig.json").read_text(encoding="utf-8"))
argv = sys.argv[sys.argv.index("--") + 1:]
BODY, IMAGE, OUT = (str(Path(a).resolve()) for a in argv[:3])

# DWPose: индексы точек; L — левая сторона человека (+X в Blender, он смотрит в -Y)
WEIGHTS_VIA = ""
KP = {"nose": 0, "neck": 1, "sho": (5, 2), "elb": (6, 3), "wri": (7, 4), "hip": (11, 8),
      "knee": (12, 9), "ank": (13, 10), "ear": (17, 16), "big": (18, 21), "small": (19, 22), "heel": (20, 23)}


def load_body():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BODY)
    ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    # glTF хранит вершину отдельно на каждом шве UV: 1498 треугольников приходят
    # 4492 вершинами-островками, и тепловые веса на них не считаются вовсе.
    # Склейка совпадающих вершин швы UV не трогает — UV живут на углах граней.
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def image_to_mesh(ob):
    """Функция (x, y картинки) -> (X, Z сетки) по совмещению рамок силуэта."""
    m = bpy.data.images.load(str(Path(IMAGE).with_name(Path(IMAGE).stem + "_prep.mask.png")))
    w, h = m.size
    mask = np.array(m.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, 0] > 0.5
    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    co = np.array([v.co for v in ob.data.vertices])
    lo, hi = co.min(0), co.max(0)

    def f(px, py):
        return (lo[0] + (px - x0) / (x1 - x0) * (hi[0] - lo[0]),
                hi[2] - (py - y0) / (y1 - y0) * (hi[2] - lo[2]))
    return f, lo, hi


def joints(ob):
    pose = json.loads(Path(IMAGE).with_name(Path(IMAGE).stem + "_pose.json").read_text())
    to_mesh, lo, hi = image_to_mesh(ob)
    bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    far = (hi[1] - lo[1]) * 4 + 1

    def depth(x, z):
        """Середина сечения по Y; если луч прошёл мимо (точка у самого края) — ближайшая поверхность."""
        a = bvh.ray_cast(Vector((x, lo[1] - far, z)), Vector((0, 1, 0)))[0]
        b = bvh.ray_cast(Vector((x, hi[1] + far, z)), Vector((0, -1, 0)))[0]
        if a is not None and b is not None:
            return (a.y + b.y) / 2
        return bvh.find_nearest(Vector((x, (lo[1] + hi[1]) / 2, z)))[0].y

    def pt(i):
        x, z = to_mesh(pose[i][0], pose[i][1])
        return Vector((x, depth(x, z), z))

    J = {}
    for name, idx in KP.items():
        if isinstance(idx, tuple):
            l, r = pt(idx[0]), pt(idx[1])
            # зеркальное среднее: левая точка и отражённая правая
            m = Vector(((l.x - r.x) / 2, (l.y + r.y) / 2, (l.z + r.z) / 2))
            J["L_" + name], J["R_" + name] = m, Vector((-m.x, m.y, m.z))
        else:
            J[name] = pt(idx)
    J["top"] = Vector((0, J["neck"].y, hi[2]))
    return J


def build(J):
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None, connect=False):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    hip_c = (J["L_hip"] + J["R_hip"]) / 2
    neck = J["neck"].copy()
    neck.x = 0
    hips = hip_c.lerp(neck, R["hips_up"])
    ear = (J["L_ear"] + J["R_ear"]) / 2
    ear.x = 0
    bone("Hips", hip_c, hips)
    prev = "Hips"
    spine = ["Spine", "Spine1", "Spine2"]
    for i, n in enumerate(spine):
        a = hips.lerp(neck, i / len(spine))
        b = hips.lerp(neck, (i + 1) / len(spine))
        bone(n, a, b, prev, connect=(i > 0))
        prev = n
    head_base = neck.lerp(ear, R["head_base"])
    bone("Neck", neck, head_base, "Spine2", True)
    bone("Head", head_base, J["top"], "Neck", True)
    bone("HeadTop_End", J["top"], J["top"] + Vector((0, 0, R["end_len"])), "Head", True)

    for s, S in (("L", "Left"), ("R", "Right")):
        sho, elb, wri = J[s + "_sho"], J[s + "_elb"], J[s + "_wri"]
        clav = neck.lerp(sho, R["clavicle_start"])
        clav.z = neck.z - R["clavicle_drop"]
        bone(S + "Shoulder", clav, sho, "Spine2")
        bone(S + "Arm", sho, elb, S + "Shoulder", True)
        bone(S + "ForeArm", elb, wri, S + "Arm", True)
        hand_end = wri + (wri - elb).normalized() * (wri - elb).length * R["hand_len"]
        bone(S + "Hand", wri, hand_end, S + "ForeArm", True)

        hip, knee, ank = J[s + "_hip"], J[s + "_knee"], J[s + "_ank"]
        toe = (J[s + "_big"] + J[s + "_small"]) / 2
        ball = toe.lerp(J[s + "_heel"], R["ball_from_toe"])
        ball.z = ank.z * R["ball_height"]
        toe.z = ball.z
        bone(S + "UpLeg", hip, knee, "Hips")
        bone(S + "Leg", knee, ank, S + "UpLeg", True)
        bone(S + "Foot", ank, ball, S + "Leg", True)
        bone(S + "ToeBase", ball, toe, S + "Foot", True)
        bone(S + "Toe_End", toe, toe + Vector((0, -R["end_len"], 0)), S + "ToeBase", True)

    # крен костей: ось Z каждой кости — вперёд (-Y) у корпуса и ног, вверх у рук
    # и стоп. Стопа и носок лежат почти вдоль -Y, и «Z вперёд» для них вырождается.
    # От этой договорённости зависят знаки в data/anims.json:
    #   корпус, бёдра: +X — наклон / мах вперёд, +Y — поворот влево;
    #   колено: -X — сгиб; стопа: +X — носок вверх;
    #   левая рука: +X — поднять в сторону, -Z — вперёд; у правой Y и Z зеркальны.
    up = ("Shoulder", "Arm", "Hand", "Foot", "Toe")
    for b in eb:
        b.select = not any(k in b.name for k in up)
    bpy.ops.armature.calculate_roll(type="GLOBAL_NEG_Y")
    for b in eb:
        b.select = any(k in b.name for k in up)
    bpy.ops.armature.calculate_roll(type="GLOBAL_POS_Z")
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _heat(ob, arm):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    return sum(1 for v in ob.data.vertices if not any(g.weight > 1e-4 for g in v.groups))


def skin(ob, arm):
    """Тепловые веса; если не сошлись (на сильно упрощённой сетке бывают
    неманифолдные места), — считаются на замкнутой копии, пересобранной
    вокселями, и переносятся на сетку по ближайшей грани."""
    global WEIGHTS_VIA
    if _heat(ob, arm) == 0:
        WEIGHTS_VIA = "тепло"
    else:
        proxy = ob.copy()
        proxy.data = ob.data.copy()
        bpy.context.scene.collection.objects.link(proxy)
        proxy.parent = None
        proxy.modifiers.clear()
        proxy.vertex_groups.clear()
        rm = proxy.modifiers.new("remesh", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = R["proxy_voxel"] * max(proxy.dimensions)
        bpy.context.view_layer.objects.active = proxy
        bpy.ops.object.modifier_apply(modifier="remesh")
        left = _heat(proxy, arm)
        ob.vertex_groups.clear()
        for g in proxy.vertex_groups:
            ob.vertex_groups.new(name=g.name)
        dt = ob.modifiers.new("dt", "DATA_TRANSFER")
        dt.object = proxy
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_move_to_index(modifier="dt", index=0)
        bpy.ops.object.modifier_apply(modifier="dt")
        bpy.data.objects.remove(proxy)
        WEIGHTS_VIA = f"через воксельную копию (без веса на копии: {left})"
        _fill_unweighted(ob)
    # не больше 4 влияний на вершину: столько берёт glTF за один набор, и так дешевле.
    # Выделение — явно: после расчёта на копии оно осталось на ней, и ограничение не применялось.
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    unweighted = sum(1 for v in ob.data.vertices if not any(g.weight > 1e-4 for g in v.groups))
    most = max(len([g for g in v.groups if g.weight > 1e-4]) for v in ob.data.vertices)
    return unweighted, most


def _fill_unweighted(ob):
    """Вершинам без веса — веса ближайшей вершины с весом (места, где не сошлось и на копии)."""
    from mathutils.kdtree import KDTree
    has = [v for v in ob.data.vertices if any(g.weight > 1e-4 for g in v.groups)]
    kd = KDTree(len(has))
    for i, v in enumerate(has):
        kd.insert(v.co, i)
    kd.balance()
    for v in ob.data.vertices:
        if not any(g.weight > 1e-4 for g in v.groups):
            src = has[kd.find(v.co)[1]]
            for g in src.groups:
                ob.vertex_groups[g.group].add([v.index], g.weight, "REPLACE")


def _band(co, z, keep, need=8):
    """Вершины у высоты z: полоса ±2 см, расширяется до ±16, пока в неё не попадёт need вершин
    (на 900 треугольниках вершины по высоте разнесены на 5-10 см, в узкую полосу не попадает ни одной)."""
    for tol in (0.02, 0.04, 0.08, 0.16):
        band = co[(np.abs(co[:, 2] - z) < tol) & keep]
        if len(band) >= need:
            return band
    return band


def section(ob, z, half_width):
    """Срез тела на высоте z в пределах |x| < half_width: ширина и глубина, м."""
    co = np.array([v.co for v in ob.data.vertices])
    band = _band(co, z, np.abs(co[:, 0]) < half_width)
    return (band.max(0) - band.min(0))[:2] if len(band) else (0, 0)


def main():
    ob = load_body()
    J = joints(ob)
    arm = build(J)
    unweighted, most = skin(ob, arm)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
    # грудь — срез посередине между основанием шеи и плечами по высоте, в пределах плеч;
    # бедро — срез левой ноги на середине бедренной кости
    sho = J["L_sho"]
    chest = section(ob, (J["neck"].z + J["L_hip"].z) / 2 + (sho.z - J["L_hip"].z) * 0.25, abs(sho.x))
    mid = (J["L_hip"] + J["L_knee"]) / 2
    co = np.array([v.co for v in ob.data.vertices])
    leg = _band(co, mid.z, co[:, 0] * np.sign(mid.x) > 0.01)
    thigh = (leg.max(0) - leg.min(0))[:2] if len(leg) else (0, 0)
    print(f"RIG {Path(OUT).name}: костей {len(arm.data.bones)}, вершин {len(ob.data.vertices)}, "
          f"без веса {unweighted}, влияний на вершину до {most}; "
          f"веса {WEIGHTS_VIA}; грудь {chest[0]:.2f}x{chest[1]:.2f} м, бедро {thigh[0]:.2f} м, рост {ob.dimensions.z:.2f} м")
    # точки суставов — для проверки глазами и замеров
    (Path(OUT).with_suffix(".joints.json")).write_text(json.dumps({k: list(v) for k, v in J.items()}, indent=1))


main()
