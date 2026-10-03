"""Точечная правка вещи в готовом glb персонажа: скелет, скин и анимации не трогаются.

    python swap_item.py replace <персонаж.glb> <сетка вещи> <новая.glb> [size=1.1]
    python swap_item.py scale   <персонаж.glb> <сетка вещи> [length=1.2] [thick=2.0]
    python swap_item.py fit_gloves <персонаж.glb> [clearance=1.7]

Исходников вещей (output/char3d/item_*) может не быть на этой машине, а прогон
персонажа через Blender меняет оси костей — от них зависят сокеты рук. Поэтому
меняются только данные одной сетки (node с именем вещи, например item_shield):

- replace — новая сетка (glb из bake.py ... item: лицо в +Z, верх +Y) встаёт по раме
  старой: длинная ось старой — вверх новой, тонкая — нормаль лица наружу от тела
  (от оси Y персонажа), центр — в центр старой; высота — size × длина старой.
  Вся вещь привязана к главной кости старой (вес 1), текстура — новая.
- scale — та же сетка: от рукояти (конец длинной оси у главной кости) длиннее в
  length раз, поперёк — в thick раз толще (меч-«зубочистка»).
- fit_gloves — посадка пары по ладоням в координатах привязки кистей;
  лишние скрытые грани предплечья возвращаются в постоянно видимое тело.

Вершины скинованной сетки в glTF — в позе привязки в пространстве сцены, поэтому
рама считается прямо по ним. Старые данные остаются в буфере неиспользуемыми.
"""
import copy
import json
import struct
import sys
from pathlib import Path

