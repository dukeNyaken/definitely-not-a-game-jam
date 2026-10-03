"""Rebuild the four prologue NPCs from their captured original designs.

Run with the Comfy portable Python: prologue_npcs.py images|backs|meshes [id ...].
Intermediate assets stay under output/prologue_npcs; only reviewed exports
belong in assets/characters/npcs. Clothing is part of the body mesh.
"""
import json
import sys
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy
import img_edit
import img2mesh
import prep

HERE = Path(__file__).resolve().parent
OUT = HERE / "output" / "prologue_npcs"
DESIGNS = {
    "young_brother": "Young adult Nordic man, clean shaven, short dark brown hair, ivory linen long sleeved shirt, dark brown simple belt, brown trousers, brown leather boots. No armor, no crown.",
    "father": "Elderly Nordic jarl, bald crown with gray hair at sides, long white beard down his chest, simple thin silver circlet. Muted dark teal gray ankle length robe, dark brown leather belt, wide gray taupe fur shoulder mantle and long gray taupe fur cape down his back. Brown boots.",
    "beloved": "Young adult Nordic woman, pale skin, blonde hair in ONE long braid down her BACK tied with crimson ribbon. Thin silver circlet with small red gem at forehead. Crimson red long sleeved ankle length dress, dark brown fitted leather waist cincher, brown shoes.",
    "faithful": "Young adult Nordic woman, warm pale skin, ochre brown headscarf covering her hair except a brown fringe, modest muted blue gray long sleeved ankle length dress, cream rectangular apron at FRONT, brown leather crossbody strap and small satchel on her hip, brown shoes.",
    # Остальные люди сюжетных сцен: тот же конвейер, референсы снимает npc_refs.gd.
    "friend": "Adult Nordic warrior man, short dark brown hair, short dark brown beard, linen bandage around his forehead with a small blood stain. Ochre tan quilted gambeson with vertical quilting seams, long sleeves, linen bandage strip diagonally across his chest, linen bandage wrapped around his left forearm, dark brown leather belt, gambeson skirt to mid thigh. Dark gray brown trousers, brown leather boots.",
    "refugee": "Thin Nordic teenage boy, about fifteen years old, messy tousled light brown hair, small bruise on his cheek. Ragged short sleeved light brown tunic to mid thigh with frayed hem, pale rope belt, ragged dark gray brown knee length trousers, bare shins and BAREFOOT.",
    "captain": "Adult Nordic guard captain, short brown beard. Polished steel kettle hat helmet with wide brim and short red plume. Polished steel breastplate, rounded steel pauldrons, narrow black tabard panel with one vertical gold stripe down the front of the breastplate and down the waist skirt, steel plated waist skirt. Dark crimson long sleeves and trousers, linen bandage on his left forearm, dark leather boots, sword in brown leather scabbard hanging at his left hip.",
    "widow": "Young adult Nordic woman, pale tired sad face. Dark plum gray wool shawl covering her head and hair and draped over her shoulders and upper chest, dark plum gray long sleeves, darker brown bodice, plain brown ankle length wool dress, brown shoes.",
    "smith": "Old burly Nordic blacksmith, bald head, bushy gray eyebrows, thick gray moustache and short gray beard. Big muscular BARE arms, leather bracer on his right forearm. Dark charcoal sleeveless tunic, long brown leather apron from chest to knees, wide brown leather belt, dark gray trousers, heavy dark brown boots, iron smithing hammer hanging at his right hip.",
    "novice": "Young Nordic man, healer's apprentice, light brown hair, clean shaven. Warm brown ankle length hooded wool robe with the hood UP over his head, face visible, long wide sleeves follow his straight arms down to the wrists, pale rope belt, brown leather strap diagonally across his chest, small leather satchel with green herbs at his left hip, brown shoes.",
    "mother": "Elderly Nordic woman, Solveig's mother, kind tired lined face, gray hair mostly hidden under a white linen coif head covering with gray strands at the temples. Muted dark green gray long sleeved ankle length wool dress, faded crimson wool shawl over her shoulders and chest, cream apron at FRONT, small bunch of brass keys hanging at her right hip, brown shoes.",
    # Человекоподобные враги: тела в assets/characters/enemies, оружие — отдельными предметами.
    # Не люди: рой — бес на четырёх лапах (снят сбоку), у слизня генерируется только череп внутри куба.
    "swarm": "Small demonic imp creature on four short legs, deathly pale sickly green hide, two curved bone horns, wide mouth with small white fangs, glowing yellow eyes, row of white bone spikes along its spine, one short thick tail growing from its rump, every body part connected, no floating pieces.",
    "slime_skull": "A single yellowed human skull, dark empty eye sockets with a faint green glow inside, cracked cranium, upper teeth, no lower jaw.",
    "infantry": "Undead foot soldier, gaunt gray green corpse skin, sunken cheeks, slack open jaw, small glowing green eyes. HUGE oversized rusty iron kettle hat helmet, twice normal size, very wide flat brim wider than his shoulders, tall conical crown with a short spike on top. Rusty gray chainmail shirt with short sleeves and chainmail leggings, tattered blood red tabard hanging front and back, brown leather belt, bare corpse forearms, worn tan leather boots.",
    "archer": "Undead skeleton crossbowman: bare off white bone skeleton with visible ribcage, spine, pelvis, thin bone arms and legs, skull with dark eye sockets and tiny red glowing eyes. Tall pointed ragged gray brown hood over the skull, tattered gray brown cloak hanging down his back, leather quiver strap.",
    "brute": "Huge hulking executioner, pale gray white skin, enormous muscular bare chest, shoulders and arms, thick neck, small head under a pointed brown leather executioner hood with red glowing eye holes. Bloodstained brown leather apron from chest to knees, wide leather belt, leather bracers on both forearms, pale bare legs, heavy brown leather boots, bone spikes growing from his upper back.",
    "caster": "Sinister cultist sorcerer, ragged crimson red ankle length robe with wide sleeves, tall pointed dark crimson hood, white bone plague doctor beak mask with glowing orange eyes, narrow gold vertical stripe down the front of the robe, short dark red shoulder cape, bony pale gray hands.",
    "jester": "Stocky dwarf jester with short legs and a big head, white porcelain mask with a wide crooked grin, black diamond eye holes and a long pointed nose. Three horned jester cap with gold bells, horns alternating red and black. Puffy doublet split vertically half red half black with gold diamond buttons, white and red ruff collar, one red leg and one black leg, black pointed curled shoes with gold bells, leather belt.",
}
FRONT = """Redesign this primitive placeholder as a finished early PlayStation 2 low polygon fantasy game character model. Preserve the character's existing clothing design and colors. Replace block primitives with continuous anatomically believable human body and detailed painted face. {design} Clothing is integrated into the character, fully dressed. Full body FRONT orthographic view, straight symmetrical A pose, arms straight diagonally down 40 degrees away from body, hands open and clearly separated from clothing, feet flat slightly apart pointing forward. Straight back. Long garments end above shoes so both shoes are visible. Natural adult proportions, realistic modest face, no chibi. Low polygon angular silhouette with hand painted texture detail. Flat uniform medium gray background, soft even neutral illumination, NO cast shadow, no floor, no text, no accessories held in either hand, no weapons, no staff, no lantern. Whole figure centered with margin above head and below feet, single character only."""
# Перегенерация неудачной картинки: другой сид без правки описания, (id, вид) -> сдвиг.
RESEED = {("novice", "front"): 1, ("novice", "back"): 2, ("swarm", "front"): 1}
# Шаблоны не для людей: существо — строго сбоку мордой вправо (второй бок — зеркало),
# предмет — сам по себе спереди.
CREATURE = """Redesign this primitive placeholder as a finished early PlayStation 2 low polygon fantasy game creature model. {design} Exact SIDE profile orthographic view, head pointing to the RIGHT, standing on all four legs, legs straight and clearly separated, tail visible. Natural creature anatomy, low polygon angular silhouette with hand painted texture detail. Flat uniform medium gray background, soft even neutral illumination, NO cast shadow, no floor, no text. Whole creature centered, filling most of the frame width with margin, single creature only."""
OBJECT = """Replace everything in this image with one isolated object: {design} Early PlayStation 2 low polygon game prop with hand painted texture. Straight FRONT orthographic view, centered, filling half of the frame. Flat uniform medium gray background, soft even neutral illumination, NO cast shadow, no floor, no text, nothing else in the image."""
TEMPLATE = {"swarm": CREATURE, "slime_skull": OBJECT}
BACK = """Show exactly this same character from directly BEHIND. Rotate character 180 degrees around vertical axis. Exact same framing, body proportions, standing symmetrical A pose, arms and feet position, outfit, palette and scale. {design} View back of head, back of shoulders and back of boots, never face. Preserve silhouette of the front reference. Flat uniform medium gray background, no ground shadow, no floor, no text, no handheld objects. Early PlayStation 2 low polygon game model with hand painted textures."""


