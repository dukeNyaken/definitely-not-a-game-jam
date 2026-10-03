"""Узлы ComfyUI для конвейера персонажей char3d (эксперимент к definitely-not-a-game-jam).

Логики здесь нет — только обёртки над скриптами из CHAR3D (prep, keypoints,
to_godot и Blender: bake, rig, anim, dress). Все числа — в CHAR3D/data/*.json.
Персонаж или вещь живёт папкой output/char3d/<имя>/ (у вещей имя начинается с item_):
    front.png, back.png      — картинки (и рядом служебные _fill, _prep.mask, _pose)
    raw.glb                  — сетка Hunyuan
    lowpoly.glb (+ .png)     — лоу-поли с текстурой
    rigged.glb               — со скелетом и весами            (только персонаж)
    animated.glb             — с действиями Idle / Walk / Attack (только персонаж)
    dressed.glb              — с надетыми вещами                (только персонаж)
Модели узлы отдают типом FILE_3D_GLB — его показывает Preview3DAdvanced.

Ещё здесь сторож температуры: пока ComfyUI работает, раз в 2 с смотрит
nvidia-smi и на 85 °C два замера подряд прерывает счёт и чистит очередь.
"""
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image

import folder_paths
from comfy_api.latest._util.geometry_types import File3D

CHAR3D = Path(r"C:\Godot\definitely-not-a-game-jam\experiments\char3d")
SETTINGS = CHAR3D / "data" / "settings.json"
EQUIPMENT = CHAR3D / "data" / "equipment.json"
if str(CHAR3D) not in sys.path:
    sys.path.insert(0, str(CHAR3D))

ITEM = "item_"        # приставка папки вещи
NONE = "(нет)"
FROM_INPUT = "(взять из name_in)"   # выбор, когда имя приходит связью с узла «сохранить»


def _settings():
    return json.loads(SETTINGS.read_text(encoding="utf-8"))


def _slots():
    return list(json.loads(EQUIPMENT.read_text(encoding="utf-8"))["slots"])


def _root():
    return Path(folder_paths.get_output_directory()) / "char3d"


def _folders(need, items=None):
    """Папки в output/char3d, где есть файл need; items=True/False — только вещи / только персонажи."""
    r = _root()
    if not r.exists():
        return []
    return sorted(p.name for p in r.iterdir() if (p / need).exists()
                  and (items is None or p.name.startswith(ITEM) == items))


def _or_hint(names, hint):
    return names or [hint]


def _glb(path):
    return File3D(str(path), "glb")


def _to_png(image, path):
    a = (image[0].cpu().numpy() * 255).clip(0, 255).astype(np.uint8)
    Image.fromarray(a).save(path)


