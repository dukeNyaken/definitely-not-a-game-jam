"""Пакетная генерация по субъектам из data/subjects.json теми же графами, что во вкладках.

    python -u gen_batch.py <субъект>[:рост] ...

Субъект-вещь (kind=item) -> вкладка 3 -> output/char3d/item_<субъект>/ (картинки, форма, лоу-поли).
Субъект-тело (kind=body)  -> вкладки 1 и 2 -> output/char3d/<субъект>/ (… скелет, свои анимации);
рост в метрах после двоеточия (по умолчанию settings: lowpoly.body.height).
Готовое (есть lowpoly.glb / animated.glb) пропускается — перезапуск продолжает с места.
"""
import json
import sys
from pathlib import Path

import build_prototype as bp
import comfy_tabs

SUB = json.loads((Path(__file__).parent / "data" / "subjects.json").read_text(encoding="utf-8"))


def main(*specs):
    for spec in specs:
        name, _, h = spec.partition(":")
        if SUB[name]["kind"] == "item":
            if (bp.OUT / f"item_{name}" / "lowpoly.glb").exists():
                print("уже есть:", name)
                continue
            bp.run(f"вещь {name}", comfy_tabs.tab3(name, name), f"item_{name}")
        else:
            if not (bp.OUT / name / "raw.glb").exists():
                bp.run(f"тело {name}: картинки и форма", comfy_tabs.tab1(name, name), f"{name}_tab1")
            if not (bp.OUT / name / "animated.glb").exists():
                bp.run(f"тело {name}: лоу-поли, скелет", comfy_tabs.tab2(name, float(h) if h else None), f"{name}_tab2")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    main(*sys.argv[1:])