import numpy as np

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        data = Path(path).read_bytes()
        n = struct.unpack_from("<I", data, 12)[0]
        self.json = json.loads(data[20:20 + n])
        off = 20 + n
        blen = struct.unpack_from("<I", data, off)[0]
        self.bin = bytearray(data[off + 8:off + 8 + blen])

    def read(self, acc_i):
        a = self.json["accessors"][acc_i]
        bv = self.json["bufferViews"][a["bufferView"]]
        dt = np.dtype(COMP[a["componentType"]])
        nc = NCOMP[a["type"]]
        stride = bv.get("byteStride", 0) or dt.itemsize * nc
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        raw = np.frombuffer(bytes(self.bin), dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * nc, offset=start)
        out = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * nc), strides=(stride, 1)).copy()
        return out.view(dt).reshape(a["count"], nc)

    def write(self, arr, kind, target=None):
        """Новый bufferView + accessor в конце буфера; возвращает индекс accessor."""
        while len(self.bin) % 4:
            self.bin.append(0)
        ct = {np.float32: 5126, np.uint16: 5123, np.uint32: 5125, np.uint8: 5121}[arr.dtype.type]
        bv = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": arr.nbytes}
        if target:
            bv["target"] = target
        self.bin += arr.tobytes()
        self.json["bufferViews"].append(bv)
        acc = {"bufferView": len(self.json["bufferViews"]) - 1, "componentType": ct, "count": len(arr), "type": kind}
        if kind == "VEC3" and arr.dtype == np.float32:
            acc["min"], acc["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        self.json["accessors"].append(acc)
        return len(self.json["accessors"]) - 1

    def image_bytes(self, img_i):
        bv = self.json["bufferViews"][self.json["images"][img_i]["bufferView"]]
        return bytes(self.bin[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])

    def save(self, path):
        self.json["buffers"][0]["byteLength"] = len(self.bin)
        js = json.dumps(self.json, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        while len(self.bin) % 4:
            self.bin.append(0)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(self.bin), 0x004E4942) + bytes(self.bin)
        Path(path).write_bytes(out)


def item(g, name):
    node = next(n for n in g.json["nodes"] if n.get("name") == name and "mesh" in n)
    return node, g.json["meshes"][node["mesh"]]


def main_joint(g, prim):
    j = g.read(prim["attributes"]["JOINTS_0"])
    w = g.read(prim["attributes"]["WEIGHTS_0"]).astype(np.float64)
    if w.max() > 1.5:   # нормированные целые
        w = w / np.iinfo(g.read(prim["attributes"]["WEIGHTS_0"]).dtype).max
    score = np.zeros(int(j.max()) + 1)
    np.add.at(score, j.ravel(), w.ravel())
    return int(score.argmax())


def frame(p):
    c = (p.min(0) + p.max(0)) / 2
    _, s, vt = np.linalg.svd(p - p.mean(0), full_matrices=False)
    return c, vt  # строки: длинная, средняя, тонкая


def replace(target, name, new_glb, size=1.1):
    g, n = Glb(target), Glb(new_glb)
    node, mesh = item(g, name)
    old = mesh["primitives"][0]
    p = g.read(old["attributes"]["POSITION"]).astype(np.float64)
    joint = main_joint(g, old)
    c, (a1, a2, a3) = frame(p)
    if a1[1] < 0:
        a1 = -a1
    out = np.array([c[0], 0.0, c[2]])          # от оси персонажа к вещи — наружу
    if np.dot(a3, out) < 0:
        a3 = -a3
    length = np.ptp((p - c) @ a1)
    np_ = n.json["meshes"][0]["primitives"][0]
    q = n.read(np_["attributes"]["POSITION"]).astype(np.float64)
    qn = n.read(np_["attributes"]["NORMAL"]).astype(np.float64)
    uv = n.read(np_["attributes"]["TEXCOORD_0"]).astype(np.float32)
    idx = n.read(np_["indices"]).ravel().astype(np.uint32)
    qc = (q.min(0) + q.max(0)) / 2
    s = size * length / np.ptp(q[:, 1])
    rot = np.stack([np.cross(a1, a3), a1, a3], axis=1)   # столбцы: куда идут X, Y, Z новой
    pos = (c + (s * (q - qc)) @ rot.T).astype(np.float32)
    nor = (qn @ rot.T).astype(np.float32)
    joints = np.zeros((len(pos), 4), np.uint16)
    joints[:, 0] = joint
    weights = np.zeros((len(pos), 4), np.float32)
    weights[:, 0] = 1.0
    # текстура новой вещи — картинкой в буфер персонажа
    img = n.image_bytes(n.json["textures"][n.json["materials"][np_["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"])
    while len(g.bin) % 4:
        g.bin.append(0)
    g.json["bufferViews"].append({"buffer": 0, "byteOffset": len(g.bin), "byteLength": len(img)})
    g.bin += img
    g.json.setdefault("images", []).append({"bufferView": len(g.json["bufferViews"]) - 1, "mimeType": "image/png", "name": name + "_tex"})
    g.json.setdefault("samplers", []).append({"magFilter": 9728, "minFilter": 9728})
    g.json.setdefault("textures", []).append({"source": len(g.json["images"]) - 1, "sampler": len(g.json["samplers"]) - 1})
    g.json["materials"].append({"name": name, "pbrMetallicRoughness": {"baseColorTexture": {"index": len(g.json["textures"]) - 1}, "metallicFactor": 0.0, "roughnessFactor": 0.9}})
    mesh["primitives"] = [{"attributes": {
        "POSITION": g.write(pos, "VEC3", 34962), "NORMAL": g.write(nor, "VEC3", 34962),
        "TEXCOORD_0": g.write(uv, "VEC2", 34962), "JOINTS_0": g.write(joints, "VEC4", 34962),
        "WEIGHTS_0": g.write(weights, "VEC4", 34962)},
        "indices": g.write(idx, "SCALAR", 34963), "material": len(g.json["materials"]) - 1}]
    g.save(target)
    print(f"REPLACE {target} {name}: {len(pos)} вершин, длина {length:.2f} -> {np.ptp((pos - c) @ a1):.2f} м, кость {joint}")


def scale(target, name, length=1.2, thick=2.0):
    g = Glb(target)
    node, mesh = item(g, name)
    for prim in mesh["primitives"]:
        p = g.read(prim["attributes"]["POSITION"]).astype(np.float64)
        nrm = g.read(prim["attributes"]["NORMAL"]).astype(np.float64)
        joint = main_joint(g, prim)
        skin = next(s for s in g.json["skins"] if node.get("skin") is not None and s is g.json["skins"][node["skin"]])
        ibm = g.read(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)   # glTF — по столбцам
        hand = np.linalg.inv(ibm[joint])[:3, 3]
        mean = p.mean(0)
        _, _, vt = np.linalg.svd(p - mean, full_matrices=False)
        a = vt[0]
        t = (p - mean) @ a
        grip = mean + a * (t.min() if abs(t.min() - (hand - mean) @ a) < abs(t.max() - (hand - mean) @ a) else t.max())
        along = (p - grip) @ a
        perp = (p - mean) - np.outer((p - mean) @ a, a)
        newp = grip + np.outer(along * length, a) + perp * thick + (mean - grip - a * ((mean - grip) @ a))
        nn = np.outer((nrm @ a) / length, a) + (nrm - np.outer(nrm @ a, a)) / thick
        nn /= np.linalg.norm(nn, axis=1, keepdims=True)
        prim["attributes"]["POSITION"] = g.write(newp.astype(np.float32), "VEC3", 34962)
        prim["attributes"]["NORMAL"] = g.write(nn.astype(np.float32), "VEC3", 34962)
        print(f"SCALE {target} {name}: длина {np.ptp(t):.2f} -> {np.ptp(along) * length:.2f} м, толще в {thick}, рукоять у кости {joint}")
    g.save(target)


def fit_gloves(target, clearance=1.7):
    """Посадить пару на кисти по их вершинам, исключая слабые веса туловища.

    Сравниваем рамки в позе привязки кисти: скин и анимации не меняются.
    Правка нужна, когда исходная посадка охватила предплечье вместо ладони.
    """
    g = Glb(target)
    body = next(n for n in g.json["nodes"] if n.get("name") == "hide_gloves")
    for node in g.json["nodes"]:
        if node.get("name") not in ("item_gloves_L", "item_gloves_R"):
            continue
        skin = g.json["skins"][node["skin"]]
        hand = "LeftHand" if node["name"].endswith("_L") else "RightHand"
        joint = next(i for i, n in enumerate(skin["joints"]) if g.json["nodes"][n]["name"] == hand)
        bind = g.read(skin["inverseBindMatrices"])[joint].reshape(4, 4).T.astype(np.float64)
        hand_points = []
        for primitive in g.json["meshes"][body["mesh"]]["primitives"]:
            a = primitive["attributes"]
            j, w = g.read(a["JOINTS_0"]), g.read(a["WEIGHTS_0"])
            mask = np.sum(np.where(j == joint, w, 0.0), axis=1) >= 0.8
            hand_points.append(g.read(a["POSITION"])[mask])
        points = np.concatenate(hand_points)
        if not len(points):
            raise ValueError(f"No palm vertices for {hand}")
        local_hand = (bind @ np.column_stack((points, np.ones(len(points)))).T).T[:, :3]
        target_center = (local_hand.min(0) + local_hand.max(0)) / 2
        target_size = np.ptp(local_hand, axis=0).max() * clearance
        mesh = g.json["meshes"][node["mesh"]]
        positions = [g.read(p["attributes"]["POSITION"]) for p in mesh["primitives"]]
        cloud = np.concatenate(positions)
        local = (bind @ np.column_stack((cloud, np.ones(len(cloud)))).T).T[:, :3]
        center = (local.min(0) + local.max(0)) / 2
        factor = min(1.0, target_size / np.ptp(local, axis=0).max())
        inverse = np.linalg.inv(bind)
        for primitive, pos in zip(mesh["primitives"], positions):
            transformed = (bind @ np.column_stack((pos, np.ones(len(pos)))).T).T[:, :3]
            transformed = (transformed - center) * factor + target_center
            fitted = (inverse @ np.column_stack((transformed, np.ones(len(pos)))).T).T[:, :3]
            primitive["attributes"]["POSITION"] = g.write(fitted.astype(np.float32), "VEC3", 34962)
        print(f"FIT {target} {node['name']}: scale={factor:.3f}, palm={target_center.round(3)}")
    # Исходная большая перчатка скрывала и предплечья. Возвращаем эти грани
    # в постоянно видимое тело; под перчатками прячутся только сами ладони.
    body_index = g.json["nodes"].index(body)
    body_skin = g.json["skins"][body["skin"]]
    hand_joints = [i for i, n in enumerate(body_skin["joints"]) if g.json["nodes"][n]["name"] in ("LeftHand", "RightHand")]
    hidden, exposed = [], []
    for primitive in g.json["meshes"][body["mesh"]]["primitives"]:
        a = primitive["attributes"]
        joints, weights = g.read(a["JOINTS_0"]), g.read(a["WEIGHTS_0"])
        hand_weight = np.sum(np.where(np.isin(joints, hand_joints), weights, 0.0), axis=1)
        triangles = g.read(primitive["indices"]).reshape(-1, 3)
        palm = np.all(hand_weight[triangles] >= 0.8, axis=1)
        for mask, output in [(palm, hidden), (~palm, exposed)]:
            if not np.any(mask):
                continue
            part = copy.deepcopy(primitive)
            part["indices"] = g.write(triangles[mask].reshape(-1, 1), "SCALAR", 34963)
            output.append(part)
    if not hidden:
        raise ValueError("No palm faces to hide under gloves")
    g.json["meshes"][body["mesh"]]["primitives"] = hidden
    if exposed:
        visible_mesh = len(g.json["meshes"])
        g.json["meshes"].append({"name": "body_glove_forearms", "primitives": exposed})
        visible_node = len(g.json["nodes"])
        g.json["nodes"].append({**body, "name": "body_glove_forearms", "mesh": visible_mesh})
        for parent in g.json["nodes"]:
            if body_index in parent.get("children", []):
                parent["children"].append(visible_node)
        for scene in g.json["scenes"]:
            if body_index in scene.get("nodes", []):
                scene["nodes"].append(visible_node)
    g.save(target)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    opts = {a.split("=")[0]: float(a.split("=")[1]) for a in sys.argv[2:] if "=" in a}
    pos = [a for a in sys.argv[2:] if "=" not in a]
    {"replace": replace, "scale": scale, "fit_gloves": fit_gloves}[sys.argv[1]](*pos, **opts)
