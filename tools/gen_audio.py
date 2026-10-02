#!/usr/bin/env python3
"""Процедурная генерация всех звуков и музыки игры (только стандартная библиотека).

python3 tools/gen_audio.py            — всё
python3 tools/gen_audio.py sfx        — только эффекты
python3 tools/gen_audio.py music      — только музыка
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
TAU = math.tau
rng = random.Random(7)


# ---------------------------------------------------------------- базовое

def silence(sec):
    return [0.0] * int(sec * SR)


def n_samples(sec):
    return max(1, int(sec * SR))


def noise(sec, seed=None):
    r = random.Random(seed) if seed is not None else rng
    return [r.uniform(-1.0, 1.0) for _ in range(n_samples(sec))]


def osc(freq, sec, shape="sine", phase=0.0, freq_end=None, curve=1.0):
    """Осциллятор с опциональным свипом частоты."""
    n = n_samples(sec)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        if freq_end is None:
            f = freq
        else:
            k = (i / n) ** curve
            f = freq + (freq_end - freq) * k
        ph += f / SR
        p = ph % 1.0
        if shape == "sine":
            v = math.sin(TAU * p)
        elif shape == "square":
            v = 1.0 if p < 0.5 else -1.0
        elif shape == "saw":
            v = 2.0 * p - 1.0
        elif shape == "tri":
            v = 4.0 * abs(p - 0.5) - 1.0
        else:
            v = 0.0
        out[i] = v
    return out


def fm(carrier, ratio, index, sec, index_decay=4.0, freq_end=None):
    n = n_samples(sec)
    out = [0.0] * n
    pc = 0.0
    pm = 0.0
    for i in range(n):
        t = i / SR
        f = carrier if freq_end is None else carrier + (freq_end - carrier) * (i / n)
        pm += f * ratio / SR
        idx = index * math.exp(-index_decay * t)
        pc += f / SR
        out[i] = math.sin(TAU * pc + idx * math.sin(TAU * pm))
    return out


def env_exp(sig, decay, attack=0.002):
    n = len(sig)
    a = max(1, int(attack * SR))
    for i in range(n):
        g = math.exp(-decay * i / SR)
        if i < a:
            g *= i / a
        sig[i] *= g
    return sig


def env_adsr(sig, a, d, s, r):
    n = len(sig)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    for i in range(n):
        if i < na:
            g = i / max(na, 1)
        elif i < na + nd:
            g = 1.0 - (1.0 - s) * (i - na) / max(nd, 1)
        elif i < n - nr:
            g = s
        else:
            g = s * max(0.0, (n - i) / max(nr, 1))
        sig[i] *= g
    return sig


def env_swell(sig, peak=0.85):
    """Нарастание к peak (доля длины), потом быстрый спад."""
    n = len(sig)
    p = int(n * peak)
    for i in range(n):
        if i < p:
            g = (i / p) ** 2
        else:
            g = max(0.0, 1.0 - (i - p) / max(n - p, 1)) ** 0.5
        sig[i] *= g
    return sig


def lowpass(sig, cutoff, cutoff_end=None):
    out = [0.0] * len(sig)
    y = 0.0
    n = len(sig)
    for i, x in enumerate(sig):
        c = cutoff if cutoff_end is None else cutoff + (cutoff_end - cutoff) * (i / n)
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (x - y)
        out[i] = y
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, lp)]


def bandpass(sig, lo, hi, lo_end=None, hi_end=None):
    return lowpass(highpass_sweep(sig, lo, lo_end), hi, hi_end)


def highpass_sweep(sig, cutoff, cutoff_end=None):
    lp = lowpass(sig, cutoff, cutoff_end)
    return [x - l for x, l in zip(sig, lp)]


def gain(sig, g):
    return [x * g for x in sig]


def mix(*parts, length=None):
    """mix((signal, offset_sec, gain), ...)"""
    total = length if length is not None else 0
    for p in parts:
        s, off = p[0], p[1]
        total = max(total, int(off * SR) + len(s))
    out = [0.0] * total
    for p in parts:
        s, off = p[0], p[1]
        g = p[2] if len(p) > 2 else 1.0
        o = int(off * SR)
        for i, x in enumerate(s):
            j = o + i
            if j < total:
                out[j] += x * g
    return out


def add_into(buf, sig, offset_samples, g=1.0):
    n = len(buf)
    for i, x in enumerate(sig):
        j = offset_samples + i
        if j >= n:
            break
        buf[j] += x * g


def softclip(sig, drive=1.0):
    return [math.tanh(x * drive) for x in sig]


def normalize(sig, peak=0.9):
    m = max((abs(x) for x in sig), default=0.0)
    if m < 1e-9:
        return sig
    return [x * peak / m for x in sig]


def fade_out(sig, sec):
    n = len(sig)
    k = min(n, int(sec * SR))
    for i in range(k):
        sig[n - k + i] *= 1.0 - i / k
    return sig


def pluck(freq, sec, damping=0.996, bright=0.5, seed=1):
    """Струна Карплуса — Стронга."""
    r = random.Random(seed)
    period = max(2, int(SR / freq))
    buf = [r.uniform(-1, 1) for _ in range(period)]
    out = [0.0] * n_samples(sec)
    idx = 0
    for i in range(len(out)):
        cur = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = damping * (bright * cur + (1 - bright) * 0.5 * (cur + nxt))
        out[i] = cur
        idx = (idx + 1) % period
    return out


def bell(freq, sec, decay=3.0, partials=((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))):
    out = [0.0] * n_samples(sec)
    for ratio, amp in partials:
        s = osc(freq * ratio, sec)
        env_exp(s, decay * (1 + ratio * 0.35))
        for i, x in enumerate(s):
            out[i] += x * amp
    return out


def reverb(sig, wet=0.3, room=0.84, damp=0.4, tail=1.2):
    """Мини-Freeverb: 4 гребенчатых + 2 всепропускающих фильтра."""
    n = len(sig) + int(tail * SR)
    x = sig + [0.0] * (n - len(sig))
    combs = [1116, 1188, 1277, 1356]
    combs = [int(c * SR / 44100) for c in combs]
    out = [0.0] * n
    for c in combs:
        buf = [0.0] * c
        idx = 0
        filt = 0.0
        for i in range(n):
            y = buf[idx]
            filt = y * (1 - damp) + filt * damp
            buf[idx] = x[i] + filt * room
            idx = (idx + 1) % c
            out[i] += y * 0.25
    for a in (556, 441):
        a = int(a * SR / 44100)
        buf = [0.0] * a
        idx = 0
        for i in range(n):
            b = buf[idx]
            inp = out[i]
            o = -inp + b
            buf[idx] = inp + b * 0.5
            idx = (idx + 1) % a
            out[i] = o
    return [x[i] * (1 - wet) + out[i] * wet for i in range(n)]


def write(name, sig, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    sig = normalize(sig, peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in sig:
            v = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print("  ", name, "%.2fs" % (len(sig) / SR))


def note_freq(n):
    """MIDI-номер → частота."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


