"""Люди сюжетных сцен и враги из output/prologue_npcs в игру: assets/characters/npcs
и assets/characters/enemies (реестры npcs.json и enemies.json).

    python export_prologue_npcs.py [id ...]

Запускать после build_prologue_npcs.py. Тело с одеждой — одна сетка, поэтому
dress.py не нужен: animated.glb копируется как есть, замеряется на стенде
(measure/npc_<id>.json), импортируется в игру с ретаргетом, а затем
npc_poses.gd запекает стойки и жесты (anims/npc_<id>_*.tres) и сокеты в реестры.
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_prototype as ep
import godot_import
import to_godot

HERE = Path(__file__).resolve().parent
OUT = HERE / "output" / "prologue_npcs"
IDS = ["young_brother", "father", "beloved", "faithful", "friend", "refugee", "captain", "widow", "smith", "novice", "mother"]
# враги: тела в assets/characters/enemies, реестр enemies.json
ENEMIES = ["infantry", "archer", "brute", "caster", "jester"]


def main(ids):
    imports = []
    for name in ids or IDS + ENEMIES:
        src = OUT / name / "animated.glb"
        if not src.exists():
            print(f"ПРОПУСК {name}: нет {src}")
            continue
        folder = "enemies" if name in ENEMIES else "npcs"
        (ep.PROTO / folder).mkdir(parents=True, exist_ok=True)
        dst = ep.PROTO / folder / f"{name}.glb"
        shutil.copyfile(src, dst)
        print(ep.measure(f"npc_{name}", dst), flush=True)
        imports.append(f"res://assets/characters/{folder}/{name}.glb")
    to_godot._godot(ep.GAME, "--import")
    for res in imports:
        godot_import.main(str(ep.GAME), "character", res, ep.MAPS)
        to_godot.reimport(ep.GAME, res.replace("res://", ""))
    # experiments/ скрыт от Godot (.gdignore): скрипт поз запускается по пути на диске
    out = to_godot._godot(ep.GAME, "--script", str(HERE / "npc_poses.gd"))
    print("\n".join(l for l in out.splitlines() if l.startswith(("POSE", "NPC_POSES", "ERROR", "SCRIPT ERROR"))))
    if "NPC_POSES_DONE" not in out:
        raise RuntimeError("npc_poses.gd упал:\n" + "\n".join(out.splitlines()[-20:]))
    to_godot._godot(ep.GAME, "--import")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1:])
