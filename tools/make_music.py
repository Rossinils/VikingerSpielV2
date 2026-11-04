"""Komponiert die Hintergrundmusik ohne Gesang (reines Python, keine Abhaengigkeiten) nach Musik/Hintergrund/*.wav.

Aufruf:
    python tools/make_music.py              -> alle Stuecke
    python tools/make_music.py morgenwind   -> nur dieses Stueck (Namen: PIECES unten)
    python tools/make_music.py --missing    -> nur die Stuecke, die in Musik/Hintergrund noch fehlen

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


def crackle(buf, dur_s, density=6.0, gain=0.05):
    """Knistern (Feuer, Holz): kurze Schellenklicks an zufaelligen Stellen."""
    k = int(dur_s * density)
    for _ in range(k):
        add(buf, random.randrange(0, max(len(buf) - n(0.1), 1)), shaker(random.uniform(0.02, 0.05)), gain * random.uniform(0.4, 1.0))


def schildwall():
    """Deckkampf: D-Moll, 138 Schlaege. Trommelwand, galoppierender Bass, Streicherstakkato, Hornrufe, Fiedel."""
    random.seed(51)
    bpm = 138.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 40
    tail = n(2.5)
    buf = [0.0] * (n(bars * bar) + tail)
    roots = [38, 34, 36, 38, 38, 34, 43, 33]  # Dm Bb C Dm | Dm Bb Gm A
    chords = {38: [50, 53, 57], 34: [46, 50, 53], 36: [48, 52, 55], 43: [43, 46, 50], 33: [45, 49, 52]}
    scale = scale_notes(2, [0, 2, 3, 5, 7, 8, 10], 62, 81)  # D aeolisch
    motif = []
    prev = 69
    for e in range(8):
        prev = nearest_step(prev, scale, 4)
        motif.append(prev)
    add(buf, 0, drone(mtof(26), bars * bar + 2.0), 0.55)
    for b in range(bars):
        t0 = n(b * bar)
        root = roots[b % 8]
        quiet = 32 <= b < 36  # Atempause: nur Trommeln und Grundton, dann wieder alles
        for k in range(4):
            for pos, g in ((0.0, 1.0), (0.5, 0.6), (0.75, 0.6)):  # Galopp: Achtel und zwei Sechzehntel
                add(buf, t0 + n((k + pos) * beat), pluck(mtof(root), beat * 0.35, 0.993, 0.75), 0.36 * g)
        add(buf, t0, drum("low"), 0.7)
        add(buf, t0 + n(2 * beat), drum("low"), 0.6)
        add(buf, t0 + n(1 * beat), drum("mid"), 0.5)
        add(buf, t0 + n(3 * beat), drum("mid"), 0.5)
        if b >= 8:
            for k in range(4):
                add(buf, t0 + n(k * beat), drum("stomp"), 0.25)
            add(buf, t0 + n(3.5 * beat), drum("high"), 0.35)
        for e in range(8):
            add(buf, t0 + n(e * beat / 2.0), shaker(), 0.05)
        if quiet:
            continue
        if b >= 4:
            for k in range(4):
                for m in chords[root]:
                    add(buf, t0 + n((k + 0.5) * beat), bow(mtof(m + 12), beat * 0.25, 0.01, 0.06, 2200.0), 0.07)
        if b % 4 == 0:
            add(buf, t0, horn(mtof(root + 12), beat * 1.6, 0.04, 0.3, 950.0), 0.22)
            add(buf, t0 + n(2 * beat), horn(mtof(root + 19), beat * 1.8, 0.04, 0.4, 950.0), 0.2)
        if 16 <= b < 32 or b >= 36:
            for e, m in enumerate(motif):
                if e % 2 == 0 or random.random() < 0.5:
                    mm = m + (2 if b % 8 in (2, 3) else 0)
                    add(buf, t0 + n(e * beat / 2.0), bow(mtof(mm), beat * 0.45, 0.02, 0.08, 2800.0), 0.2)
        if b % 8 == 7:
            for k in range(4):
                add(buf, t0 + n((2 + k * 0.5) * beat), drum("high"), 0.45)
    finish(buf, tail, "schildwall")


def blutige_planken():
    """Deckkampf: A phrygisch im schnellen 6/8. Toms, Quintbass, Fiedelreigen, Schellen."""
    random.seed(61)
    eighth = 0.135
    bar = 6 * eighth
    bars = 72
    tail = n(2.0)
    buf = [0.0] * (n(bars * bar) + tail)
    scale = scale_notes(9, [0, 1, 3, 5, 7, 8, 10], 64, 84)  # A phrygisch
    roots = [45, 45, 46, 45, 43, 43, 46, 40]  # A A Bb A G G Bb E
    phrases = []
    for _ in range(3):
        prev = 76
        ph = []
        for e in range(12):
            if e % 3 != 1 or random.random() < 0.6:
                prev = nearest_step(prev, scale, 4)
                ph.append((e, prev))
        phrases.append(ph)
    add(buf, 0, drone(mtof(33), bars * bar + 2.0), 0.5)
    add(buf, 0, drone(mtof(40), bars * bar + 2.0), 0.25)
    for b in range(bars):
        t0 = n(b * bar)
        root = roots[(b // 2) % 8]
        add(buf, t0, pluck(mtof(root - 12), eighth * 2.5, 0.995, 0.6), 0.5)
        add(buf, t0 + n(3 * eighth), pluck(mtof(root - 5), eighth * 2.5, 0.995, 0.6), 0.4)
        add(buf, t0, drum("low"), 0.65)
        add(buf, t0 + n(3 * eighth), drum("mid"), 0.5)
        if b % 2 == 1:
            add(buf, t0 + n(5 * eighth), drum("high"), 0.35)
        for e in range(6):
            add(buf, t0 + n(e * eighth), shaker(0.06), 0.06 if e % 3 else 0.1)
        if b >= 8 and not (48 <= b < 52):
            ph = phrases[(b // 2) % 3]
            half = b % 2
            for e, m in ph:
                if e // 6 == half:
                    add(buf, t0 + n((e - half * 6) * eighth), bow(mtof(m), eighth * 0.9, 0.015, 0.05, 3000.0), 0.2)
        if b % 8 == 0:
            add(buf, t0, horn(mtof(root), bar * 1.8, 0.05, 0.4, 800.0), 0.2)
    finish(buf, tail, "blutige_planken")


def aus_der_tiefe():
    """Kraken: Cis-Moll mit Tritonus, 80 Schlaege. Tiefer Brummton, schwere Schlaege, schleichende Hoerner, Streichercluster."""
    random.seed(71)
    bpm = 80.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 26
    tail = n(4.0)
    buf = [0.0] * (n(bars * bar) + tail)
    add(buf, 0, drone(mtof(25), bars * bar + 3.0), 0.8)   # Cis
    add(buf, 0, drone(mtof(31), bars * bar + 3.0), 0.35)  # G: der Tritonus darunter
    descend = [37, 36, 35, 34]  # Cis C H B: das Horn sinkt
    for b in range(bars):
        t0 = n(b * bar)
        add(buf, t0, drum("low"), 0.9)
        add(buf, t0 + n(1.5 * beat), drum("low"), 0.55)
        if b % 2 == 1:
            add(buf, t0 + n(3.0 * beat), drum("stomp"), 0.5)
            add(buf, t0 + n(3.5 * beat), drum("stomp"), 0.6)
        if b % 2 == 0:
            add(buf, t0, horn(mtof(descend[(b // 2) % 4]), 2 * bar - 0.5, 0.6, 1.0, 700.0), 0.32)
        if b >= 4:
            lo = 49 + (b % 8)
            for m in (lo, lo + 1, lo + 6):  # enger Cluster, der langsam steigt
                add(buf, t0, tremolo_pad(mtof(m), bar - 0.1, 9.0, 0.6, 0.5, 0.6, 1500.0), 0.09)
        for _ in range(3):
            if random.random() < 0.6:
                m = random.choice([73, 74, 79, 80, 85])
                add(buf, t0 + n(random.uniform(0.0, 3.5) * beat), pluck(mtof(m), beat * 2.0, 0.9975, 0.4), 0.16)
        if b % 8 == 7:
            for k in range(6):
                add(buf, t0 + n((1.0 + k * 0.5) * beat), drum("mid"), 0.35 + 0.08 * k)
    finish(buf, tail, "aus_der_tiefe")


def nebelfahrt():
    """Nebel und Spuk: E aeolisch mit phrygischem F, 58 Schlaege. Leere Harfe, schwebender Teppich, ferne Fiedel."""
    random.seed(81)
    bpm = 58.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 22
    tail = n(5.0)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [[52, 55, 59], [48, 52, 55, 59], [45, 48, 52], [47, 52, 54]]  # Em Cmaj7 Am Bsus
    scale = scale_notes(4, [0, 1, 3, 5, 7, 8, 10], 64, 88)
    add(buf, 0, drone(mtof(28), bars * bar + 4.0), 0.6)
    add(buf, 0, drone(mtof(35), bars * bar + 4.0), 0.25)
    prev = 76
    for b in range(bars):
        t0 = n(b * bar)
        ch = chords[(b // 2) % 4]
        if b % 2 == 0:
            for m in ch:
                add(buf, t0, pad(mtof(m), 2 * bar, 1.8, 2.5, 800.0), 0.2)
        for e in range(4):
            if random.random() < 0.45:
                prev = nearest_step(prev, scale, 6)
                add(buf, t0 + n((e + random.choice([0.0, 0.5])) * beat), pluck(mtof(prev), beat * 4.0, 0.9985, 0.35), 0.3)
        if b % 6 == 3:
            m = random.choice(ch) + 24
            add(buf, t0, bow(mtof(m), bar * 1.5, 1.0, 1.5, 1800.0, 0.012, 3.0), 0.14)
        if b % 4 == 0:
            add(buf, t0, drum("low"), 0.18)
    finish(buf, tail, "nebelfahrt")


def ruderlied():
    """Ruderlied: G dorisch, 84 Schlaege. Jeder Ruderschlag eine Trommel, tiefe Hornstimmen wie Maennerchor, Fiedelweise."""
    random.seed(91)
    bpm = 84.0
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 32
    tail = n(3.0)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [(43, [55, 58, 62]), (41, [53, 57, 60]), (39, [51, 55, 58]), (41, [53, 57, 62])]  # Gm F Es F
    scale = scale_notes(7, [0, 2, 3, 5, 7, 9, 10], 62, 79)  # G dorisch
    tune = []
    prev = 67
    for _ in range(4):
        ph = []
        for e in range(8):
            if e % 2 == 0 or random.random() < 0.35:
                prev = nearest_step(prev, scale, 3)
                ph.append((e, prev, 1.0 if e % 4 == 0 else 0.5))
        tune.append(ph)
    add(buf, 0, drone(mtof(31), bars * bar + 2.0), 0.45)
    for b in range(bars):
        t0 = n(b * bar)
        root, tones = chords[(b // 2) % 4]
        add(buf, t0, drum("low"), 0.6)          # Ruder ins Wasser
        add(buf, t0 + n(2 * beat), drum("low"), 0.5)
        add(buf, t0 + n(1.0 * beat), drum("stomp"), 0.28)
        add(buf, t0 + n(3.0 * beat), drum("stomp"), 0.28)
        if b % 2 == 0:
            for m in tones:  # "Chor": tiefe, weiche Hornstimmen
                add(buf, t0, horn(mtof(m - 12), 2 * bar - 0.4, 0.5, 0.8, 600.0), 0.13)
        for k in (0, 2):
            add(buf, t0 + n(k * beat), pluck(mtof(root), beat * 1.8, 0.996, 0.45), 0.4)
        if b >= 4 and b % 16 < 14:
            for e, m, ln in tune[(b // 2) % 4] if b % 2 == 0 else tune[(b // 2 + 1) % 4]:
                add(buf, t0 + n(e * beat / 2.0), bow(mtof(m), beat * ln * 0.95, 0.06, 0.15, 2300.0), 0.2)
    finish(buf, tail, "ruderlied")


def lagerfeuer():
    """Lager: F-Dur und D-Moll im 3/4-Takt, 66 Schlaege. Laute, warmer Teppich, leise Fiedel, knisterndes Holz."""
    random.seed(101)
    bpm = 66.0
    beat = 60.0 / bpm
    bar = 3 * beat
    bars = 32
    tail = n(3.0)
    buf = [0.0] * (n(bars * bar) + tail)
    chords = [(41, [53, 57, 60]), (38, [50, 53, 57]), (46, [50, 53, 58]), (36, [48, 52, 55])]  # F Dm B C
    scale = scale_notes(5, [0, 2, 4, 5, 7, 9, 10], 65, 84)
    prev = 72
    for b in range(bars):
        t0 = n(b * bar)
        root, tones = chords[(b // 2) % 4]
        if b % 2 == 0:
            for m in tones:
                add(buf, t0, pad(mtof(m), 2 * bar, 1.2, 1.6, 900.0), 0.16)
        add(buf, t0, pluck(mtof(root - 12), beat * 2.5, 0.997, 0.3), 0.45)
        arp = [tones[0], tones[1], tones[2], tones[1] + 12, tones[2], tones[1]]
        for e in range(6):
            add(buf, t0 + n(e * beat / 2.0), pluck(mtof(arp[e] + 12), beat * 1.8, 0.9975, 0.4), 0.22)
        if b >= 4 and b % 8 < 6:
            for e in range(3):
                if random.random() < 0.7:
                    prev = nearest_step(prev, scale, 3)
                    add(buf, t0 + n(e * beat), bow(mtof(prev), beat * 0.95, 0.12, 0.25, 2000.0, 0.006, 5.0), 0.15)
    crackle(buf, bars * bar, 5.0, 0.05)
    finish(buf, tail, "lagerfeuer")


PIECES = {"morgenwind": morgenwind, "sturmwache": sturmwache, "eisen_und_salz": eisen_und_salz, "taverne": taverne,
          "schildwall": schildwall, "blutige_planken": blutige_planken, "aus_der_tiefe": aus_der_tiefe,
          "nebelfahrt": nebelfahrt, "ruderlied": ruderlied, "lagerfeuer": lagerfeuer}

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or list(PIECES)
    if "--missing" in sys.argv:  # nur, was in Musik/Hintergrund noch fehlt
        names = [nm for nm in names if not os.path.exists(os.path.join(OUT, nm + ".wav"))]
    for name in names:
        PIECES[name]()