# ---------------------------------------------------------------- эффекты

def whoosh(sec, lo, hi, lo_end, hi_end, seed=None):
    s = bandpass(noise(sec, seed), lo, hi, lo_end, hi_end)
    return env_swell(s, 0.45)


def thud(freq=110, sec=0.25, end=45):
    s = osc(freq, sec, "sine", freq_end=end, curve=0.5)
    return env_exp(s, 14)


def metal(freq, sec, decay=9.0):
    return bell(freq, sec, decay, ((1, 1.0), (2.41, 0.7), (3.87, 0.5), (5.13, 0.35), (7.2, 0.2)))


def click(sec=0.02, freq=2400):
    s = osc(freq, sec)
    return env_exp(s, 220)


def sfx():
    print("SFX:")
    write("sword_swing", whoosh(0.2, 400, 1500, 1200, 5000))
    write("sword_hit", mix((whoosh(0.16, 500, 2000, 1500, 5000), 0, 0.6),
                           (env_exp(highpass(noise(0.08), 1500), 60), 0.04, 0.8),
                           (metal(820, 0.35, 14), 0.04, 0.5),
                           (thud(140, 0.2), 0.04, 0.9)))
    write("fist_swing", whoosh(0.14, 250, 900, 600, 2200), 0.6)
    write("fist_hit", mix((thud(120, 0.22, 50), 0, 1.0), (env_exp(lowpass(noise(0.07), 1800), 50), 0, 0.7)))
    write("block", mix((env_exp(highpass(noise(0.05), 2000), 80), 0, 0.8),
                       (metal(520, 0.6, 6), 0, 0.9),
                       (thud(160, 0.18), 0, 0.6)))
    write("shield_raise", mix((env_exp(lowpass(noise(0.12), 900), 30), 0, 0.8), (thud(210, 0.15, 120), 0, 0.6)), 0.6)
    write("dash", whoosh(0.28, 300, 1200, 1500, 6000), 0.7)
    grab = [(whoosh(0.25, 300, 1000, 800, 3000), 0, 0.5)]
    for k in range(7):
        grab.append((metal(1800 + rng.uniform(-300, 400), 0.12, 30), 0.03 + k * 0.03 + rng.uniform(0, 0.015), 0.35))
    write("grab", mix(*grab))
    wave_boom = osc(90, 0.9, "sine", freq_end=35, curve=0.6)
    env_exp(wave_boom, 4)
    shimmer = lowpass(mix((osc(220, 0.9, "saw"), 0), (osc(330.5, 0.9, "saw"), 0), (osc(440.8, 0.9, "saw"), 0)), 300, 4000)
    env_exp(shimmer, 5)
    write("amulet_wave", reverb(mix((wave_boom, 0, 1.0), (shimmer, 0, 0.35), (env_exp(noise(0.3), 10), 0, 0.2)), 0.25))
    write("crit", mix((env_exp(osc(1900, 0.3), 16), 0, 0.6), (env_exp(osc(2850, 0.25), 20), 0, 0.4),
                      (env_exp(highpass(noise(0.03), 3000), 150), 0, 0.7), (thud(170, 0.15), 0, 0.8)))
    hurt = lowpass(osc(150, 0.28, "saw", freq_end=85), 900)
    env_adsr(hurt, 0.01, 0.1, 0.5, 0.12)
    write("hero_hurt", mix((hurt, 0, 0.7), (thud(100, 0.2), 0, 0.9)), 0.8)
    death = mix((lowpass(noise(0.45), 2500, 300), 0, 0.6), (osc(300, 0.45, "saw", freq_end=60), 0, 0.3))
    write("enemy_death", env_exp(death, 7), 0.7)
    write("enemy_slash", lowpass(whoosh(0.22, 250, 900, 700, 2600), 2500), 0.7)
    spawn = mix((whoosh(0.6, 80, 400, 300, 1500), 0, 0.7), (env_swell(osc(70, 0.6, "sine", freq_end=110), 0.7), 0, 0.5))
    write("enemy_spawn", spawn, 0.6)
    write("enemy_windup", env_swell(lowpass(osc(240, 0.4, "saw", freq_end=420), 1200), 0.9), 0.4)
    bite = mix((env_exp(highpass(noise(0.04), 2500), 90), 0, 1.0), (env_exp(highpass(noise(0.04), 3000), 90), 0.06, 0.7))
    write("swarm_bite", bite, 0.5)
    twang = pluck(196, 0.5, 0.993, 0.6)
    write("arrow_shot", mix((twang, 0, 0.8), (whoosh(0.25, 600, 2500, 1500, 5000), 0.02, 0.4)))
    slam = mix((osc(70, 1.0, "sine", freq_end=28, curve=0.5), 0, 1.0), (lowpass(noise(0.8), 600, 150), 0, 0.8),
               (env_exp(noise(0.1), 30), 0, 0.5))
    write("brute_slam", reverb(env_exp(slam, 3.5), 0.2))
    charge = fm(300, 1.5, 3.0, 1.0, 0.5, freq_end=700)
    write("zone_charge", env_swell(lowpass(charge, 2500), 0.95), 0.4)
    blast = mix((thud(120, 0.4, 40), 0, 1.0), (env_exp(noise(0.4), 9), 0, 0.6), (env_exp(osc(1500, 0.4, "sine", freq_end=3000), 8), 0, 0.25))
    write("zone_blast", reverb(blast, 0.2))
    write("reflect", mix((metal(1200, 0.4, 8), 0, 0.8), (env_exp(osc(900, 0.3, "sine", freq_end=1800), 10), 0, 0.5)))
    absorb = [(whoosh(0.5, 200, 800, 1500, 6000), 0, 0.5)]
    for k, n in enumerate([72, 76, 79, 84]):
        absorb.append((bell(note_freq(n), 0.8, 4.0), 0.25 + k * 0.06, 0.3))
    write("absorb", reverb(mix(*absorb), 0.3))
    # Жертва: гул + нарастание шума + колокольный аккорд.
    drone = lowpass(mix((osc(55, 2.4, "saw"), 0), (osc(55.4, 2.4, "saw"), 0), (osc(82.4, 2.4, "saw"), 0)), 400)
    env_adsr(drone, 0.3, 0.3, 0.7, 1.0)
    swell = env_swell(highpass(noise(1.2), 2000), 0.95)
    chord = mix(*[(bell(note_freq(n), 2.0, 1.4), 1.15, 0.3) for n in [62, 65, 69, 74]])
    write("sacrifice", reverb(mix((drone, 0, 0.6), (swell, 0, 0.35), (chord, 0, 1.0), (thud(80, 0.6, 30), 1.15, 0.8)), 0.35, tail=1.6))
    conf = lowpass(mix((osc(110, 1.3, "saw", freq_end=220), 0), (osc(165, 1.3, "saw", freq_end=330), 0)), 300, 3000)
    write("sacrifice_confirm", env_swell(conf, 0.92), 0.6)
    pad = [(lowpass(osc(note_freq(n) * (1 + d), 1.8, "saw"), 1200), 0, 0.25) for n in [50, 57, 62, 65] for d in (-0.003, 0.003)]
    pad_s = mix(*pad)
    env_adsr(pad_s, 0.5, 0.3, 0.7, 0.8)
    write("altar_open", reverb(pad_s, 0.4, tail=1.5), 0.6)
    write("hold_tick", env_exp(osc(1400, 0.04), 90), 0.35)
    write("shrine_appear", reverb(mix(*[(bell(note_freq(n), 1.4, 2.5), k * 0.08, 0.4) for k, n in enumerate([76, 79, 83, 88])]), 0.4))
    write("shrine_swap", reverb(mix((bell(note_freq(79), 0.8, 3), 0, 0.5), (bell(note_freq(84), 0.8, 3), 0.12, 0.5),
                                    (whoosh(0.4, 300, 1200, 1200, 4000), 0, 0.3)), 0.3))
    write("stage_clear", reverb(mix(*[(bell(note_freq(n), 1.5, 2.2), k * 0.11, 0.45) for k, n in enumerate([62, 66, 69, 74, 78])]), 0.3))
    horn = lowpass(mix((osc(110, 1.4, "saw"), 0), (osc(110.6, 1.4, "saw"), 0), (osc(165, 1.4, "saw"), 0, 0.6)), 900)
    env_adsr(horn, 0.25, 0.2, 0.8, 0.5)
    write("elite_horn", reverb(horn, 0.3), 0.7)
    write("item_fly", mix((whoosh(0.45, 400, 1500, 1500, 5000), 0, 0.6), (env_exp(osc(1600, 0.4, "sine", freq_end=2400), 6), 0.1, 0.2)), 0.6)
    roar_n = lowpass(noise(1.8), 700)
    roar_t = osc(58, 1.8, "saw", freq_end=45)
    roar = [(a * 0.7 + b * 0.5) * (0.6 + 0.4 * math.sin(TAU * 7 * i / SR)) for i, (a, b) in enumerate(zip(roar_n, roar_t))]
    env_adsr(roar, 0.15, 0.3, 0.8, 0.8)
    write("boss_roar", reverb(softclip(roar, 2.0), 0.3))
    write("boss_phase", reverb(mix((thud(90, 0.6, 30), 0, 1.0), (env_exp(noise(0.5), 6), 0, 0.5), (metal(300, 0.8, 4), 0, 0.4)), 0.3))
    bd = [(osc(100, 2.6, "sine", freq_end=25, curve=0.4), 0, 1.0), (env_exp(lowpass(noise(2.5), 1500, 200), 1.5), 0, 0.6)]
    for k in range(14):
        bd.append((metal(rng.uniform(600, 2400), 0.6, 8), 0.1 + rng.uniform(0, 1.5), 0.25))
    write("boss_death", reverb(env_exp(mix(*bd), 1.2), 0.35, tail=1.5))
    defeat = mix(*[(env_adsr(lowpass(osc(note_freq(n), 1.6, "saw"), 1000), 0.05, 0.3, 0.6, 0.8), k * 0.35, 0.35) for k, n in enumerate([57, 53, 50])])
    write("defeat", reverb(defeat, 0.35))
    write("defeat_sting", reverb(mix(*[(bell(note_freq(n), 2.4, 1.2), 0, 0.3) for n in [45, 52, 57, 60]]), 0.4))
    vic = [(bell(note_freq(n), 1.6, 1.8), k * 0.14, 0.4) for k, n in enumerate([62, 66, 69, 74, 78, 81])]
    vic.append((env_adsr(lowpass(mix((osc(note_freq(50), 2.4, "saw"), 0), (osc(note_freq(57), 2.4, "saw"), 0)), 1500), 0.4, 0.3, 0.7, 1.0), 0.6, 0.35))
    write("victory", reverb(mix(*vic), 0.35))
    write("ui_click", mix((click(0.03, 1500), 0, 1.0), (click(0.02, 3000), 0, 0.4)), 0.5)
    write("ui_hover", click(0.02, 2200), 0.25)

    # Сущности.
    write("essence_blade", mix((env_exp(highpass(noise(0.3), 4000), 14), 0, 0.6),
                               (env_exp(osc(3200, 0.4), 9), 0.01, 0.35), (env_exp(osc(4700, 0.35), 11), 0.01, 0.25),
                               (whoosh(0.2, 800, 3000, 2000, 7000), 0, 0.5)))
    write("essence_bulwark", reverb(bell(392, 1.0, 2.6), 0.3))
    write("essence_mass", mix((thud(80, 0.5, 30), 0, 1.0), (env_exp(lowpass(noise(0.4), 500), 7), 0, 0.7)))
    gz = mix((osc(660, 0.7), 0), (osc(667, 0.7), 0), (osc(990, 0.7, "sine", freq_end=1320), 0, 0.5))
    gz = [x * (0.6 + 0.4 * math.sin(TAU * 11 * i / SR)) for i, x in enumerate(gz)]
    env_adsr(gz, 0.05, 0.2, 0.6, 0.3)
    write("essence_gaze", reverb(gz, 0.35), 0.6)
    gr = []
    for k in range(9):
        gr.append((metal(1500 + rng.uniform(-300, 600), 0.1, 35), k * 0.028 + rng.uniform(0, 0.01), 0.4))
    write("essence_grip", mix(*gr), 0.7)
    gu = whoosh(0.4, 300, 1200, 1200, 5000)
    gu = [x * (0.55 + 0.45 * math.sin(TAU * 26 * i / SR)) for i, x in enumerate(gu)]
    write("essence_gust", gu, 0.7)
    zap = osc(1400, 0.3, "saw", freq_end=180, curve=0.4)
    env_exp(zap, 9)
    crackle = env_exp([x if rng.random() < 0.08 else 0.0 for x in noise(0.3)], 8)
    write("essence_energy", mix((lowpass(zap, 3500), 0, 0.7), (crackle, 0, 0.6), (thud(140, 0.2), 0, 0.5)))

    # Новые враги: шут и слизень.
    giggle = []
    for k, f in enumerate([880, 1040, 920, 1180]):
        g = fm(f, 2.0, 2.5, 0.09, 14.0, freq_end=f * 0.85)
        env_adsr(g, 0.005, 0.03, 0.5, 0.04)
        g = [x * (0.7 + 0.3 * math.sin(TAU * 38 * i / SR)) for i, x in enumerate(g)]
        giggle.append((lowpass(g, 3200), k * 0.11, 0.6 if k % 2 == 0 else 0.45))
    write("jester_giggle", reverb(mix(*giggle), 0.2), 0.6)
    write("knife_slash", mix((whoosh(0.13, 1500, 4000, 3000, 8000), 0, 0.7), (env_exp(osc(2600, 0.12, "sine", freq_end=3400), 30), 0.02, 0.25)), 0.7)
    squish = lowpass(noise(0.35), 900, 250)
    squish = [x * (0.6 + 0.4 * math.sin(TAU * 22 * i / SR)) for i, x in enumerate(squish)]
    env_adsr(squish, 0.01, 0.1, 0.5, 0.15)
    write("slime_squish", mix((squish, 0, 0.9), (env_exp(osc(180, 0.3, "sine", freq_end=70), 9), 0, 0.6)), 0.7)
    write("slime_roll", mix((env_exp(lowpass(noise(0.12), 500), 25), 0, 0.8), (thud(95, 0.14, 55), 0, 0.6)), 0.5)


