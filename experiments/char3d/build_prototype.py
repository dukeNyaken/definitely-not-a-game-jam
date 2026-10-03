"""Полный цикл «текст -> одетый персонаж для игры» теми же графами, что во вкладках ComfyUI.

    python build_prototype.py <имя> <субъект тела> <слот>=<субъект|item_папка> ... [--fresh]

Пример: python build_prototype.py game_hero game_hero helmet=item_helmet gloves=gloves
  - персонаж: вкладка 1 (картинки + Hunyuan), вкладка 2 (лоу-поли, скелет, свои анимации);
  - вещь: готовая папка item_* берётся как есть, иначе генерируется вкладкой 3 из субъекта;
  - вкладка 4: одеть -> output/char3d/<имя>/dressed.glb.
Нужен запущенный ComfyUI с узлами char3d. Сторож температуры — внутри узлов
и здесь (comfy.guarded). Каждый шаг печатает отчёт своего узла.
"""
import json
import sys
from pathlib import Path

import comfy
import comfy_tabs

HERE = Path(__file__).parent
OUT = comfy.COMFY_DIR / "output" / "char3d"


def run(title, graph, log):
    graph = {k: v for k, v in graph.items() if v["class_type"] != "Preview3DAdvanced"}   # просмотр — только в интерфейсе
    with comfy.guarded(HERE / "out" / f"gpu_{log}.csv"):
        outputs, sec = comfy.run(graph, timeout=1800)
    temp, mem = comfy.gpu_peak(HERE / "out" / f"gpu_{log}.csv")
    print(f"=== {title}: {sec:.0f} с, видеокарта до {temp} °C, {mem} МиБ")
    for v in outputs.values():
        if "text" in v:
            print(v["text"][0])
    return outputs


def main(name, subject, *slots):
    # готовую форму не перегенерируем (каждая генерация — новый человек); --fresh — заново
    if "--fresh" in slots or not (OUT / name / "raw.glb").exists():
        run(f"персонаж {name}: картинки и форма", comfy_tabs.tab1(subject, name), f"{name}_tab1")
    slots = [s for s in slots if s != "--fresh"]
    g = comfy_tabs.tab2(name)
    run(f"персонаж {name}: лоу-поли, скелет, анимации", g, f"{name}_tab2")
    worn = {}
    for spec in slots:
        slot, src = spec.split("=", 1)
        if not (OUT / src / "lowpoly.glb").exists():
            run(f"вещь {slot}: из субъекта {src}", comfy_tabs.tab3(src, slot), f"item_{slot}")
            src = "item_" + slot
        worn[slot] = src
    run(f"одеть {name}: {worn}", comfy_tabs.tab4(name, worn), f"{name}_dress")
    print("ГОТОВО:", OUT / name / "dressed.glb")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(*sys.argv[1:])
