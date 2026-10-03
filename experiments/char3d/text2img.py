"""Текст -> картинка в ComfyUI. Два движка, выбор — text2img.engine в settings.json.

    python text2img.py <субъект из data/subjects.json> [число вариантов] [движок]

- wan  — уже скачанная Wan 2.2 TI2V 5B: видео длиной в один кадр = картинка;
- qwen — Qwen-Image 2.1 (некоммерческая лицензия), DiT в GGUF.
Размер кадра задаёт движок (у каждого свой родной), субъект — только форму
кадра (portrait/square). Варианты отличаются зерном (seed + i), чтобы любой
можно было повторить. Результат: out/<субъект>/<движок>_<i>.png и CSV
температуры за прогон.
"""
import json
import sys
from pathlib import Path

import comfy

HERE = Path(__file__).parent
S = json.loads((HERE / "data" / "settings.json").read_text(encoding="utf-8"))["text2img"]
SUBJECTS = json.loads((HERE / "data" / "subjects.json").read_text(encoding="utf-8"))


def _texts(subject):
    sub = SUBJECTS[subject]
    neg = SUBJECTS["negative"] + (", " + sub["negative_extra"] if sub.get("negative_extra") else "")
    return sub["prompt"], neg, sub["frame"]


def wan_graph(subject, seed, prefix):
    E = S["wan"]
    pos, neg, frame = _texts(subject)
    w, h = E["frames"][frame]
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": E["unet"], "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": E["text_encoder"], "type": "wan"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": E["vae"]}},
        "4": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["1", 0], "shift": E["shift"]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": pos}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": neg}},
        "7": {"class_type": "Wan22ImageToVideoLatent", "inputs": {
            "vae": ["3", 0], "width": w, "height": h, "length": 1, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": E["steps"], "cfg": E["cfg"], "sampler_name": E["sampler"],
            "scheduler": E["scheduler"], "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }


def qwen_graph(subject, seed, prefix):
    """Граф шаблона image_qwen_image_2_1_t2i без переписчика промптов."""
    E = S["qwen"]
    pos, neg, frame = _texts(subject)
    w, h = E["frames"][frame]
    return {
        "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": E["unet"]}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": E["text_encoder"], "type": "qwen_image"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": E["vae"]}},
        "4": {"class_type": "QwenImage21Cache", "inputs": {"model": ["1", 0], "device": "auto", "dtype": "default"}},
        "5": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "prompt": pos, "negative_prompt": neg, "resolution": 1024}},
        "7": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["4", 0], "positive": ["5", 0], "negative": ["5", 1], "latent_image": ["7", 0],
            "seed": seed, "steps": E["steps"], "cfg": E["cfg"], "sampler_name": E["sampler"],
            "scheduler": E["scheduler"], "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }


GRAPHS = {"wan": wan_graph, "qwen": qwen_graph}


def main(subject, n=None, engine=None):
    engine = engine or S["engine"]
    out = HERE / "out" / subject
    out.mkdir(parents=True, exist_ok=True)
    n = int(n or S["variants"])
    log = out / f"gpu_text2img_{engine}.csv"
    with comfy.guarded(log):
        for i in range(n):
            outputs, sec = comfy.run(GRAPHS[engine](subject, S["seed"] + i, f"char3d/{subject}_{engine}_{i}"))
            src = comfy.fetch(outputs, out)[0]
            dst = out / f"{engine}_{i}.png"
            src.replace(dst)
            print(f"{dst.name}: {sec:.0f} с")
    t, mem = comfy.gpu_peak(log)
    print(f"видеокарта: максимум {t} °C, {mem} МиБ")


if __name__ == "__main__":
    main(*sys.argv[1:])
