"""Тело из нашей генерации (поза, кадр, пропорции) в дизайне с концепт-арта.

    python restyle.py images|backs <id> ...

Картинка 1 — output/prologue_npcs/<основа>/front.png (А-поза, как у остальных),
картинка 2 — концепт, картинка 3 — лицо (если есть). Результат —
output/prologue_npcs/<id>/front.png и back.png; дальше — тот же конвейер
(keypoints, meshes, build_prologue_npcs.py); export_prologue_npcs.py берёт
пехотинца и шута отсюда (SOURCE).
Концепты и фото лежат в output/prologue_npcs/_refs (в репозиторий не идут).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy
import img_edit
import prep
import prologue_npcs as pn

REFS = pn.OUT / "_refs"
RESTYLE = {
    "infantry_v2": {
        "base": "infantry",
        "refs": ["swordsman.png"],
        "prompt": "Redraw the character in image 1 as the swordsman from image 2, keeping EXACTLY the pose, framing, position, "
                  "body proportions, arm angles and scale of image 1. Design from image 2: a tall woven straw basket hat "
                  "covering the whole head down to the shoulders with a small dark mesh window at the eyes, dark indigo "
                  "kimono jacket with short sleeves, dark iron lamellar chest armor laced with brown cord, wide dark sash and "
                  "belt, baggy dark gray hakama trousers tied with rope below the knees, dark leather bracers and gloves, "
                  "dark shin guards, straw sandals over dark socks. Arms straight diagonally down, hands open and empty, "
                  "no weapons, no sword, no scabbard. Early PlayStation 2 low polygon game model with hand painted textures. "
                  "Flat uniform medium gray background, soft even neutral illumination, no cast shadow, no text.",
        "back": " Show the back of the woven basket hat, the lamellar back plate with crossed cords and the sash knot.",
    },
    "jester_v2": {
        "base": "jester",
        "refs": ["court_fool.png", "face.png"],
        "prompt": "Redraw the character in image 1 as the court fool from image 2, keeping EXACTLY the pose, framing, position, "
                  "short stocky dwarf body proportions, big head, arm angles and scale of image 1. NO mask: give him the real "
                  "face of the young man from image 3 - same face shape, eyes, nose, wide friendly smile, clean shaven, short "
                  "dark brown hair at the forehead under the cap. The face is NOT a photo: sculpt and paint it in exactly "
                  "the same stylized low polygon hand painted game style and lighting as the costume, slightly caricatured, "
                  "recognizable likeness. Costume from image 2: three pointed red and charcoal jester "
                  "cap with brass bells, cream jagged collar, red and charcoal quartered doublet with puffed sleeves and small "
                  "gold diamonds, studded leather belt, jagged hem, quartered red and charcoal hose with patches, brown leather "
                  "gloves, brown curled pointed boots. Hands open and empty, no knives. Early PlayStation 2 low polygon game "
                  "model with hand painted textures. Flat uniform medium gray background, soft even neutral illumination, "
                  "no cast shadow, no text.",
        "back": " Show the back of the jester cap and bells, the back of the quartered doublet and hose; no face visible.",
    },
    # Щит героя-рыцаря: предмет, подменяется в heroes/knight.glb и boss/knight.glb (swap_item.py)
    "knight_shield": {
        "base": None,
        "refs": ["shield.png"],
        "prompt": "Recreate the shield from image 1 as one isolated early PlayStation 2 low polygon game prop with hand painted "
                  "texture: heater kite shield, polished steel face, brass trim along the edges with round brass rivets, an inset "
                  "brass escutcheon with three embossed lions in the upper middle, pointed bottom, gently curved top edge. "
                  "Straight FRONT orthographic view, centered, filling two thirds of the frame height. Flat uniform medium gray "
                  "background, soft even neutral illumination, NO cast shadow, no checkerboard, no text, nothing else.",
        "back": " Show the plain steel back of the shield with brass rim, two leather arm straps and a grip; no lions.",
    },
}


def main(stage, ids):
    with comfy.guarded(pn.OUT / ("restyle_" + stage + "_gpu.csv")):
        for name in ids:
            r = RESTYLE[name]
            folder = pn.OUT / name
            folder.mkdir(exist_ok=True)
            front, back = folder / "front.png", folder / "back.png"
            if stage == "images":
                # без основы (предмет) картинка 1 — сам концепт
                first = pn.OUT / r["base"] / "front.png" if r["base"] else REFS / r["refs"][0]
                graph = img_edit.graph(pn.upload(first), r["prompt"], 20264001, "char3d/restyle_" + name)
                for i, ref in enumerate(r["refs"] if r["base"] else []):
                    node = str(20 + i)
                    graph[node] = {"class_type": "LoadImage", "inputs": {"image": pn.upload(REFS / ref)}}
                    graph["5"]["inputs"]["images.image_%d" % (i + 2)] = [node, 0]
                pn.generate(graph, front)
                prep.prep(front, front.with_name("front_prep.png"))
            elif stage == "backs":
                graph = img_edit.graph(pn.upload(front), img_edit.EDITS["back"] + r["back"], 20265001, "char3d/restyle_" + name + "_rear")
                graph["4"]["inputs"]["device"] = "off"
                pn.generate(graph, back)
                prep.prep(back, back.with_name("back_prep.png"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
