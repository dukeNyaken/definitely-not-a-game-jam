"""Доли и такты песни для музыкальной сцены: *.beats.json рядом с записью (его читает SongTrack).

    python tools/song_beats.py "assets/audio/evel_brother_musicle/Всё твоё — моё.wav" \
        14.0:112.0@65.98 117.7:132.1@119.40 156.4:209.8@188.18 216.0:219.7

Каждый аргумент — отрезок песни, где играет ритм: «начало:конец», после @ — секунда сильной доли
(начало такта), от которой такты отсчитываются по четыре доли. Без @ сильная — первая доля отрезка.
Вне отрезков долей нет: вступление на словах, паузы и «стоп» сцена играет без ритма.

У живой записи темп «плавает» (Suno), и равная сетка к концу куплета уходит с удара на десятки
миллисекунд. Поэтому доли ищутся трекером (librosa, динамическое программирование по силе атак),
а потом каждая притягивается к ближайшему удару ударных в окне ±45 мс. Нужны librosa и numpy.
"""
import json
import sys

import librosa
import numpy as np

SR = 22050
HOP = 128
SNAP = 0.045
BEATS_PER_BAR = 4


def spans(args):
    out = []
    for a in args:
        anchor = None
        if "@" in a:
            a, anchor = a.split("@")
            anchor = float(anchor)
        start, end = (float(x) for x in a.split(":"))
        out.append((start, end, anchor))
    return out


def main():
    wav = sys.argv[1]
    out_path = wav.rsplit(".", 1)[0] + ".beats.json"
    y, _ = librosa.load(wav, sr=SR, mono=True)
    onset = librosa.onset.onset_strength(y=y, sr=SR, hop_length=HOP)
    drums = librosa.onset.onset_strength(y=librosa.effects.percussive(y, margin=2.0), sr=SR, hop_length=HOP)
    n = min(len(onset), len(drums))
    onset, drums = onset[:n], drums[:n]
    t = librosa.frames_to_time(np.arange(n), sr=SR, hop_length=HOP)
    beats, bars, parts = [], [], []
    for start, end, anchor in spans(sys.argv[2:]):
        m = (t >= start - 0.5) & (t <= end + 0.5)
        tempo, frames = librosa.beat.beat_track(onset_envelope=onset[m], sr=SR, hop_length=HOP,
                                                start_bpm=147.0, tightness=300, trim=False)
        found = t[m][frames]
        found = found[(found >= start - 0.05) & (found <= end)]
        floor = np.median(drums[m]) * 2.0
        snapped = []
        for x in found:
            w = (t >= x - SNAP) & (t <= x + SNAP)
            i = int(np.argmax(drums[w]))
            snapped.append(float(t[w][i]) if drums[w][i] > floor else float(x))
        first = 0 if anchor is None else int(np.argmin(np.abs(np.array(snapped) - anchor)))
        for i, x in enumerate(snapped):
            beats.append(round(x, 3))
            if (i - first) % BEATS_PER_BAR == 0:
                bars.append(round(x, 3))
        parts.append({"from": start, "to": end, "bpm": round(float(np.atleast_1d(tempo)[0]), 2), "beats": len(snapped)})
        print("%7.2f–%7.2f: %3d долей, ~%.1f уд/мин" % (start, end, len(snapped), float(np.atleast_1d(tempo)[0])))
    data = {
        "source": wav.rsplit("/", 1)[-1],
        "comment": "Доли (beats) и сильные доли тактов (bars), с. Сделано tools/song_beats.py.",
        "parts": parts,
        "beats": beats,
        "bars": bars,
    }
    # Каждый ключ — своей строкой, массивы — в строку: файл читается глазами и не растягивается на сотни строк.
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("{\n" + ",\n".join(" %s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in data.items()) + "\n}\n")
    print("записано:", out_path)


if __name__ == "__main__":
    main()
