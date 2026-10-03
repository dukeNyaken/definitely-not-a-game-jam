"""Сторож видеокарты на время генерации в ComfyUI.

Опрашивает nvidia-smi и, если температура держится выше порога два замера
подряд, шлёт ComfyUI /interrupt — счёт обрывается, память освобождается.
Два замера подряд нужны, чтобы одиночный выброс датчика не гасил генерацию.

Запуск:  python gpu_guard.py [--limit 85] [--warn 80] [--poll 2] [--max-idle 120]
Выход:   0 — очередь опустела сама, 2 — прервал по нагреву.
"""
import argparse, json, subprocess, sys, time, urllib.request
from datetime import datetime

p = argparse.ArgumentParser()
p.add_argument("--limit", type=float, default=85.0)
p.add_argument("--warn", type=float, default=80.0)
p.add_argument("--poll", type=float, default=2.0)
p.add_argument("--max-idle", type=float, default=120.0, help="сек простоя до выхода")
p.add_argument("--host", default="http://127.0.0.1:8188")
p.add_argument("--log", default="gpu_guard.csv")
a = p.parse_args()

Q = "--query-gpu=temperature.gpu,power.draw,utilization.gpu,memory.used"
SMI = ["nvidia-smi", Q, "--format=csv,noheader,nounits"]


def read():
    out = subprocess.run(SMI, capture_output=True, text=True, timeout=10).stdout.strip()
    t, w, u, m = (x.strip() for x in out.split(","))
    return float(t), float(w), int(u), int(m)


def busy():
    with urllib.request.urlopen(f"{a.host}/queue", timeout=5) as r:
        q = json.load(r)
    return len(q["queue_running"]) + len(q["queue_pending"])


def interrupt():
    req = urllib.request.Request(f"{a.host}/interrupt", data=b"", method="POST")
    urllib.request.urlopen(req, timeout=5).read()
    # очередь тоже чистим: иначе следующая задача стартует сразу и снова нагреет
    req = urllib.request.Request(f"{a.host}/queue", data=json.dumps({"clear": True}).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    urllib.request.urlopen(req, timeout=5).read()


log = open(a.log, "w", encoding="utf-8")
log.write("время,температура,ватт,загрузка,память\n")

hot = 0
idle = 0.0
silent = 0.0          # сколько секунд подряд ComfyUI не отвечает
seen_job = False
tmax = wmax = 0.0
start = time.time()
warned = False
print(f"сторож: порог {a.limit}°C, опрос раз в {a.poll} с")

while True:
    t, w, u, m = read()
    tmax, wmax = max(tmax, t), max(wmax, w)
    log.write(f"{datetime.now():%H:%M:%S},{t},{w},{u},{m}\n")
    log.flush()

    if t >= a.limit:
        hot += 1
        if hot >= 2:
            interrupt()
            print(f"ПРЕРВАНО: {t}°C два замера подряд (порог {a.limit})")
            print(f"максимум за прогон: {tmax}°C, {wmax} Вт")
            log.close()
            sys.exit(2)
    else:
        hot = 0
        if t >= a.warn and not warned:
            print(f"внимание: {t}°C (порог прерывания {a.limit})")
            warned = True

    try:
        n = busy()
        silent = 0.0
    except Exception:
        # Сервер молчит — это НЕ пустая очередь. MiniMax H3 забивает оперативку
        # почти до конца, ComfyUI на время загрузки моделей перестаёт отвечать,
        # и прежнее «ошибка = пусто» уводило сторожа через 20 с, бросая
        # температуру без присмотра. Ждём и мерим дальше; сдаёмся, только если
        # сервер молчит дольше a.max_idle.
        silent += a.poll
        if silent >= max(a.max_idle, 300):
            print(f"ComfyUI не отвечает {silent:.0f} с — сторож уходит")
            break
        time.sleep(a.poll)
        continue
    if n:
        seen_job, idle = True, 0.0
    else:
        idle += a.poll
        if seen_job and idle >= 20:
            break
        if not seen_job and idle >= a.max_idle:
            print("очередь пуста, работы не дождался")
            break

    time.sleep(a.poll)

mins = (time.time() - start) / 60
print(f"готово за {mins:.1f} мин; максимум {tmax}°C, {wmax} Вт; лог: {a.log}")
log.close()