# ---------------------------------------------------------------- музыка

class Song:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = bars * beats_per_bar * self.beat
        self.buf = [0.0] * int((self.length + 3.0) * SR)
        self.cache = {}

    def at(self, beat):
        return int(beat * self.beat * SR)

    def place(self, key, maker, beat, g=1.0):
        if key not in self.cache:
            self.cache[key] = maker()
        add_into(self.buf, self.cache[key], self.at(beat), g)

    def render(self, wet=0.25, room=0.82):
        loop_n = int(self.length * SR)
        out = reverb(self.buf, wet, room, tail=0.0)
        # Хвост после конца петли заворачивается в её начало — шов не слышен.
        res = out[:loop_n]
        for i in range(loop_n, len(out)):
            res[i - loop_n] += out[i]
        return res


def kick():
    s = osc(120, 0.35, "sine", freq_end=40, curve=0.35)
    env_exp(s, 9)
    return mix((s, 0, 1.0), (env_exp(lowpass(noise(0.02), 3000), 120), 0, 0.3))


def snare():
    return mix((env_exp(bandpass(noise(0.25), 800, 6000), 16), 0, 0.8), (env_exp(osc(190, 0.15, "sine", freq_end=150), 25), 0, 0.5))


def hat(open_=False):
    return env_exp(highpass(noise(0.18 if open_ else 0.05), 6000), 12 if open_ else 70)


