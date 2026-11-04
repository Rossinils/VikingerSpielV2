"""Komponiert die Hintergrundmusik ohne Gesang (reines Python, keine Abhaengigkeiten) nach Musik/Hintergrund/*.wav.

Aufruf:
    python tools/make_music.py              -> alle Stuecke
    python tools/make_music.py morgenwind   -> nur dieses Stueck (morgenwind, sturmwache, eisen_und_salz, taverne)

Mono, 22,05 kHz, 16 Bit. Die Stuecke sind als Endlosschleife gedacht: der Nachhall am Ende wird auf den
Anfang gelegt, so dass der Uebergang nicht knackt. Der Zufall ist festgelegt (Seed je Stueck), jeder Lauf
liefert dieselbe Musik. Instrumente: Karplus-Strong-Zupfen (Laute/Harfe), gestrichene Saege (Fiedel),
Orgelpunkt, Rahmentrommel, Schellenrauschen. Kein Anspruch auf Konzertsaal, aber ruhig und stimmig.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
TAU = 2.0 * math.pi
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Musik", "Hintergrund")


# --- Bausteine ---------------------------------------------------------------

def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def n(seconds):
    return int(seconds * SR)


def lowpass(x, cutoff):
    """Einfacher Tiefpass (ein Pol)."""
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def fade_env(length, atk, rel):
    """Huellkurve mit Ein- und Ausblenden (Sekunden)."""
    a = max(int(atk * SR), 1)
    r = max(int(rel * SR), 1)
    env = [1.0] * length
    for i in range(min(a, length)):
        env[i] = i / a
    for i in range(min(r, length)):
        j = length - 1 - i
        env[j] = min(env[j], i / r)
    return env


def pad(freq, dur, atk=0.9, rel=1.4, bright=1100.0):
    """Weicher Streicherteppich: zwei leicht verstimmte Saegezaehne plus Sinus, tiefpassgefiltert."""
    length = n(dur + rel)
    p1 = p2 = p3 = 0.0
    f1, f2, f3 = freq * 0.997, freq * 1.003, freq
    out = []
    for _ in range(length):
        p1 = (p1 + f1 / SR) % 1.0
        p2 = (p2 + f2 / SR) % 1.0
        p3 = (p3 + f3 / SR) % 1.0
        out.append(0.4 * (2 * p1 - 1) + 0.4 * (2 * p2 - 1) + 0.5 * math.sin(TAU * p3))
    out = lowpass(out, bright)
    env = fade_env(length, atk, rel)
    return [v * e for v, e in zip(out, env)]


def tremolo_pad(freq, dur, rate=7.0, depth=0.5, atk=0.2, rel=0.5, bright=1800.0):
    """Streichertremolo fuer Spannung."""
    length = n(dur + rel)
    p1 = p2 = 0.0
    out = []
    for i in range(length):
        p1 = (p1 + freq * 0.998 / SR) % 1.0
        p2 = (p2 + freq * 1.002 / SR) % 1.0
        lfo = 1.0 - depth * 0.5 * (1.0 + math.sin(TAU * rate * i / SR))
        out.append((0.5 * (2 * p1 - 1) + 0.5 * (2 * p2 - 1)) * lfo)
    out = lowpass(out, bright)
    env = fade_env(length, atk, rel)
    return [v * e for v, e in zip(out, env)]


def pluck(freq, dur, decay=0.9965, bright=0.5):
    """Karplus-Strong: Laute oder Harfe."""
    period = max(int(SR / freq), 2)
    buf = [random.uniform(-1.0, 1.0) * bright + (1.0 - bright) * math.sin(TAU * i / period) for i in range(period)]
    out = []
    idx = 0
    for _ in range(n(dur)):
        nxt = buf[(idx + 1) % period]
        v = buf[idx]
        buf[idx] = decay * 0.5 * (v + nxt)
        out.append(v)
        idx = (idx + 1) % period
    env = fade_env(len(out), 0.003, 0.08)
    return [v * e for v, e in zip(out, env)]


def bow(freq, dur, atk=0.12, rel=0.25, bright=2400.0, vib=0.004, vib_hz=5.4):
    """Gestrichene Saite (Fiedel/Vielle): Saege mit Vibrato, tiefpassgefiltert."""
    length = n(dur + rel)
    ph = ph2 = 0.0
    out = []
    for i in range(length):
        t = i / SR
        v = 1.0 + vib * min(t / 0.4, 1.0) * math.sin(TAU * vib_hz * t)
        ph = (ph + freq * v / SR) % 1.0
        ph2 = (ph2 + freq * 1.004 * v / SR) % 1.0
        out.append(0.55 * (2 * ph - 1) + 0.45 * (2 * ph2 - 1))
    out = lowpass(out, bright)
    env = fade_env(length, atk, rel)
    return [v * e for v, e in zip(out, env)]


def horn(freq, dur, atk=0.08, rel=0.3, bright=1000.0):
    """Tiefes Horn: Saege plus Rechteck, stark gefiltert."""
    length = n(dur + rel)
    ph = 0.0
    out = []
    for _ in range(length):
        ph = (ph + freq / SR) % 1.0
        out.append(0.6 * (2 * ph - 1) + 0.4 * (1.0 if ph < 0.5 else -1.0))
    out = lowpass(out, bright)
    env = fade_env(length, atk, rel)
    return [v * e for v, e in zip(out, env)]


def drone(freq, dur):
    length = n(dur)
    ph = ph2 = 0.0
    out = []
    for _ in range(length):
        ph = (ph + freq / SR) % 1.0
        ph2 = (ph2 + freq * 2.0 / SR) % 1.0
        out.append(0.7 * math.sin(TAU * ph) + 0.18 * math.sin(TAU * ph2) + 0.12 * (2 * ph - 1))
    out = lowpass(out, 400.0)
    env = fade_env(length, 2.0, 2.0)
    return [v * e for v, e in zip(out, env)]


def drum(kind="low"):
    """Rahmentrommel / Toms."""
    base, dur, tau = {"low": (58.0, 0.7, 0.22), "mid": (95.0, 0.5, 0.15), "high": (140.0, 0.35, 0.1), "stomp": (70.0, 0.4, 0.09)}[kind]
    length = n(dur)
    ph = 0.0
    out = []
    for i in range(length):
        t = i / SR
        f = base * (1.0 + 1.1 * math.exp(-t / 0.035))
        ph = (ph + f / SR) % 1.0
        out.append(math.sin(TAU * ph) * math.exp(-t / tau))
    stick = lowpass([random.uniform(-1, 1) * math.exp(-i / SR / 0.012) for i in range(length)], 1800.0)
    return [v + 0.35 * s for v, s in zip(out, stick)]


def shaker(dur=0.09):
    length = n(dur)
    raw = [random.uniform(-1, 1) * math.exp(-i / SR / 0.025) for i in range(length)]
    return highpass(raw, 4500.0)


def add(buf, start, samples, gain=1.0):
    if start < 0:
        samples = samples[-start:]
        start = 0
    end = min(len(buf), start + len(samples))
    for i in range(end - start):
        buf[start + i] += samples[i] * gain


def finish(buf, tail, name, peak=0.85):
    """Hall auf den Anfang legen (Endlosschleife), normalisieren, schreiben."""
    loop = len(buf) - tail
    for i in range(tail):
        buf[i] += buf[loop + i]
    buf = buf[:loop]
    m = max(abs(v) for v in buf) or 1.0
    scale = peak / m
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(v * scale * 32767)))) for v in buf))
    print("%s: %.1f s, Spitze %.2f" % (name, len(buf) / SR, m * scale))


def scale_notes(root, steps, lo, hi):
    """Alle Toene einer Tonleiter (MIDI) zwischen lo und hi."""
    out = []
    for octave in range(0, 10):
        for s in steps:
            m = root + 12 * octave + s
            if lo <= m <= hi:
                out.append(m)
    return sorted(out)


def nearest_step(prev, candidates, max_leap=5):
    near = [c for c in candidates if abs(c - prev) <= max_leap and c != prev]
    return random.choice(near) if near else random.choice(candidates)


# --- Stuecke -----------------------------------------------------------------

def morgenwind():
    """Ruhige See: D dorisch, 72 Schlaege, Harfenzupfen ueber Teppich und Orgelpunkt."""
    random.seed(11)
    bpm = 72.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 28
    tail = n(4.0)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [([50, 53, 57], 38), ([48, 52, 55], 36), ([43, 47, 50], 43), ([45, 48, 52], 45)]  # Dm, C, G, Am
    add(buf, 0, drone(mtof(38), bars * bar + 3.0), 0.55)
    scale = scale_notes(2, [0, 2, 3, 5, 7, 9, 10], 62, 86)  # D dorisch (D = 2 + 12k)
    prev = 74
    for b in range(bars):
        notes, root = chords[(b // 2) % 4]
        t0 = n(b * bar)
        if b % 2 == 0:
            for m in notes:
                add(buf, t0, pad(mtof(m), 2 * bar), 0.30)
        add(buf, t0, pluck(mtof(root - 12 + 12), beat * 3.0, 0.998, 0.3), 0.55)
        tones = [m + 12 * k for m in notes for k in (1, 2) if 62 <= m + 12 * k <= 86]
        for e in range(8):
            if random.random() < (0.62 if e % 2 == 0 else 0.38):
                pool = tones if random.random() < 0.7 else scale
                prev = nearest_step(prev, pool, 5)
                add(buf, t0 + n(e * beat / 2.0), pluck(mtof(prev), beat * 2.2, 0.9972, 0.55), 0.38)
        if b % 8 == 4:  # gestrichene Gegenstimme, zwei Takte
            add(buf, t0, bow(mtof(notes[2] + 12), 2 * bar - 0.3), 0.20)
        if b % 2 == 0 and b > 0:
            add(buf, t0, drum("low"), 0.22)
    finish(buf, tail, "morgenwind")


def sturmwache():
    """Sturm: A aeolisch, 112 Schlaege, Rahmentrommeln, tremolierende Streicher, Fiedelmotiv."""
    random.seed(23)
    bpm = 112.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 40
    tail = n(3.0)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [[45, 52, 57, 60], [41, 48, 53, 57], [48, 55, 60, 64], [43, 50, 55, 59]]  # Am, F, C, G
    add(buf, 0, drone(mtof(33), bars * bar + 2.0), 0.7)
    add(buf, 0, drone(mtof(40), bars * bar + 2.0), 0.35)
    minor = scale_notes(9, [0, 3, 5, 7, 10], 69, 84)  # A-Moll-Pentatonik
    motifs = []
    for _ in range(2):
        notes = []
        prev = 76
        for e in range(16):
            if e % 2 == 0 or random.random() < 0.3:
                prev = nearest_step(prev, minor, 7)
                notes.append((e, prev, 0.5 if random.random() < 0.6 else 1.0))
        motifs.append(notes)
    pattern = [("low", 0.0, 1.0), ("mid", 1.5, 0.7), ("low", 2.0, 0.9), ("mid", 3.0, 0.7), ("high", 3.5, 0.5)]
    for b in range(bars):
        t0 = n(b * bar)
        chord = chords[b % 4]
        for m in chord:
            add(buf, t0, tremolo_pad(mtof(m), bar - 0.1, 7.5, 0.5), 0.17)
        for kind, pos, g in pattern:
            add(buf, t0 + n(pos * beat), drum(kind), 0.55 * g)
        for e in range(8):
            add(buf, t0 + n(e * beat / 2.0), shaker(), 0.07)
        if b >= 4:
            motif = motifs[0] if (b // 2) % 2 == 0 else motifs[1]
            if b % 2 == 0 and (b // 2) % 4 != 3:
                for e, m, ln in motif:
                    add(buf, t0 + n(e * beat / 2.0), bow(mtof(m), beat * ln * 0.9, 0.05, 0.12, 2800.0), 0.22)
        if b % 4 == 0:
            add(buf, t0, horn(mtof(chord[0] - 12), 2 * bar - 0.2), 0.25)
    finish(buf, tail, "sturmwache")


def eisen_und_salz():
    """Kampf: E phrygisch, 132 Schlaege, schwere Trommeln, Ostinato-Bass, Hornrufe."""
    random.seed(31)
    bpm = 132.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 48
    tail = n(3.0)
    buf = [0.0] * (n(bars * bar) + tail)
    notes_e = scale_notes(4, [0, 1, 3, 5, 7, 8, 10], 64, 79)  # E phrygisch
    roots = [40, 40, 41, 40, 43, 41, 40, 40]  # E E F E G F E E
    riff = []
    prev = 71
    for e in range(8):
        prev = nearest_step(prev, notes_e, 5)
        riff.append(prev)
    add(buf, 0, drone(mtof(28), bars * bar + 2.0), 0.6)
    for b in range(bars):
        t0 = n(b * bar)
        root = roots[b % 8]
        for e in range(8):
            accent = 1.0 if e % 4 == 0 else 0.6
            add(buf, t0 + n(e * beat / 2.0), pluck(mtof(root - 12), beat * 0.45, 0.994, 0.7), 0.42 * accent)
        for k in range(4):
            add(buf, t0 + n(k * beat), drum("low" if k % 2 == 0 else "mid"), 0.6)
        add(buf, t0 + n(1.5 * beat), drum("high"), 0.4)
        add(buf, t0 + n(3.5 * beat), drum("high"), 0.4)
        for m in (root, root + 7, root + 12):
            add(buf, t0, horn(mtof(m + 12), beat * 1.4, 0.03, 0.2, 900.0), 0.16)
        if b >= 8 and b % 2 == 0:
            for e in range(8):
                if e % 2 == 0 or random.random() < 0.3:
                    m = riff[e]
                    add(buf, t0 + n(e * beat / 2.0), bow(mtof(m), beat * 0.45, 0.03, 0.08, 2600.0), 0.20)
        if b % 8 == 7:
            add(buf, t0 + n(2 * beat), drum("high"), 0.5)
            add(buf, t0 + n(3 * beat), drum("high"), 0.5)
    finish(buf, tail, "eisen_und_salz")


def taverne():
    """Hafen: G mixolydisch im 6/8-Takt, Laute, Fusstrampeln, Schellen."""
    random.seed(41)
    eighth = 0.2  # Achtel in Sekunden (punktierte Viertel ~ 100)
    bar = 6 * eighth
    bars = 64
    tail = n(2.5)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [(43, [55, 59, 62]), (41, [53, 57, 60]), (36, [52, 55, 60]), (38, [50, 54, 57])]  # G F C D
    scale = scale_notes(7, [0, 2, 4, 5, 7, 9, 10], 62, 84)  # G mixolydisch
    tune = []
    prev = 71
    for _ in range(8):
        step = []
        for e in range(6):
            if e in (0, 3) or random.random() < 0.5:
                prev = nearest_step(prev, scale, 4)
                step.append((e, prev))
        tune.append(step)
    for b in range(bars):
        t0 = n(b * bar)
        root, tones = chords[(b // 2) % 4]
        arp = [tones[0], tones[1], tones[2], tones[1], tones[2], tones[1]]
        for e in range(6):
            add(buf, t0 + n(e * eighth), pluck(mtof(arp[e]), eighth * 4.0, 0.997, 0.4), 0.30)
        add(buf, t0, pluck(mtof(root - 12), eighth * 3.0, 0.997, 0.35), 0.55)
        add(buf, t0 + n(3 * eighth), pluck(mtof(root - 5), eighth * 3.0, 0.997, 0.35), 0.40)
        add(buf, t0, drum("stomp"), 0.45)
        add(buf, t0 + n(3 * eighth), drum("stomp"), 0.35)
        for e in (2, 5):
            add(buf, t0 + n(e * eighth), shaker(0.07), 0.10)
        if b >= 4:
            for e, m in tune[(b // 2) % 8] if b % 2 == 0 else tune[(b // 2 + 3) % 8]:
                add(buf, t0 + n(e * eighth), pluck(mtof(m), eighth * 2.6, 0.9968, 0.6), 0.34)
    finish(buf, tail, "taverne")


PIECES = {"morgenwind": morgenwind, "sturmwache": sturmwache, "eisen_und_salz": eisen_und_salz, "taverne": taverne}

if __name__ == "__main__":
    names = sys.argv[1:] or list(PIECES)
    for name in names:
        PIECES[name]()
