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


def main(ids):
    for name in ids or ["young_brother", "father", "beloved", "faithful", "friend", "refugee", "captain", "widow", "smith", "novice", "mother"]:
        d = OUT / name
        for script, args, result in [
            ("bake.py", [d / "raw.glb", d / "front.png", d / "lowpoly.glb", "body", d / "back.png", "tris=1500", "tex=256", "height=2.1"], "lowpoly.glb"),
            ("rig.py", [d / "lowpoly.glb", d / "front.png", d / "rigged.glb"], "rigged.glb"),
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
