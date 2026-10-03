"""Blender: четвероногому (рой) — скелет «тело + четыре лапы», веса по высоте, glb со скином.

    blender -b --python quad_rig.py -- <lowpoly.glb> <выход.glb> [legs=0.42]

Сетка из bake.py (sym=0): морда в +X, лапы на z=0, рост — по модели. Лапы — вершины
ниже legs × рост, разнесённые на четыре четверти по X (перёд/зад) и Y (бока).
Кость лапы — от бедра (чуть выше этой высоты) до стопы; вес лапы плавно спадает
к животу, остальное — тело. Тепловые веса на 900 треугольниках не сходятся, а эти
сходятся всегда, и сетка гнётся без щелей. Кости: body, leg_fl, leg_fr, leg_bl, leg_br
(f/b — перёд/зад, l/r — левая/правая для морды в +X: левая — +Y).
"""
import sys

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
P = {"legs": 0.42, **{a.split("=")[0]: float(a.split("=")[1]) for a in argv[2:]}}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for v in ob.data.vertices])
height = co[:, 2].max()
knee = P["legs"] * height
low = co[co[:, 2] < knee]
cx, cy = np.median(low[:, 0]), np.median(co[:, 1])
quads = {}
for name, sx, sy in (("fl", 1, 1), ("fr", 1, -1), ("bl", -1, 1), ("br", -1, -1)):
    m = (np.sign(low[:, 0] - cx) == sx) & (np.sign(low[:, 1] - cy) == sy)
    foot = low[m][low[m][:, 2] < 0.15 * height]
    pts = foot if len(foot) else low[m]
    quads[name] = (pts[:, 0].mean(), pts[:, 1].mean())

# Скелет: тело вдоль X на высоте бедра, лапы вниз до пола.
hip = knee + 0.06 * height
arm_data = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
body = arm_data.edit_bones.new("body")
body.head = Vector((co[:, 0].min() * 0.5, cy, hip))
body.tail = Vector((co[:, 0].max() * 0.5, cy, hip))
for name, (x, y) in quads.items():
    b = arm_data.edit_bones.new("leg_" + name)
    b.head = Vector((x, y, hip))
    b.tail = Vector((x, y, 0.0))
    b.parent = body
bpy.ops.object.mode_set(mode="OBJECT")

# Веса: ниже бедра и у оси своей лапы — лапа (по высоте: 1 ниже колена, к бедру — 0;
# по радиусу от оси: 1 внутри, к краю — 0). Опущенная морда и бока живота тоже ниже
# бедра, но далеко от оси — остаются телу.
groups = {n: ob.vertex_groups.new(name=n) for n in ["body"] + ["leg_" + q for q in quads]}
blend = 0.14 * height
xs = sorted({round(x, 3) for x, _ in quads.values()})
ys = sorted({round(y, 3) for _, y in quads.values()})
radius = 0.45 * min(xs[-1] - xs[0], ys[-1] - ys[0])
for v in ob.data.vertices:
    x, y, z = v.co
    q = ("f" if x > cx else "b") + ("l" if y > cy else "r")
    fx, fy = quads[q]
    r = ((x - fx) ** 2 + (y - fy) ** 2) ** 0.5
    w = float(np.clip((hip + blend * 0.5 - z) / blend, 0.0, 1.0)) * float(np.clip((radius * 1.3 - r) / (radius * 0.6), 0.0, 1.0))
    if w > 0.0:
        groups["leg_" + q].add([v.index], w, "REPLACE")
    if w < 1.0:
        groups["body"].add([v.index], 1.0 - w, "REPLACE")
ob.parent = arm
mod = ob.modifiers.new("Armature", "ARMATURE")
mod.object = arm
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB")
print("QUAD %s: рост %.2f м, бедро %.2f м, радиус лапы %.2f м, лапы %s" % (DST, height, hip, radius,
      ", ".join("%s (%.2f, %.2f)" % (n, x, y) for n, (x, y) in quads.items())))