def _from_png(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255
    return torch.from_numpy(a)[None]


def _blender(script, *args):
    """Скрипт Blender без окна; строки отчёта (BAKE/RIG/ANIM/DRESS) — наружу."""
    exe = _settings()["tools"]["blender"]
    r = subprocess.run([exe, "-b", "--python", str(CHAR3D / script), "--", *map(str, args)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [l for l in r.stdout.splitlines() if l.split(" ", 1)[0] in ("BAKE", "RIG", "ANIM", "DRESS", "VIEWS")]
    if r.returncode != 0 or not lines:
        tail = "\n".join((r.stdout + r.stderr).splitlines()[-25:])
        raise RuntimeError(f"{script} упал:\n{tail}")
    return "\n".join(lines).replace("; ", "\n")


def _mtimes(*paths):
    return ";".join(f"{p}:{os.path.getmtime(p) if os.path.exists(p) else 0}" for p in paths)


# ------------------------------------------------------------------ узлы


class Char3DCutout:
    """Фон долой: фигура на белом в квадрате — вход для Hunyuan (prep.py)."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"image": ("IMAGE",)}}

    def run(self, image):
        import prep
        tmp = Path(folder_paths.get_temp_directory()) / "char3d_cutout"
        tmp.mkdir(parents=True, exist_ok=True)
        src = tmp / "src.png"
        _to_png(image, src)
        prep.prep(src, tmp / "src_prep.png")
        return (_from_png(tmp / "src_prep.png"),)


class Char3DSaveCharacter:
    """Сохраняет набор в output/char3d/<имя>/ (вещь — в item_<имя>/) для следующих вкладок."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("FILE_3D_GLB", "STRING", "STRING")
    RETURN_NAMES = ("raw_glb", "name", "report")
    FUNCTION = "run"
    OUTPUT_NODE = True

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"name": ("STRING", {"default": "hero"}), "kind": (["персонаж", "вещь"],),
                             "front": ("IMAGE",), "mesh": ("MESH",)},
                "optional": {"back": ("IMAGE",)}}

    def run(self, name, kind, front, mesh, back=None):
        import prep
        from comfy_extras.nodes_save_3d import mesh_item_to_glb_bytes
        folder = (ITEM if kind == "вещь" and not name.startswith(ITEM) else "") + name
        d = _root() / folder
        d.mkdir(parents=True, exist_ok=True)
        _to_png(front, d / "front.png")
        prep.prep(d / "front.png", d / "front_prep.png")
        report = [f"{kind} {folder}: {d}"]
        if back is not None:
            _to_png(back, d / "back.png")
            prep.prep(d / "back.png", d / "back_prep.png")
            iou = prep.back_iou(d / "back.png", d / "front.png")
            report.append(f"вид сзади: IoU с отражённым видом спереди {iou:.3f}" + ("  <- МАЛО, поза поехала" if iou < 0.85 else ""))
        elif (d / "back.png").exists():
            (d / "back.png").unlink()
        (d / "raw.glb").write_bytes(mesh_item_to_glb_bytes(mesh, 0))
        import img2mesh
        v, t = img2mesh.glb_counts(d / "raw.glb")
        report.append(f"сырая сетка: {v} вершин, {t} треугольников")
        return (_glb(d / "raw.glb"), folder, "\n".join(report))


class Char3DLowPoly:
    """Лоу-поли + текстура с картинок (bake.py в Blender). Вещь или персонаж — по имени папки."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("FILE_3D_GLB", "STRING", "STRING")
    RETURN_NAMES = ("glb", "character", "report")
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        lp = _settings()["lowpoly"]
        return {"required": {
            "character": ([FROM_INPUT] + _folders("raw.glb"),),
            "tris": ("INT", {"default": 0, "min": 0, "max": 5000, "step": 50,
                             "tooltip": f"бюджет треугольников; 0 — по умолчанию: персонаж {lp['body']['tris']}, вещь {lp['item']['tris']}"}),
            "tex": ([0, 64, 128, 256], {"default": 0,
                                        "tooltip": f"сторона текстуры; 0 — по умолчанию: персонаж {lp['body']['tex']}, вещь {lp['item']['tex']}"}),
            "height": ("FLOAT", {"default": lp["body"]["height"], "min": 0.3, "max": 5.0, "step": 0.05,
                                 "tooltip": "рост персонажа в метрах (у вещи размер задаёт посадка)"}),
        }, "optional": {"name_in": ("STRING", {"forceInput": True,
                                               "tooltip": "имя с узла «сохранить» — тогда список выше не нужен"})}}

    @classmethod
    def IS_CHANGED(cls, character, name_in=None, **kw):
        d = _root() / (name_in or character)
        return _mtimes(d / "raw.glb", d / "front.png", d / "back.png", SETTINGS) + str(kw)

    def run(self, character, tris, tex, height, name_in=None):
        name = name_in or character
        if name == FROM_INPUT:
            raise RuntimeError("выбери персонажа в списке или подай имя связью в name_in")
        d = _root() / name
        kind = "item" if name.startswith(ITEM) else "body"
        args = [d / "raw.glb", d / "front.png", d / "lowpoly.glb", kind]
        if (d / "back.png").exists():
            args.append(d / "back.png")
        args += ([f"tris={tris}"] if tris else []) + ([f"tex={tex}"] if tex else []) + \
                ([f"height={height}"] if kind == "body" else [])
        rep = _blender("bake.py", *args)
        return (_glb(d / "lowpoly.glb"), name, rep)


class Char3DRig:
    """Скелет (имена Mixamo) по точкам DWPose + автоматические веса (keypoints.py, rig.py)."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("FILE_3D_GLB", "STRING", "STRING")
    RETURN_NAMES = ("glb", "character", "report")
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"character": ("STRING", {"forceInput": True})}}

    @classmethod
    def IS_CHANGED(cls, character):
        d = _root() / character
        return _mtimes(d / "lowpoly.glb", CHAR3D / "data" / "rig.json")

    def run(self, character):
        import keypoints
        if character.startswith(ITEM):
            raise RuntimeError("скелет нужен персонажу, а это вещь — её надевает узел «одеть»")
        d = _root() / character
        try:
            keypoints.main(str(d / "front.png"))
        except SystemExit as e:          # keypoints выходит через sys.exit — не даём уронить сервер
            raise RuntimeError(str(e))
        rep = _blender("rig.py", d / "lowpoly.glb", d / "front.png", d / "rigged.glb")
        return (_glb(d / "rigged.glb"), character, rep)


