"""Blender: ключевые позы из data/anims.json -> действия на скелете -> glb.

    blender -b --python anim.py -- <тело_со_скелетом.glb> <выход.glb>

Каждый ключ — поза base, поверх неё поза ключа (кость из ключа заменяет
кость из base). В каждый ключ пишутся все кости, задействованные в действии:
иначе кость, упомянутая в одном ключе, тянулась бы через соседние, где её нет.
Печатает длительность и число ключей каждого действия.
"""
import json
import math
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).parent
A = json.loads((HERE / "data" / "anims.json").read_text(encoding="utf-8"))
argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = (str(Path(a).resolve()) for a in argv[:2])


def clean(pose):
    return {k: v for k, v in pose.items() if not k.startswith("_")}


def mirror(pose):
    """Левое <-> правое; поворот отражается сменой знака Y и Z (ось X кости — поперёк тела)."""
    out = {}
    for k, v in pose.items():
        name = k.replace("Left", "\0").replace("Right", "Left").replace("\0", "Right")
        out[name] = v if k == "Hips_loc" else [v[0], -v[1], -v[2]]
    return out


def resolve(ref):
    if isinstance(ref, dict):
        return mirror(clean(A["poses"][ref["mirror"]]))
    return clean(A["base"]) if ref == "base" else clean(A["poses"][ref])


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    sc = bpy.context.scene
    sc.render.fps = A["fps"]
    arm.animation_data_create()
    base = clean(A["base"])
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"

    report = []
    for name, spec in A["actions"].items():
        keys = [(f, {**base, **resolve(ref)}) for f, ref in spec["keys"]]
        bones = sorted({b for _, p in keys for b in p})
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for frame, pose in keys:
            for b in bones:
                if b == "Hips_loc":
                    pb = arm.pose.bones["Hips"]
                    pb.location = pose.get(b, [0, 0, 0])
                    pb.keyframe_insert("location", frame=frame)
                    continue
                pb = arm.pose.bones[b]
                pb.rotation_euler = [math.radians(d) for d in pose.get(b, [0, 0, 0])]
                pb.keyframe_insert("rotation_euler", frame=frame)
        act.frame_range = (keys[0][0], keys[-1][0])
        report.append(f"{name} {keys[-1][0] / A['fps']:.2f} с, ключей {len(keys)}, костей {len(bones)}"
                      + (", петля" if spec["loop"] else ""))
        arm.animation_data.action = None
        for pb in arm.pose.bones:   # сброс позы, чтобы следующее действие не наследовало хвосты
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS",
                              export_anim_single_armature=True)
    print("ANIM " + Path(OUT).name + ": " + "; ".join(report))


main()