def tom(f):
    s = osc(f, 0.4, "sine", freq_end=f * 0.6)
    return env_exp(s, 8)


def bass_note(n, sec, bright=900):
    f = note_freq(n)
    s = mix((osc(f, sec, "saw"), 0, 0.6), (osc(f * 0.5, sec, "square"), 0, 0.4))
    s = lowpass(s, bright)
    env_adsr(s, 0.005, 0.1, 0.7, 0.05)
    return s


def lead_note(n, sec, shape="square", cutoff=2600):
    f = note_freq(n)
    s = mix((osc(f, sec, shape), 0, 0.5), (osc(f * 1.004, sec, shape), 0, 0.5))
    s = lowpass(s, cutoff)
    env_adsr(s, 0.01, 0.08, 0.55, 0.08)
    return s


def pad_chord(notes, sec, cutoff=1400):
    parts = []
    for n in notes:
        f = note_freq(n)
        for d in (-0.004, 0.0, 0.004):
            parts.append((osc(f * (1 + d), sec, "saw"), 0, 0.2))
    s = lowpass(mix(*parts), cutoff)
    env_adsr(s, sec * 0.25, sec * 0.2, 0.75, sec * 0.3)
    return s


def choir(notes, sec):
    parts = []
    for n in notes:
        f = note_freq(n)
        for d in (-0.006, 0.0, 0.006):
            s = osc(f * (1 + d), sec, "tri")
            s = [x * (0.8 + 0.2 * math.sin(TAU * 5.2 * i / SR)) for i, x in enumerate(s)]
            parts.append((s, 0, 0.22))
    s = lowpass(mix(*parts), 1800)
    env_adsr(s, sec * 0.3, 0.2, 0.8, sec * 0.3)
    return s


