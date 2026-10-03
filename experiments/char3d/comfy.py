"""Разговор с ComfyUI по HTTP: поставить граф, дождаться, забрать файлы.

Только стандартная библиотека — запускается любым питоном, ComfyUI при этом
работает отдельным процессом (порт 8188). Графы собирают text2img.py и
img2mesh.py; здесь нет ни одного знания о моделях.
"""
import contextlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

# Консоль Windows по умолчанию в cp1252: русский вывод роняет скрипт, а упавший
# сторож температуры оставляет генерацию без присмотра (так и случилось 2 октября).
sys.stdout.reconfigure(encoding="utf-8")
GUARD_ENV = {**os.environ, "PYTHONIOENCODING": "utf-8"}

HOST = "http://127.0.0.1:8188"
COMFY_DIR = Path(r"D:\AI\ComfyUI_windows_portable\ComfyUI")


def _get(path):
    with urllib.request.urlopen(HOST + path, timeout=30) as r:
        return json.load(r)


def _post(path, payload):
    req = urllib.request.Request(HOST + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def upload(image_path):
    """Кладёт картинку в input ComfyUI (копией — так проще, чем multipart)."""
    dst = COMFY_DIR / "input" / Path(image_path).name
    shutil.copyfile(image_path, dst)
    return dst.name


def run(graph, timeout=1800):
    """Ставит граф и ждёт конца. Возвращает (outputs, секунды)."""
    res = _post("/prompt", {"prompt": graph, "client_id": "char3d-" + uuid.uuid4().hex[:8]})
    if res.get("node_errors"):
        raise RuntimeError(json.dumps(res["node_errors"], ensure_ascii=False, indent=1))
    pid = res["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < timeout:
        h = _get("/history/" + pid)
        if pid in h:
            st = h[pid].get("status", {})
            if st.get("status_str") == "error":
                msgs = [m for m in st.get("messages", []) if m[0] == "execution_error"]
                raise RuntimeError(json.dumps(msgs, ensure_ascii=False, indent=1)[:3000])
            if st.get("completed", True):
                return h[pid]["outputs"], time.time() - t0
        time.sleep(2)
    raise TimeoutError(f"ComfyUI не закончил за {timeout} с")


def fetch(outputs, dest_dir):
    """Копирует все выходные файлы графа (картинки и 3D) в dest_dir."""
    dest_dir = Path(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)
    got = []
    for node_out in outputs.values():
        for key in ("images", "3d", "meshes", "files"):
            for f in node_out.get(key, []) or []:
                if not isinstance(f, dict) or "filename" not in f:
                    continue
                q = urllib.parse.urlencode({"filename": f["filename"], "subfolder": f.get("subfolder", ""),
                                            "type": f.get("type", "output")})
                dst = dest_dir / f["filename"]
                with urllib.request.urlopen(f"{HOST}/view?{q}", timeout=120) as r:
                    dst.write_bytes(r.read())
                got.append(dst)
    return got


@contextlib.contextmanager
def guarded(log_path):
    """Сторож температуры на время работы: gpu_guard.py рвёт счёт на 85 °C.

    Лог температуры (CSV) ложится рядом с результатом — по нему видно максимум.
    """
    g = subprocess.Popen([sys.executable, str(Path(__file__).with_name("gpu_guard.py")),
                          "--limit", "85", "--log", str(log_path), "--max-idle", "600"], env=GUARD_ENV)
    time.sleep(3)
    if g.poll() is not None:
        raise RuntimeError("сторож температуры не запустился — генерацию не начинаю")
    try:
        yield
    finally:
        g.terminate()


def gpu_peak(log_path):
    """Максимумы из лога сторожа: (°C, МиБ памяти)."""
    rows = Path(log_path).read_text(encoding="utf-8").splitlines()[1:]
    vals = [r.split(",") for r in rows if r.count(",") == 4]
    if not vals:
        return None, None
    return max(float(v[1]) for v in vals), max(int(v[4]) for v in vals)
