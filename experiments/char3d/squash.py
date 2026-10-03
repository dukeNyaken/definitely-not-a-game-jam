"""Blender: прижать торчащее вглубь (по Y) выше заданной высоты — после bake.py, до rig.py.

    blender -b --python squash.py -- <вход.glb> <выход.glb> [z=1.7] [y=0.3] [k=0.2]

Hunyuan достраивает рог колпака шута, торчащий на картинке вверх-назад, длинным
хвостом за спину (глубина модели ~1 м вместо ~0.5). Вершины выше z (метров,
модель уже в росте 2.1 и стоит на нуле) дальше y за осью (сзади: лицо после
bake.py смотрит в -Y) сжимаются к ней в k раз; спереди ничего не трогается.
UV не меняются — текстура остаётся на месте.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
P = {"z": 1.7, "y": 0.3, "k": 0.2, **{a.split("=")[0]: float(a.split("=")[1]) for a in argv[2:]}}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
moved = 0
for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    for v in ob.data.vertices:
        co = ob.matrix_world @ v.co
        if co.z > P["z"] and co.y > P["y"]:
            co.y = P["y"] + (co.y - P["y"]) * P["k"]
            v.co = ob.matrix_world.inverted() @ co
            moved += 1
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB")
dims = max((ob.dimensions for ob in bpy.context.scene.objects if ob.type == "MESH"), key=lambda d: d.y)
print(f"SQUASH {DST}: вершин сдвинуто {moved}; размер {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} м")
