"""Blender: снимок glb с четырёх сторон (спереди, справа, сзади, слева) одним листом.

    blender -b --python views.py -- <модель.glb> <лист.png> [точек на вид] [pose=<поза.json>] [anim=<действие>:<кадр>]

Без pose/anim модель снимается в позе покоя.
worn=1 — скрыть части тела под вещами (hide_*), как в игре.
pose — {кость: [X, Y, Z] градусов в локальных осях кости}: пробная поза для
проверки весов. anim — кадр действия из файла (проверка анимации).

Ортокамера и Workbench: видна форма, а не освещение. Если в модели есть
текстура — рисуется текстурой, иначе серым. Нужен для проверки глазами
каждого шага; цифры (треугольники, размеры) печатает он же.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = str(Path(argv[0]).resolve()), str(Path(argv[1]).resolve())
RES = int(argv[2]) if len(argv) > 2 and argv[2].isdigit() else 512
OPT = dict(a.split("=", 1) for a in argv[2:] if "=" in a)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
if arm:
    # без anim= — поза покоя: импорт сам надевает первое действие
    arm.data.pose_position = "POSE" if "anim" in OPT or "pose" in OPT else "REST"
if arm and "pose" in OPT:
    import json, math
    for name, deg in json.loads(Path(OPT["pose"]).read_text(encoding="utf-8")).items():
        if name.startswith("_"):
            continue
        pb = arm.pose.bones[name]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = [math.radians(d) for d in deg]
if arm and "anim" in OPT:
    act, frame = OPT["anim"].rsplit(":", 1)
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[act]
    bpy.context.scene.frame_set(int(frame))
bpy.context.view_layer.update()
# импорт glTF кладёт форму костей (Icosphere) в glTF_not_exported — это не модель;
# worn=1 — как в игре при надетых вещах: части тела hide_* под вещами скрыты
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"
          and not any(c.name == "glTF_not_exported" for c in o.users_collection)]
if OPT.get("worn") == "1":
    for o in meshes:
        if o.name.startswith("hide_"):
            o.hide_render = True
    meshes = [o for o in meshes if not o.name.startswith("hide_")]
for c in bpy.data.collections:
    if c.name == "glTF_not_exported":
        c.hide_render = True
dg = bpy.context.evaluated_depsgraph_get()
pts = [o.matrix_world @ v.co for o in meshes for v in o.evaluated_get(dg).to_mesh().vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center, size = (lo + hi) / 2, hi - lo
tris = sum(len(o.evaluated_get(dg).data.loop_triangles) for o in meshes)
print(f"VIEWS {Path(SRC).name}: {tris} треугольников, размер {size.x:.3f} x {size.y:.3f} x {size.z:.3f}")

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
has_tex = any(n.type == "TEX_IMAGE" for o in meshes for m in o.data.materials if m and m.use_nodes for n in m.node_tree.nodes)
sh.color_type = "TEXTURE" if has_tex else "SINGLE"
sh.light = "FLAT" if has_tex else "STUDIO"
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.18, 0.18, 0.2)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(size) * 1.1
dist = max(size) * 3

# glTF -> Blender: Y-вверх glTF становится Z-вверх; «перед» модели смотрит в -Y
views = {"front": Vector((0, -1, 0)), "right": Vector((1, 0, 0)), "back": Vector((0, 1, 0)), "left": Vector((-1, 0, 0))}
shots = []
for name, d in views.items():
    cam.location = center + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    path = str(Path(DST).with_name(f"_{name}.png"))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    shots.append(path)

# склейка в один лист
imgs = [bpy.data.images.load(p) for p in shots]
sheet = bpy.data.images.new("sheet", RES * 4, RES)
px = [0.0] * (RES * 4 * RES * 4)
for i, im in enumerate(imgs):
    src = list(im.pixels)
    for y in range(RES):
        row = src[y * RES * 4:(y + 1) * RES * 4]
        start = (y * RES * 4 + i * RES) * 4
        px[start:start + RES * 4] = row
sheet.pixels = px
sheet.filepath_raw = DST
sheet.file_format = "PNG"
sheet.save()
for p in shots:
    Path(p).unlink()
