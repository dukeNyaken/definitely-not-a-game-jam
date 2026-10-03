"""Картинка (после prep.py) -> сетка через Hunyuan3D 2.1, встроенный в ComfyUI.

    python img2mesh.py <картинка_prep.png> [выход.glb]

Граф — шаблон ComfyUI 3d_hunyuan3d-v2.1, числа в settings.json/img2mesh.
Hunyuan в ComfyUI выдаёт только форму, без текстуры: цвет потом
проецируется с исходной картинки в Blender (bake.py).
Печатает число вершин и треугольников сырой сетки, время и нагрев.
"""
import json
import struct
import sys
from pathlib import Path

import comfy

HERE = Path(__file__).parent
S = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["img2mesh"]


def graph(image_name, prefix):
    return {
        "1": {"class_type": "ImageOnlyCheckpointLoader", "inputs": {"ckpt_name": S["checkpoint"]}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "3": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": S["shift"]}},
        "13": {"class_type": "CLIPVisionEncode", "inputs": {"clip_vision": ["1", 1], "image": ["2", 0], "crop": "center"}},
        "6": {"class_type": "Hunyuan3Dv2Conditioning", "inputs": {"clip_vision_output": ["13", 0]}},
        "4": {"class_type": "EmptyLatentHunyuan3Dv2", "inputs": {"resolution": S["latent_resolution"], "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {
            "model": ["3", 0], "positive": ["6", 0], "negative": ["6", 1], "latent_image": ["4", 0],
            "seed": S["seed"], "steps": S["steps"], "cfg": S["cfg"], "sampler_name": S["sampler"],
            "scheduler": S["scheduler"], "denoise": 1.0}},
        "8": {"class_type": "VAEDecodeHunyuan3D", "inputs": {
            "samples": ["7", 0], "vae": ["1", 2], "num_chunks": S["num_chunks"],
            "octree_resolution": S["octree_resolution"]}},
        "9": {"class_type": "VoxelToMesh", "inputs": {"voxel": ["8", 0], "algorithm": "surface net", "threshold": S["threshold"]}},
        "10": {"class_type": "SaveGLB", "inputs": {"mesh": ["9", 0], "filename_prefix": prefix}},
    }


def glb_counts(path):
    """Вершины и треугольники из заголовка glb — без Blender, по accessor'ам."""
    data = Path(path).read_bytes()
    jlen = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + jlen])
    verts = tris = 0
    for m in gltf["meshes"]:
        for p in m["primitives"]:
            verts += gltf["accessors"][p["attributes"]["POSITION"]]["count"]
            tris += gltf["accessors"][p["indices"]]["count"] // 3
    return verts, tris


def main(src, dst=None):
    src = Path(src)
    dst = Path(dst) if dst else src.with_name(src.stem.replace("_prep", "") + "_raw.glb")
    log = dst.with_suffix(".gpu.csv")
    name = comfy.upload(src)
    with comfy.guarded(log):
        outputs, sec = comfy.run(graph(name, f"char3d/{dst.stem}"))
    got = [f for f in comfy.fetch(outputs, dst.parent) if f.suffix == ".glb"]
    got[0].replace(dst)
    v, t = glb_counts(dst)
    temp, mem = comfy.gpu_peak(log)
    print(f"{dst.name}: {v} вершин, {t} треугольников, {dst.stat().st_size / 1e6:.1f} МБ; "
          f"{sec:.0f} с; видеокарта до {temp} °C, {mem} МиБ")


if __name__ == "__main__":
    main(*sys.argv[1:])
