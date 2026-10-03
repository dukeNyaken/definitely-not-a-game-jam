"""Bake, rig and export reviewed prologue NPC generation results in Blender.

Run after prologue_npcs.py images, backs, meshes and keypoints.py.
The father's hidden joints were placed manually; preserve front_pose.json.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "output" / "prologue_npcs"
TOOLS = json.loads((HERE / "data/settings.json").read_text(encoding="utf-8"))["tools"]


def blender(script, args, log):
    command = [TOOLS["blender"], "-b", "--python", str(HERE / script), "--", *map(str, args)]
    result = subprocess.run(command, capture_output=True, env={**os.environ, "PYTHONIOENCODING": "utf-8"})
    text = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    log.write_text(text, encoding="utf-8")
    print(text[-1400:], flush=True)
    if result.returncode or "Traceback" in text:
        raise RuntimeError(f"Blender failed: {log}")


# Без скелета людей: только запекание сетки (череп слизня кувыркается в кубе); рою (QUAD) —
# свой скелет на четыре лапы, их качает процедурная модель.
QUAD = ["swarm"]
STATIC = {
    "swarm": ["body", "tris=900", "tex=128", "height=0.75", "sym=0"],
    "slime_skull": ["item", "tris=300", "tex=128"],
}


# Поправки по персонажу: лицо шута с фото читается только на текстуре 512; рог его
# колпака Hunyuan вытягивает за спину — squash.py прижимает его к затылку до оснастки.
BAKE = {"jester_v2": ["tex=512"]}
SQUASH = {"jester_v2": ["z=1.45", "y=0.12", "k=0.08"]}


def main(ids):
    for name in ids or ["young_brother", "father", "beloved", "faithful", "friend", "refugee", "captain", "widow", "smith", "novice", "mother"]:
        d = OUT / name
        if name in STATIC:
            if not (d / "lowpoly.glb").exists():
                print(f"START {name} bake.py", flush=True)
                blender("bake.py", [d / "raw.glb", d / "front.png", d / "lowpoly.glb", STATIC[name][0], d / "back.png", *STATIC[name][1:]], d / "bake.py.log")
            if name in QUAD and not (d / "rigged.glb").exists():
                print(f"START {name} quad_rig.py", flush=True)
                blender("quad_rig.py", [d / "lowpoly.glb", d / "rigged.glb"], d / "quad_rig.py.log")
            continue
        for script, args, result in [
            ("bake.py", [d / "raw.glb", d / "front.png", d / "lowpoly.glb", "body", d / "back.png", "tris=1500", "tex=256", "height=2.1", *BAKE.get(name, [])], "lowpoly.glb"),
            *([("squash.py", [d / "lowpoly.glb", d / "squashed.glb", *SQUASH[name]], "squashed.glb")] if name in SQUASH else []),
            ("rig.py", [d / ("squashed.glb" if name in SQUASH else "lowpoly.glb"), d / "front.png", d / "rigged.glb"], "rigged.glb"),
            ("anim.py", [d / "rigged.glb", d / "animated.glb"], "animated.glb"),
        ]:
            if not (d / result).exists():
                print(f"START {name} {script}", flush=True)
                blender(script, args, d / (script + ".log"))
                if not (d / result).exists():
                    raise RuntimeError(f"Missing output {d / result}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1:])
