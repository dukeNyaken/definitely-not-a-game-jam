"""Графы двух вкладок ComfyUI (формат API) из тех же функций, что у скриптов.

    python comfy_tabs.py   -> comfy_workflows/tab1..tab4 *.api.json

Вкладка 1: текст -> Qwen (спереди) -> Qwen-правка (сзади) -> вырезка фона ->
Hunyuan3D -> «сохранить персонажа» (output/char3d/<имя>/) + предпросмотр.
Вкладка 2: персонаж -> лоу-поли + текстура -> скелет -> анимации, после
каждого шага Preview3D и отчёт цифрами.
Вкладка 3: текст -> вещь (те же шаги, что у вкладки 1) -> лоу-поли.
Вкладка 4: персонаж + вещи по слотам -> одетый персонаж -> в проект Godot.
Подграфы берутся из text2img / img_edit / img2mesh — числа в одном месте
(data/*.json). В интерфейс графы превращает фронтенд ComfyUI (app.loadApiJson).
"""
import json
from pathlib import Path

import img2mesh
import img_edit
import text2img

HERE = Path(__file__).parent
_S = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))
LP, TOOLS = _S["lowpoly"], _S["tools"]
EQ = json.loads((HERE / "data" / "equipment.json").read_text(encoding="utf-8"))["slots"]


def merge(g, sub, prefix, skip=(), rename=None):
    """Вкладывает подграф sub в g: номера узлов -> prefix+номер; ссылки на узлы
    из rename заменяются готовой ссылкой (так подграфы делят загрузчики и входы)."""
    rename = rename or {}
    for nid, node in sub.items():
        if node["class_type"] in skip:
            continue
        inputs = {}
        for key, val in node["inputs"].items():
            if isinstance(val, list) and len(val) == 2 and isinstance(val[0], str):
                val = rename[val[0]] if val[0] in rename else [prefix + val[0], val[1]]
            inputs[key] = val
        g[prefix + nid] = {"class_type": node["class_type"], "inputs": inputs}


def tab1(subject="hero_body", name="hero2", kind="персонаж"):
    g = {}
    seed = text2img.S["seed"]
    merge(g, text2img.qwen_graph(subject, seed, ""), "f", skip=("SaveImage",))
    front = ["f9", 0]
    # правка «вид сзади» делит с видом спереди все загрузчики, вход — картинка спереди
    # зерно вида сзади +1: с тем же, что у вида спереди, Qwen рисует «каменный»
    # костюм и закрывает лицо (IoU силуэта 0.56-0.73), с +1 — чисто (0.86)
    # правка «сзади» своя у субъекта (ключ back): у одиночной поножи общая давала тот же вид спереди
    back_edit = img_edit.EDITS[text2img.SUBJECTS[subject].get("back", "back")]
    merge(g, img_edit.graph("", back_edit, seed + 1, ""), "b",
          skip=("SaveImage", "LoadImage", "UnetLoaderGGUF", "CLIPLoader", "VAELoader", "QwenImage21Cache"),
          rename={"1": ["f1", 0], "2": ["f2", 0], "3": ["f3", 0], "4": ["f4", 0], "6": front})
    back = ["b9", 0]
    g["c1"] = {"class_type": "Char3DCutout", "inputs": {"image": front}}
    merge(g, img2mesh.graph("", ""), "h", skip=("SaveGLB", "LoadImage"), rename={"2": ["c1", 0]})
    g["s1"] = {"class_type": "Char3DSaveCharacter", "inputs": {"name": name, "kind": kind, "front": front, "back": back, "mesh": ["h9", 0]}}
    g["s2"] = {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["s1", 0], "width": 1024, "height": 1024}}
    g["s3"] = {"class_type": "PreviewAny", "inputs": {"source": ["s1", 2]}}
    g["p1"] = {"class_type": "PreviewImage", "inputs": {"images": front}}
    g["p2"] = {"class_type": "PreviewImage", "inputs": {"images": back}}
    g["p3"] = {"class_type": "PreviewImage", "inputs": {"images": ["c1", 0]}}
    if kind == "вещь":
        # вещь сразу в лоу-поли: имя папки приходит с «сохранить», список выбора не нужен
        g["l1"] = {"class_type": "Char3DLowPoly", "inputs": {"character": "(взять из name_in)", "tris": 0, "tex": 0,
                                                             "height": LP["body"]["height"], "name_in": ["s1", 1]}}
        g["l2"] = {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["l1", 0], "width": 1024, "height": 1024}}
        g["l3"] = {"class_type": "PreviewAny", "inputs": {"source": ["l1", 2]}}
    return _numbered(g)


def tab2(character="hero", height=None):
    return {
        "1": {"class_type": "Char3DLowPoly", "inputs": {"character": character, "tris": 0, "tex": 0, "height": height or LP["body"]["height"]}},
        "2": {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["1", 0], "width": 1024, "height": 1024}},
        "3": {"class_type": "PreviewAny", "inputs": {"source": ["1", 2]}},
        "4": {"class_type": "Char3DRig", "inputs": {"character": ["1", 1]}},
        "5": {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["4", 0], "width": 1024, "height": 1024}},
        "6": {"class_type": "PreviewAny", "inputs": {"source": ["4", 2]}},
        "7": {"class_type": "Char3DAnimate", "inputs": {"character": ["4", 1]}},
        "8": {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["7", 0], "width": 1024, "height": 1024}},
        "9": {"class_type": "PreviewAny", "inputs": {"source": ["7", 1]}},
    }


def tab3(subject="helmet", name="helmet"):
    return tab1(subject, name, kind="вещь")


def tab4(character="hero", worn=None):
    worn = worn or {"helmet": "item_helmet", "armor": "item_armor", "sword": "item_sword"}
    slots = {s: worn.get(s, "(нет)") for s in EQ}
    return {
        "1": {"class_type": "Char3DDress", "inputs": {"character": character, **slots}},
        "2": {"class_type": "Preview3DAdvanced", "inputs": {"model_3d": ["1", 0], "width": 1024, "height": 1024}},
        "3": {"class_type": "PreviewAny", "inputs": {"source": ["1", 2]}},
        "4": {"class_type": "Char3DToGodot", "inputs": {"character": ["1", 1], "project": TOOLS["godot_project"]}},
        "5": {"class_type": "PreviewAny", "inputs": {"source": ["4", 0]}},
    }


def _numbered(g):
    """Фронтенд ждёт числовые номера узлов."""
    ids = {k: str(i + 1) for i, k in enumerate(g)}
    out = {}
    for k, node in g.items():
        inputs = {key: [ids[v[0]], v[1]] if isinstance(v, list) and len(v) == 2 and v[0] in ids else v
                  for key, v in node["inputs"].items()}
        out[ids[k]] = {"class_type": node["class_type"], "inputs": inputs}
    return out


if __name__ == "__main__":
    out = HERE / "comfy_workflows"
    out.mkdir(exist_ok=True)
    for fname, graph in (("tab1_character.api.json", tab1()), ("tab2_animate.api.json", tab2()),
                         ("tab3_item.api.json", tab3()), ("tab4_dress.api.json", tab4())):
        (out / fname).write_text(json.dumps(graph, ensure_ascii=False, indent=1), encoding="utf-8")
        print(fname, len(graph), "узлов")
