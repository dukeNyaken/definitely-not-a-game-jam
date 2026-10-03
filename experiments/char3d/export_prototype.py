"""Варианты героя и босс -> папка assets/characters/ в игре: всё, что нужно SkinnedActorModel.

    python export_prototype.py [вариант ...]      # без аргументов — все из data/prototype.json

Для каждого варианта (data/prototype.json):
  heroes/<id>.glb      герой: тело + 7 вещей (dress.py variant=<id>), импорт с ретаргетом
  boss/<id>.glb        босс: общее тело + те же 7 вещей, посаженных по его росту
  measure/<тело>.json  замер клипов на этом теле (tools/measure_anims.gd в стенде godot_test):
                       скорость шага зависит от длины ног — у каждого тела своя
Общее: anims/ual.glb (библиотека UAL, CC0), retarget/bonemap_*.tres, heroes.json — список
вариантов для игры (меню «Герой»). animation.json (что и как играет) пишется руками.
Вариант пропускается, если у него не хватает вещей, — печатается, каких.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import godot_import
import to_godot

HERE = Path(__file__).parent
GAME = HERE.parents[1]
PROTO = GAME / "assets" / "characters"
STAND = Path(to_godot.TOOLS["godot_project"])
OUT = Path(r"D:\AI\ComfyUI_windows_portable\ComfyUI\output\char3d")
MANIFEST = json.loads((HERE / "data" / "prototype.json").read_text(encoding="utf-8"))
MAPS = "res://assets/characters/retarget"


def body_glb(name):
    d = OUT / name
    return d / "animated.glb" if (d / "animated.glb").exists() else d / "rigged.glb"


def dress(body, items, variant, dst):
    args = [to_godot.TOOLS["blender"], "-b", "--python", str(HERE / "dress.py"), "--", str(body), str(dst)]
    args += [f"{slot}={OUT / folder / 'lowpoly.glb'}" for slot, folder in items.items()] + [f"variant={variant}"]
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    line = next((l for l in r.stdout.splitlines() if l.startswith("DRESS")), None)
    if line is None:
        raise RuntimeError("dress.py упал:\n" + "\n".join((r.stdout + r.stderr).splitlines()[-20:]))
    return line.replace("; ", "\n    ")


def measure(name, glb):
    """Замер клипов на теле: тело ставится в стенд (там уже есть библиотека), результат — в assets/characters/measure."""
    to_godot.install(glb, name)
    out = PROTO / "measure" / f"{name}.json"
    to_godot._godot(STAND, "--script", "res://tools/measure_anims.gd", "--", name, str(out))
    m = json.loads(out.read_text(encoding="utf-8"))
    return f"{name}: " + ", ".join(f"{k.split('/')[1]} {m[k]['foot_speed']} м/с" for k in ("ual/Walk", "ual/Jog_Fwd", "ual/Sprint"))


def main(*only):
    for sub in ("heroes", "boss", "anims", "retarget", "measure"):
        (PROTO / sub).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(STAND / "anims" / "ual.glb", PROTO / "anims" / "ual.glb")
    shutil.copyfile(STAND / "anims" / "ual_LICENSE.txt", PROTO / "anims" / "ual_LICENSE.txt")
    for f in (STAND / "retarget").glob("bonemap_*.tres"):
        shutil.copyfile(f, PROTO / "retarget" / f.name)
    work = HERE / "out" / "proto"
    work.mkdir(parents=True, exist_ok=True)
    heroes, imports, measured = [], [], {}
    for v in MANIFEST["variants"]:
        if only and v["id"] not in only:
            continue
        missing = [f for f in v["items"].values() if not (OUT / f / "lowpoly.glb").exists()]
        if missing:
            print(f"ПРОПУСК {v['id']}: нет вещей {missing}")
            continue
        for kind, body in (("heroes", v["body"]), ("boss", MANIFEST["boss_body"])):
            dst = work / f"{v['id']}_{kind}.glb"
            print(f"{v['id']} / {kind}:\n    " + dress(body_glb(body), v["items"], v["id"], dst))
            shutil.copyfile(dst, PROTO / kind / f"{v['id']}.glb")
            imports.append(f"res://assets/characters/{kind}/{v['id']}.glb")
            if body not in measured:
                measured[body] = measure(body, dst)
        heroes.append({"id": v["id"], "title": v["title"],
                       "model": f"res://assets/characters/heroes/{v['id']}.glb", "measure": f"res://assets/characters/measure/{v['body']}.json",
                       "boss": f"res://assets/characters/boss/{v['id']}.glb", "boss_measure": f"res://assets/characters/measure/{MANIFEST['boss_body']}.json"})
    to_godot._godot(GAME, "--import")
    for res in imports:
        godot_import.main(str(GAME), "character", res, MAPS)
        to_godot.reimport(GAME, res.replace("res://", ""))
    godot_import.main(str(GAME), "library", "res://assets/characters/anims/ual.glb", MAPS)
    to_godot.reimport(GAME, "assets/characters/anims/ual.glb")
    # список вариантов: дополняется, а не затирается, когда собирается только часть
    path = PROTO / "heroes.json"
    old = json.loads(path.read_text(encoding="utf-8"))["heroes"] if path.exists() else []
    ids = [h["id"] for h in heroes]
    order = [v["id"] for v in MANIFEST["variants"]]
    merged = sorted([h for h in old if h["id"] not in ids] + heroes, key=lambda h: order.index(h["id"]) if h["id"] in order else 99)
    path.write_text(json.dumps({"_comment": "Пишется export_prototype.py (experiments/char3d). Варианты героя для меню «Герой».",
                                "heroes": merged}, ensure_ascii=False, indent=2), encoding="utf-8")
    print("ЗАМЕР ШАГА:\n  " + "\n  ".join(measured.values()))
    print(f"PROTOTYPE {PROTO}: вариантов {len(merged)} — " + ", ".join(h["title"] for h in merged))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(*sys.argv[1:])
