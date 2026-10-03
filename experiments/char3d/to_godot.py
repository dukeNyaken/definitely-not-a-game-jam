"""Одетый персонаж -> проект Godot с ретаргетом под библиотеку анимаций.

    python to_godot.py <одетый.glb> <имя> [проект]      # проект по умолчанию — tools.godot_project

1. копирует glb в <проект>/characters/<имя>.glb;
2. если в проекте ещё нет карт костей — делает их (tools/make_bonemaps.gd);
3. Godot создаёт .import, godot_import.py вписывает ретаргет, Godot импортирует заново;
4. tools/inspect.gd проверяет итог: скелет должен называться GeneralSkeleton.
Возвращает строку отчёта (её же печатает).
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import godot_import

HERE = Path(__file__).parent
TOOLS = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["tools"]


def _godot(project, *args):
    r = subprocess.run([TOOLS["godot"], "--headless", "--path", str(project), *args],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    return r.stdout + r.stderr


def reimport(project, rel):
    """Импорт заново после правки .import: Godot сам замечает не всегда (новый файл
    сразу после первого импорта он считает свежим), поэтому кэш импорта стирается."""
    for f in (Path(project) / ".godot" / "imported").glob(Path(rel).name + "-*"):
        f.unlink()
    return _godot(project, "--import")


def install(glb, name, project=None):
    project = Path(project or TOOLS["godot_project"])
    dst = project / "characters" / f"{name}.glb"
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(glb, dst)
    if not (project / "retarget" / "bonemap_mixamo.tres").exists():
        _godot(project, "--script", "res://tools/make_bonemaps.gd")
    _godot(project, "--import")
    godot_import.main(str(project), "character", f"res://characters/{name}.glb")
    reimport(project, f"characters/{name}.glb")
    out = _godot(project, "--script", "res://tools/inspect.gd", "--", f"res://characters/{name}.glb")
    lines = [l for l in out.splitlines() if l.startswith(("СКЕЛЕТ", "АНИМАЦИИ", "СЕТКА"))]
    ok = any("GeneralSkeleton" in l for l in lines)
    rep = f"GODOT {dst}: ретаргет {'есть' if ok else 'НЕ ПРИМЕНИЛСЯ'}\n" + "\n".join(lines)
    print(rep)
    if not ok:
        raise RuntimeError(rep + "\n" + "\n".join(out.splitlines()[-15:]))
    return rep


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    install(*sys.argv[1:])
