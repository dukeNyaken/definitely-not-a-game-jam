"""DWPose по исходной картинке тела: точки суставов для rig.py.

    D:/AI/ComfyUI_windows_portable/python_embeded/python.exe keypoints.py <картинка.png>

Пишет <картинка>_pose.json: 24 точки (тело 0-17 в порядке OpenPose, стопы
18-23: левые носок, мизинец, пятка, потом правые) — [x, y, уверенность]
в точках исходной картинки. «Левая» — левая сторона самого человека.
Детектор берётся из comfyui_controlnet_aux, модели там уже лежат; считает
на процессоре — одна картинка, секунды.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

AUX = "D:/AI/ComfyUI_windows_portable/ComfyUI/custom_nodes/comfyui_controlnet_aux/src"


def main(path):
    sys.path.insert(0, AUX)
    from custom_controlnet_aux.dwpose import DwposeDetector
    det = DwposeDetector.from_pretrained(
        "hr16/DWPose-TorchScript-BatchSize5", "yzd-v/DWPose",
        det_filename="yolox_l.onnx", pose_filename="dw-ll_ucoco_384_bs5.torchscript.pt",
        torchscript_device="cpu")
    rgb = np.array(Image.open(path).convert("RGB"))
    k = det.dw_pose_estimation(rgb.copy())
    if k is None or len(k) == 0:
        sys.exit("DWPose не нашёл человека")
    best = k[int(np.argmax([(q[:24, 2] > 0.3).sum() for q in k]))][:24]
    out = Path(path).with_name(Path(path).stem + "_pose.json")
    out.write_text(json.dumps(best.tolist()))
    weak = [i for i, p in enumerate(best) if p[2] < 0.3]
    # угол руки (плечо -> запястье) от вертикали: у А-позы ~45, у Т-позы 90,
    # руки по швам ~10. Скелет rig.py этого не требует, но поза входной
    # картинки задаёт позу покоя модели — по углу видно, годится ли картинка.
    ang = [abs(np.degrees(np.arctan2(best[w][0] - best[s][0], best[w][1] - best[s][1]))) for s, w in ((5, 7), (2, 4))]
    print(f"{out.name}: людей {len(k)}, точек с уверенностью < 0.3: {weak or 'нет'}; "
          f"руки от вертикали: левая {ang[0]:.0f}°, правая {ang[1]:.0f}°")


if __name__ == "__main__":
    main(sys.argv[1])
