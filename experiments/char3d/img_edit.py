"""Картинка -> картинка по инструкции: правка Qwen-Image 2.1 (некоммерческая лицензия).

    python img_edit.py <картинка.png> <правка из subjects.json/edits> [вариантов]

Граф — шаблон ComfyUI image_qwen_image_2_1_image_edit без переписчика промптов:
картинка уходит в TextEncodeQwenImage21 как опорная, латент берётся оттуда же —
он размером с опорную картинку (другой размер, по описанию узла, сдвигает правку,
а вид сзади должен лечь на ту же рамку).
Результат: <картинка>_<правка>_<i>.png рядом со входом.
"""
import json
import sys
from pathlib import Path

import comfy

HERE = Path(__file__).parent
S = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["text2img"]
EDITS = json.loads((HERE / "data" / "subjects.json").read_text(encoding="utf-8"))["edits"]


def graph(image_name, instruction, seed, prefix):
    E = S["qwen"]
    return {
        "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": E["unet"]}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": E["text_encoder"], "type": "qwen_image"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": E["vae"]}},
        "4": {"class_type": "QwenImage21Cache", "inputs": {"model": ["1", 0], "device": "auto", "dtype": "default"}},
        "6": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "5": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "vae": ["3", 0], "prompt": instruction, "negative_prompt": "",
            "resolution": 1024, "images.image_1": ["6", 0]}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["4", 0], "positive": ["5", 0], "negative": ["5", 1], "latent_image": ["5", 2],
            "seed": seed, "steps": E["steps"], "cfg": E["cfg"], "sampler_name": E["sampler"],
            "scheduler": E["scheduler"], "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }


def main(src, edit, n=1):
    src = Path(src)
    name = comfy.upload(src)
    log = src.with_name(f"gpu_edit_{edit}.csv")
    with comfy.guarded(log):
        for i in range(int(n)):
            outputs, sec = comfy.run(graph(name, EDITS[edit], S["seed"] + i, f"char3d/{src.stem}_{edit}_{i}"))
            got = comfy.fetch(outputs, src.parent)[0]
            dst = src.with_name(f"{src.stem}_{edit}_{i}.png")
            got.replace(dst)
            print(f"{dst.name}: {sec:.0f} с")
    t, mem = comfy.gpu_peak(log)
    print(f"видеокарта: максимум {t} °C, {mem} МиБ")


if __name__ == "__main__":
    main(*sys.argv[1:])