def upload(path):
    """Use Comfy's upload endpoint so input does not depend on its install path."""
    path = Path(path)
    boundary = uuid.uuid4().hex
    name = "prologue_" + path.parent.name + "_" + path.name
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()
            + path.read_bytes() + f'\r\n--{boundary}--\r\n'.encode())
    req = urllib.request.Request(comfy.HOST + "/upload/image", data=body,
        headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)["name"]


def generate(graph, dst):
    (dst.parent / (dst.stem + "_graph.json")).write_text(json.dumps(graph, indent=2), encoding="utf-8")
    outputs, seconds = comfy.run(graph)
    files = comfy.fetch(outputs, dst.parent)
    source = next(p for p in files if p.suffix == dst.suffix)
    if source != dst:
        source.replace(dst)
    print(f"DONE {dst}: {seconds:.0f}s", flush=True)


def main(stage, ids):
    OUT.mkdir(parents=True, exist_ok=True)
    with comfy.guarded(OUT / (stage + "_gpu.csv")):
        for index, name in enumerate(ids or DESIGNS):
            folder = OUT / name
            folder.mkdir(exist_ok=True)
            front, back = folder / "front.png", folder / "back.png"
            if stage == "images":
                for dst, src, instruction in (
                    (front, HERE / "references" / "prologue" / (name + "_front.png"), FRONT),
                ):
                    if not dst.exists():
                        print(f"START {name} {dst.stem}", flush=True)
                        graph = img_edit.graph(upload(src), TEMPLATE.get(name, instruction).format(design=DESIGNS[name]),
                            20261003 + list(DESIGNS).index(name) + 1000 * RESEED.get((name, "front"), 0), "char3d/prologue_" + name + "_" + dst.stem)
                        generate(graph, dst)
                    prep.prep(dst, dst.with_name(dst.stem + "_prep.png"))
            elif stage == "meshes":
                dst = folder / "raw.glb"
                if not dst.exists():
                    print(f"START {name} mesh", flush=True)
                    generate(img2mesh.graph(upload(folder / "front_prep.png"), "char3d/prologue_" + name), dst)
            elif stage == "backs" and TEMPLATE.get(name) == CREATURE:
                # существо симметрично: второй бок — зеркало первого
                from PIL import Image, ImageOps
                ImageOps.mirror(Image.open(front)).save(back)
                prep.prep(back, back.with_name("back_prep.png"))
            elif stage == "backs":
                prompt = img_edit.EDITS["back"]
                if name == "father":
                    prompt += " The back is covered by his long gray taupe fur cloak. The back of his bald head has gray hair at sides, no face or beard visible."
                elif name == "beloved":
                    prompt += " Show one blonde braid down the center of her back, tied at end with a crimson ribbon."
                elif name == "faithful":
                    prompt += " Show her ochre headscarf from behind and the back of her blue gray dress with cream apron ties. No apron panel on back."
                elif name == "captain":
                    prompt += " Show the back of his steel helmet and breastplate, the black tabard panel on his back, the scabbard on his left hip, which from behind is on the left side of the image."
                elif name == "widow":
                    prompt += " Her dark shawl covers the back of her head and shoulders."
                elif name == "smith":
                    prompt += " Show the back of his bald head, apron straps crossing his back over the charcoal tunic."
                elif name == "mother":
                    prompt += " Show the white coif covering the back of her head and the crimson shawl over her back, apron ties at the waist. No apron panel on back."
                elif name == "infantry":
                    prompt += " Show the back of his huge wide brimmed kettle hat and the red tabard on his back."
                elif name == "archer":
                    prompt += " His tattered gray brown cloak and pointed hood cover his back; bone legs and arms visible."
                elif name == "brute":
                    prompt += " Show his broad muscular pale back with bone spikes, apron ties and the back of the leather hood."
                elif name == "caster":
                    prompt += " Show the back of his tall pointed crimson hood, short cape and robe."
                elif name == "jester":
                    prompt += " Show the back of his three horned cap, the doublet halves swapped sides from behind."
                elif name == "novice":
                    prompt += " Show the back of his raised hood covering the back of his head, the back of his plain brown robe, satchel strap crossing his back. Plain flat gray background."
                graph = img_edit.graph(upload(front), prompt, 20262003 + list(DESIGNS).index(name) + 1000 * RESEED.get((name, "back"), 0), "char3d/prologue_" + name + "_rear")
                graph["4"]["inputs"]["device"] = "off"
                generate(graph, back)
                prep.prep(back, back.with_name("back_prep.png"))
            else:
                raise ValueError(stage)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