class Char3DAnimate:
    """Действия по ключевым позам из data/anims.json (anim.py)."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("FILE_3D_GLB", "STRING")
    RETURN_NAMES = ("glb", "report")
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"character": ("STRING", {"forceInput": True})}}

    @classmethod
    def IS_CHANGED(cls, character):
        d = _root() / character
        return _mtimes(d / "rigged.glb", CHAR3D / "data" / "anims.json")

    def run(self, character):
        d = _root() / character
        rep = _blender("anim.py", d / "rigged.glb", d / "animated.glb")
        return (_glb(d / "animated.glb"), rep)


class Char3DDress:
    """Надевает вещи на персонажа по правилам data/equipment.json (dress.py)."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("FILE_3D_GLB", "STRING", "STRING")
    RETURN_NAMES = ("glb", "character", "report")
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        items = [NONE] + _folders("lowpoly.glb", items=True)
        req = {"character": (_or_hint(_folders("rigged.glb", items=False), "(нет персонажа со скелетом — вкладка 2)"),)}
        for slot in _slots():
            req[slot] = (items,)
        return {"required": req}

    @classmethod
    def IS_CHANGED(cls, character, **slots):
        r = _root()
        files = [r / character / "animated.glb", r / character / "rigged.glb", EQUIPMENT]
        files += [r / v / "lowpoly.glb" for v in slots.values() if v != NONE]
        return _mtimes(*files) + str(sorted(slots.items()))

    def run(self, character, **slots):
        d = _root() / character
        body = d / "animated.glb" if (d / "animated.glb").exists() else d / "rigged.glb"
        pairs = [f"{s}={_root() / v / 'lowpoly.glb'}" for s, v in slots.items() if v != NONE]
        rep = _blender("dress.py", body, d / "dressed.glb", *pairs)
        return (_glb(d / "dressed.glb"), character, rep)


class Char3DToGodot:
    """Кладёт одетого персонажа в проект Godot и настраивает ретаргет (to_godot.py)."""
    CATEGORY = "char3d"
    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("report",)
    FUNCTION = "run"
    OUTPUT_NODE = True

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"character": ("STRING", {"forceInput": True}),
                             "project": ("STRING", {"default": _settings()["tools"]["godot_project"],
                                                    "tooltip": "проект Godot; персонаж ляжет в characters/<имя>.glb"})}}

    @classmethod
    def IS_CHANGED(cls, character, project):
        return _mtimes(_root() / character / "dressed.glb") + project

    def run(self, character, project):
        import to_godot
        return (to_godot.install(_root() / character / "dressed.glb", character, project),)


NODE_CLASS_MAPPINGS = {
    "Char3DCutout": Char3DCutout,
    "Char3DSaveCharacter": Char3DSaveCharacter,
    "Char3DLowPoly": Char3DLowPoly,
    "Char3DRig": Char3DRig,
    "Char3DAnimate": Char3DAnimate,
    "Char3DDress": Char3DDress,
    "Char3DToGodot": Char3DToGodot,
}
NODE_DISPLAY_NAME_MAPPINGS = {
    "Char3DCutout": "char3d: вырезать фон",
    "Char3DSaveCharacter": "char3d: сохранить персонажа / вещь",
    "Char3DLowPoly": "char3d: лоу-поли + текстура",
    "Char3DRig": "char3d: скелет и веса",
    "Char3DAnimate": "char3d: анимации",
    "Char3DDress": "char3d: одеть",
    "Char3DToGodot": "char3d: в Godot",
}


# ------------------------------------------------------------------ сторож температуры

GPU_LIMIT = 85.0     # °C — по заданию: на 85 останавливать


def _guard():
    import comfy.model_management as mm
    from server import PromptServer
    hot = 0
    while True:
        try:
            out = subprocess.run(["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
                                 capture_output=True, text=True, timeout=10).stdout
            t = float(out.strip().splitlines()[0])
            hot = hot + 1 if t >= GPU_LIMIT else 0
            # два замера подряд — одиночный выброс датчика не гасит генерацию
            if hot >= 2:
                mm.interrupt_current_processing()
                PromptServer.instance.prompt_queue.wipe_queue()
                print(f"[char3d] ВИДЕОКАРТА {t} °C — счёт прерван, очередь очищена")
                hot = 0
        except Exception as e:  # сторож не должен ронять сервер
            print(f"[char3d] сторож: {e}")
        time.sleep(2)


threading.Thread(target=_guard, daemon=True, name="char3d-gpu-guard").start()
print(f"[char3d] узлы загружены, сторож температуры: {GPU_LIMIT} °C")