def music_battle():
    # Ре минор, 120 BPM, 16 тактов: Dm – Bb – F – C.
    song = Song(120, 16)
    prog = [(38, [62, 65, 69]), (34, [58, 62, 65]), (41, [60, 65, 69]), (36, [60, 64, 67])]
    arp_pat = [0, 1, 2, 1, 0, 2, 1, 2]
    for bar in range(16):
        root, chord = prog[(bar // 2) % 4]
        b0 = bar * 4
        # Ударные.
        for beat in range(4):
            song.place("kick", kick, b0 + beat, 0.9 if beat % 2 == 0 else 0.6)
            if beat % 2 == 1:
                song.place("snare", snare, b0 + beat, 0.55)
            song.place("hat", hat, b0 + beat + 0.5, 0.25)
            song.place("hat2", hat, b0 + beat, 0.12)
        if bar % 4 == 3:
            for k, f in enumerate([180, 150, 120]):
                song.place("tom%d" % f, lambda f=f: tom(f), b0 + 3 + k * 0.25, 0.5)
        # Бас восьмыми.
        for e in range(8):
            n = root if e % 4 != 3 else root + 7
            song.place(("bass", n), lambda n=n: bass_note(n, song.beat * 0.48), b0 + e * 0.5, 0.55)
        # Арпеджио с 5-го такта.
        if bar >= 4:
            for e in range(8):
                n = chord[arp_pat[e]] + (12 if bar >= 12 and e % 2 == 0 else 0)
                song.place(("arp", n), lambda n=n: lead_note(n, song.beat * 0.45, "square", 2200), b0 + e * 0.5, 0.16)
        # Пэд на каждые два такта.
        if bar % 2 == 0:
            song.place(("pad", tuple(chord)), lambda chord=chord: pad_chord([c - 12 for c in chord], song.beat * 8), b0, 0.3)
    # Мелодия во второй половине.
    melody = [(69, 1), (72, 1), (70, 2), (69, 1), (67, 1), (65, 2), (67, 1), (69, 1), (65, 1), (64, 1), (62, 4)]
    beat = 32
    for rep in range(2):
        for n, d in melody:
            song.place(("mel", n, d), lambda n=n, d=d: lead_note(n, song.beat * d * 0.95, "saw", 1800), beat, 0.2)
            beat += d
    write("music_battle", song.render(0.22), 0.8)


def music_boss():
    # Ми минор / фригийский, 140 BPM, 16 тактов: Em – F – Em – D.
    song = Song(140, 16)
    prog = [(40, [64, 67, 71]), (41, [65, 69, 72]), (40, [64, 67, 71]), (38, [62, 66, 69])]
    for bar in range(16):
        root, chord = prog[bar % 4]
        b0 = bar * 4
        for e in range(8):
            if e in (0, 3, 4, 6) or (bar % 2 == 1 and e == 7):
                song.place("kick", kick, b0 + e * 0.5, 0.95)
            song.place("hat", hat, b0 + e * 0.5, 0.2 if e % 2 else 0.3)
        song.place("snare", snare, b0 + 1, 0.65)
        song.place("snare", snare, b0 + 3, 0.65)
        if bar % 4 == 3:
            for k in range(4):
                song.place("snare", snare, b0 + 3 + k * 0.25, 0.35)
        for s16 in range(16):
            n = root if s16 % 8 not in (6, 7) else root + (1 if bar % 2 == 0 else 3)
            song.place(("bassb", n), lambda n=n: softclip(bass_note(n, song.beat * 0.24, 1400), 2.2), b0 + s16 * 0.25, 0.4)
        if bar % 2 == 0:
            song.place(("choir", tuple(chord)), lambda chord=chord: choir(chord, song.beat * 8), b0, 0.4)
        if bar >= 8:
            riff = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
            for k, n in enumerate(riff):
                song.place(("riff", n), lambda n=n: lead_note(n, song.beat * 0.9, "saw", 2400), b0 + k, 0.18)
    write("music_boss", song.render(0.2), 0.85)


def music_calm():
    # Медленный пэд и колокола, 70 BPM, 8 тактов.
    song = Song(70, 8)
    prog = [[50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 64], [45, 52, 57, 61]]
    for bar in range(8):
        chord = prog[bar % 4]
        song.place(("pad", tuple(chord)), lambda chord=chord: pad_chord(chord, song.beat * 4.4, 900), bar * 4, 0.45)
        for k in range(2):
            n = chord[(bar + k * 2) % 4] + 24
            song.place(("bell", n), lambda n=n: bell(note_freq(n), 2.5, 1.6), bar * 4 + k * 2 + 0.5, 0.18)
    write("music_calm", song.render(0.45, 0.88), 0.6)


def music_menu():
    # Тёмный эмбиент: ре минор, медленная мелодия поверх гула.
    song = Song(60, 8)
    for bar in range(8):
        chord = [[38, 45, 50, 53], [34, 41, 46, 50], [36, 43, 48, 52], [33, 40, 45, 49]][bar % 4]
        song.place(("mpad", tuple(chord)), lambda chord=chord: pad_chord(chord, song.beat * 4.6, 700), bar * 4, 0.5)
    mel = [(74, 2), (72, 1), (69, 1), (70, 3), (69, 1), (65, 2), (67, 2), (69, 4), (74, 2), (77, 1), (76, 1), (74, 3), (72, 1), (69, 8)]
    beat = 0
    for n, d in mel:
        song.place(("mb", n, d), lambda n=n, d=d: bell(note_freq(n), song.beat * d + 1.2, 1.3), beat, 0.25)
        beat += d
    write("music_menu", song.render(0.5, 0.9), 0.6)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        sfx()
    if what in ("all", "music"):
        print("Music:")
        music_battle()
        music_boss()
        music_calm()
        music_menu()
