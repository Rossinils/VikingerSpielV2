"""Synthetisiert die Soundeffekte (reines Python, keine Abhaengigkeiten) nach assets/sfx/*.wav.

Aufruf:
    python tools/make_sfx.py                    -> schreibt die WAV-Dateien
    python tools/make_sfx.py --preview ordner   -> zusaetzlich ein Bild mit den Lautstaerkeverlaeufen

Alle Klaenge sind mono, 44,1 kHz, 16 Bit, mit kurzem Ein- und Ausblenden (kein Knacken) und auf
Spitzenpegel <= 0,8 normalisiert. Lautstaerke im Spiel stellt scripts/sfx.gd ein (GAIN).
"""
import math
import os
import random
import struct
import sys
import wave
import zlib

SR = 44100
TAU = 2.0 * math.pi
random.seed(7)


def n(seconds):
    return int(seconds * SR)


# --- Bausteine ---------------------------------------------------------------

class Biquad:
    """RBJ-Filter: lp (Tiefpass), hp (Hochpass), bp (Bandpass)."""

    def __init__(self, kind, f0, q=0.707):
        self.kind = kind
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(f0, q)

    def set(self, f0, q=0.707):
        w0 = TAU * min(max(f0, 20.0), SR * 0.45) / SR
        alpha = math.sin(w0) / (2.0 * q)
        cw = math.cos(w0)
        if self.kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif self.kind == "hp":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:
            b0, b1, b2 = alpha, 0.0, -alpha
        a0 = 1 + alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = (-2 * cw) / a0, (1 - alpha) / a0

    def tick(self, x):
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def filt(x, kind, f0, q=0.707):
    f = Biquad(kind, f0, q)
    return [f.tick(v) for v in x]


def sweep(x, kind, f_of_t, q=0.707):
    """Filter, dessen Grenzfrequenz sich ueber die Zeit aendert (f_of_t in Sekunden)."""
    f = Biquad(kind, f_of_t(0.0), q)
    out = []
    for i, v in enumerate(x):
        if i % 32 == 0:
            f.set(f_of_t(i / SR), q)
        out.append(f.tick(v))
    return out


def noise(dur):
    return [random.uniform(-1.0, 1.0) for _ in range(n(dur))]


def osc(shape, freq, dur, vibrato=0.0, vib_hz=5.0):
    """freq: Hz oder Funktion t -> Hz."""
    out = []
    ph = 0.0
    for i in range(n(dur)):
        t = i / SR
        f = freq(t) if callable(freq) else freq
        f *= 1.0 + vibrato * math.sin(TAU * vib_hz * t)
        ph += f / SR
        p = ph % 1.0
        if shape == "sine":
            out.append(math.sin(TAU * ph))
        elif shape == "saw":
            out.append(2.0 * p - 1.0)
        elif shape == "tri":
            out.append(4.0 * abs(p - 0.5) - 1.0)
        else:
            out.append(1.0 if p < 0.5 else -1.0)
    return out


def env(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def decay(tau):
    return lambda t: math.exp(-t / tau)


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def gain(x, g):
    return [v * g for v in x]


def delay(x, seconds):
    return [0.0] * n(seconds) + x


def smooth(t, a, b):
    if t <= a:
        return 0.0
    if t >= b:
        return 1.0
    u = (t - a) / (b - a)
    return u * u * (3 - 2 * u)


def finish(x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    x = [v * peak / m for v in x]
    fade = n(0.004)
    for i in range(min(fade, len(x))):
        k = i / fade
        x[i] *= k
        x[-1 - i] *= k
    return x


# --- Klaenge -----------------------------------------------------------------

def s_click():
    x = env(osc("sine", 1500, 0.08), decay(0.012))
    tick = env(noise(0.08), decay(0.002))
    return mix(x, gain(tick, 0.4))


def s_horn():
    """Langes tiefes Horn beim Auslaufen: Grundton und Quinte, langsamer Einsatz."""
    dur = 1.5
    a = osc("saw", 98.0, dur, 0.004, 5.2)
    b = osc("saw", 147.0 * 1.003, dur, 0.004, 4.7)
    x = mix(a, gain(b, 0.7))
    x = filt(x, "lp", 650, 0.9)
    return env(x, lambda t: smooth(t, 0.0, 0.28) * (1.0 - smooth(t, 1.0, 1.5)))


def s_sail():
    x = filt(noise(0.75), "bp", 520, 1.1)
    return env(x, lambda t: (0.35 + 0.65 * abs(math.sin(TAU * 12.0 * t))) * math.exp(-t / 0.25))


def s_creak():
    """Knarrendes Holz: Saege mit schwankender Tonhoehe, ruckelnde Lautstaerke."""
    dur = 1.0
    wob = random.uniform(0, 6)
    x = osc("saw", lambda t: 96.0 + 22.0 * math.sin(TAU * 1.6 * t + wob) + 9.0 * math.sin(TAU * 7.3 * t), dur)
    x = filt(x, "lp", 760, 1.4)
    x = env(x, lambda t: (0.55 + 0.45 * math.sin(TAU * 9.0 * t + 1.3 * math.sin(TAU * 2.1 * t))) * smooth(t, 0, 0.08) * (1 - smooth(t, 0.7, 1.0)))
    ticks = [0.0] * n(dur)
    for _ in range(14):
        i = random.randrange(n(0.05), n(0.9))
        for k in range(30):
            if i + k < len(ticks):
                ticks[i + k] += random.uniform(-1, 1) * math.exp(-k / 6.0) * 0.25
    return mix(x, ticks)


def s_crash():
    """Schwerer Aufprall: Rauschstoss, tiefer Schlag, splitterndes Holz."""
    dur = 1.5
    body = sweep(noise(dur), "lp", lambda t: 2600.0 * math.exp(-t / 0.28) + 220.0, 0.9)
    body = env(body, decay(0.32))
    thump = env(osc("sine", lambda t: 55.0 + 40.0 * math.exp(-t / 0.05), dur), decay(0.22))
    crackle = [0.0] * n(dur)
    for _ in range(60):
        t0 = random.expovariate(1.0 / 0.25)
        i = n(min(t0, 1.2))
        for k in range(24):
            if i + k < len(crackle):
                crackle[i + k] += random.uniform(-1, 1) * math.exp(-k / 5.0) * 0.5
    return mix(gain(body, 0.9), gain(thump, 1.0), crackle)


def s_wave():
    dur = 2.3
    x = noise(dur)
    x = sweep(x, "bp", lambda t: 250.0 + 1300.0 * math.sin(math.pi * min(t / 1.2, 1.0)) ** 2 + 150.0, 0.8)
    return env(x, lambda t: smooth(t, 0.0, 0.55) * math.exp(-max(t - 0.55, 0.0) / 0.7))


def s_gust():
    dur = 1.9
    x = sweep(noise(dur), "bp", lambda t: 520.0 + 220.0 * math.sin(TAU * 0.9 * t), 4.0)
    return env(x, lambda t: math.sin(math.pi * t / dur) ** 2)


def s_splash():
    dur = 1.1
    burst = env(filt(noise(dur), "hp", 1500, 0.8), decay(0.11))
    body = env(filt(noise(dur), "lp", 800, 0.9), lambda t: smooth(t, 0.0, 0.03) * math.exp(-t / 0.3))
    tracks = [gain(burst, 0.8), gain(body, 0.9)]
    for _ in range(5):
        t0 = random.uniform(0.12, 0.75)
        f0 = random.uniform(400, 700)
        chirp = env(osc("sine", lambda t, f0=f0: f0 * (1.0 + 1.2 * min(t / 0.06, 1.0)), 0.09), decay(0.03))
        tracks.append(delay(gain(chirp, 0.3), t0))
    return mix(*tracks)


def s_rope():
    dur = 0.5
    x = sweep(noise(dur), "bp", lambda t: 800.0 + 2400.0 * (t / dur), 1.2)
    return env(x, lambda t: math.sin(math.pi * t / dur) ** 2)


def s_rescue_ok():
    """Warmes aufsteigendes D-Moll: das Seil hat gehalten."""
    tracks = []
    for k, f in enumerate([293.66, 349.23, 440.0]):
        note = mix(osc("sine", f, 0.8), gain(osc("tri", f * 2.0, 0.8), 0.25))
        note = env(note, lambda t: smooth(t, 0.0, 0.012) * math.exp(-t / 0.4))
        tracks.append(delay(gain(note, 0.8), 0.17 * k))
    pad = env(osc("sine", 146.83, 1.2), lambda t: smooth(t, 0.0, 0.1) * math.exp(-t / 0.7))
    tracks.append(gain(pad, 0.5))
    return mix(*tracks)


def s_drown():
    dur = 2.1
    x = env(osc("sine", lambda t: 45.0 + 70.0 * math.exp(-t / 0.5), dur), lambda t: smooth(t, 0.0, 0.05) * math.exp(-t / 0.8))
    tracks = [x]
    for _ in range(6):
        t0 = random.uniform(0.2, 1.4)
        f0 = random.uniform(220, 420)
        chirp = env(osc("sine", lambda t, f0=f0: f0 * (1.0 + 0.8 * min(t / 0.08, 1.0)), 0.1), decay(0.04))
        tracks.append(delay(gain(chirp, 0.15), t0))
    return mix(*tracks)


def s_death():
    """Dumpfer Trommelschlag."""
    dur = 1.0
    drum = env(osc("sine", lambda t: 45.0 + 60.0 * math.exp(-t / 0.06), dur), decay(0.2))
    skin = env(filt(noise(dur), "lp", 500, 0.8), decay(0.04))
    return mix(drum, gain(skin, 0.6))


def s_hammer():
    tracks = []
    for k in range(3):
        knock = env(osc("sine", 520.0 + 25.0 * k, 0.2), decay(0.035))
        body = env(osc("sine", 175.0, 0.2), decay(0.06))
        tick = env(filt(noise(0.2), "bp", 1500, 1.0), decay(0.008))
        hit = mix(knock, gain(body, 0.8), gain(tick, 0.5))
        tracks.append(delay(hit, 0.19 * k))
    return mix(*tracks)


def s_coin():
    tracks = []
    for t0, f in ((0.0, 2093.0), (0.075, 2794.0)):
        ping = mix(osc("sine", f, 0.5), gain(osc("sine", f * 2.76, 0.5), 0.4), gain(osc("sine", f * 5.4, 0.5), 0.15))
        tracks.append(delay(env(ping, decay(0.11)), t0))
    return mix(*tracks)


def s_thunder():
    dur = 3.4
    crack = env(filt(noise(dur), "bp", 2500, 0.8), decay(0.03))
    rumble = sweep(noise(dur), "lp", lambda t: 420.0 * math.exp(-t / 1.2) + 110.0, 0.8)
    rumble = env(rumble, lambda t: smooth(t, 0.0, 0.18) * math.exp(-max(t - 0.18, 0.0) / 1.0) * (0.75 + 0.25 * math.sin(TAU * 2.6 * t)))
    return mix(gain(crack, 0.5), gain(rumble, 1.0))


def s_bell():
    dur = 3.6
    tracks = []
    for ratio, amp, tau in ((1.0, 1.0, 2.6), (2.0, 0.6, 1.8), (2.4, 0.45, 1.4), (3.0, 0.3, 1.0), (4.07, 0.2, 0.7)):
        tracks.append(gain(env(osc("sine", 392.0 * ratio, dur), decay(tau)), amp))
    tracks.append(gain(env(filt(noise(dur), "bp", 2400, 1.0), decay(0.01)), 0.4))
    return mix(*tracks)


def s_sting():
    """Zwei dumpfe Trommelschlaege mit anschwellendem tiefem Ton: da kommt etwas."""
    dur = 1.4
    def hit(strength):
        d = env(osc("sine", lambda t: 52.0 + 55.0 * math.exp(-t / 0.05), 0.7), decay(0.17))
        s = env(filt(noise(0.7), "lp", 450, 0.8), decay(0.03))
        return gain(mix(d, gain(s, 0.5)), strength)
    low = filt(osc("saw", 82.0, dur), "lp", 380, 1.0)
    low = env(low, lambda t: smooth(t, 0.2, 0.9) * (1 - smooth(t, 1.0, 1.4)))
    return mix(hit(0.8), delay(hit(1.0), 0.3), gain(low, 0.35))


def s_heartbeat():
    def thump(a):
        x = env(osc("sine", lambda t: 38.0 + 26.0 * math.exp(-t / 0.05), 0.4), decay(0.1))
        return gain(x, a)
    return filt(mix(thump(1.0), delay(thump(0.65), 0.3)), "lp", 160, 0.8)


def s_mug():
    """Zwei Humpen klirren, dazwischen ein hölzerner Schlag."""
    def clink(f, a):
        c = mix(osc("sine", f, 0.4), gain(osc("sine", f * 1.34, 0.4), 0.6))
        c = env(c, decay(0.07))
        tick = env(filt(noise(0.4), "hp", 3000, 0.8), decay(0.006))
        return gain(mix(c, gain(tick, 0.5)), a)
    thunk = env(osc("sine", 250.0, 0.2), decay(0.04))
    return mix(clink(1900.0, 1.0), delay(gain(thunk, 0.9), 0.24), delay(clink(2300.0, 0.7), 0.38))


def s_fog():
    """Tiefes Nebelhorn."""
    dur = 2.2
    x = filt(osc("saw", 72.0, dur, 0.003, 4.0), "lp", 320, 1.0)
    x = mix(x, gain(osc("sine", 72.0, dur), 0.8))
    return env(x, lambda t: smooth(t, 0.0, 0.45) * (1 - smooth(t, 1.3, 2.2)))


def s_cannon():
    """Kanonenschuss: scharfer Knall, tiefer Schlag, langes Rollen."""
    dur = 1.8
    blast = env(sweep(noise(dur), "lp", lambda t: 5000.0 * math.exp(-t / 0.06) + 300.0, 0.8), decay(0.12))
    boom = env(osc("sine", lambda t: 45.0 + 70.0 * math.exp(-t / 0.08), dur), decay(0.35))
    rumble = env(filt(noise(dur), "lp", 160, 0.9), lambda t: math.exp(-t / 0.6))
    return mix(gain(blast, 1.0), gain(boom, 1.2), gain(rumble, 0.7))


# --- Kampfgeraeusche ---------------------------------------------------------

def s_swing():
    """Klinge zischt durch die Luft."""
    dur = 0.32
    x = sweep(noise(dur), "bp", lambda t: 500.0 + 2600.0 * math.sin(math.pi * min(t / 0.28, 1.0)) ** 0.8, 1.3)
    return env(x, lambda t: math.sin(math.pi * min(t / 0.3, 1.0)) ** 1.5)


def s_whiff():
    """Ein Hieb geht ins Leere: leiser, kuerzer Luftzug."""
    dur = 0.26
    x = sweep(noise(dur), "bp", lambda t: 900.0 + 1200.0 * (1.0 - t / dur), 0.9)
    return env(x, lambda t: math.sin(math.pi * min(t / dur, 1.0)) ** 2)


def s_slash():
    """Klinge trifft Fleisch: kurzer Schnitt, dumpfer Schlag."""
    dur = 0.35
    cut = env(filt(noise(dur), "hp", 1400, 0.8), decay(0.03))
    thud = env(osc("sine", lambda t: 150.0 - 70.0 * min(t / 0.08, 1.0), dur), decay(0.06))
    ring = env(osc("sine", 2300.0, dur), decay(0.035))
    return mix(gain(cut, 0.9), gain(thud, 1.0), gain(ring, 0.18))


def s_clash():
    """Eisen auf Eisen: heller Klang mit langem Nachhall."""
    dur = 0.9
    tracks = []
    for ratio, amp, tau in ((1.0, 1.0, 0.18), (2.76, 0.7, 0.12), (5.4, 0.45, 0.08), (8.93, 0.25, 0.05)):
        tracks.append(gain(env(osc("sine", 1250.0 * ratio, dur), decay(tau)), amp))
    tracks.append(gain(env(filt(noise(dur), "hp", 2500, 0.8), decay(0.01)), 0.6))
    return mix(*tracks)


def s_chop():
    """Axt: schwerer Schlag, splitterndes Holz."""
    dur = 0.5
    thump = env(osc("sine", lambda t: 55.0 + 70.0 * math.exp(-t / 0.04), dur), decay(0.11))
    body = env(filt(noise(dur), "lp", 1300, 0.9), decay(0.045))
    crack = env(filt(noise(dur), "bp", 2800, 1.2), decay(0.012))
    return mix(gain(thump, 1.2), gain(body, 0.9), gain(crack, 0.5))


def s_bash():
    """Schildstoss: dumpfes Holz, leises Scheppern."""
    dur = 0.55
    boom = env(osc("sine", lambda t: 70.0 + 55.0 * math.exp(-t / 0.05), dur), decay(0.13))
    wood = env(filt(noise(dur), "lp", 800, 1.0), decay(0.035))
    rattle = env(osc("sine", 640.0, dur), decay(0.05))
    return mix(gain(boom, 1.2), gain(wood, 0.8), gain(rattle, 0.25))


def s_bow():
    """Bogensehne schnellt, der Pfeil zischt davon."""
    dur = 0.6
    twang = env(osc("sine", lambda t: 190.0 + 20.0 * math.exp(-t / 0.03), dur, 0.02, 38.0), decay(0.1))
    twang2 = env(osc("tri", lambda t: 380.0 + 40.0 * math.exp(-t / 0.03), dur), decay(0.05))
    slap = env(filt(noise(dur), "hp", 1800, 0.8), decay(0.006))
    arrow = sweep(noise(dur), "bp", lambda t: 3600.0 - 2200.0 * min(t / 0.3, 1.0), 2.0)
    arrow = env(arrow, lambda t: smooth(t, 0.0, 0.02) * math.exp(-t / 0.14))
    return mix(gain(twang, 1.0), gain(twang2, 0.35), gain(slap, 0.5), delay(gain(arrow, 0.7), 0.02))


def s_arrow_hit():
    """Pfeil schlaegt ein: dumpfes Pochen, der Schaft zittert nach."""
    dur = 0.5
    thunk = env(osc("sine", lambda t: 210.0 - 100.0 * min(t / 0.05, 1.0), dur), decay(0.04))
    tick = env(filt(noise(dur), "lp", 1800, 0.9), decay(0.012))
    shaft = env(osc("sine", 430.0, dur, 0.04, 26.0), decay(0.11))
    return mix(gain(thunk, 1.1), gain(tick, 0.8), gain(shaft, 0.22))


def s_bite():
    """Knurren und nasses Zuschnappen."""
    dur = 0.55
    growl = filt(osc("saw", lambda t: 85.0 + 10.0 * math.sin(TAU * 21.0 * t), dur), "lp", 420, 1.2)
    growl = env(growl, lambda t: smooth(t, 0.0, 0.06) * math.exp(-t / 0.22))
    snap1 = env(filt(noise(dur), "bp", 1100, 1.1), decay(0.02))
    snap2 = delay(env(filt(noise(dur), "bp", 1500, 1.1), decay(0.015)), 0.09)
    return mix(gain(growl, 0.9), gain(snap1, 0.8), gain(snap2, 0.6))


def s_heal():
    """Helles Glockenspiel nach oben: Kraft kehrt zurueck."""
    tracks = []
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        note = mix(osc("sine", f, 0.9), gain(osc("sine", f * 2.01, 0.9), 0.35), gain(osc("sine", f * 3.0, 0.9), 0.12))
        tracks.append(delay(gain(env(note, lambda t: smooth(t, 0.0, 0.005) * math.exp(-t / 0.3)), 0.8), 0.075 * k))
    return mix(*tracks)


def s_harp():
    """Gezupfte Saiten, ein ruhiger Lauf in Moll: der Skalde tut den Mut kund."""
    tracks = []
    for k, f in enumerate([293.66, 349.23, 440.0, 587.33]):
        pluck = mix(osc("tri", f, 1.0), gain(osc("sine", f * 2.0, 1.0), 0.4), gain(osc("sine", f * 3.0, 1.0), 0.15))
        pluck = filt(env(pluck, lambda t: smooth(t, 0.0, 0.003) * math.exp(-t / 0.35)), "lp", 3500, 0.7)
        tracks.append(delay(gain(pluck, 0.8), 0.11 * k))
    return mix(*tracks)


def s_warsong():
    """Tiefes mehrstimmiges Kriegslied mit einem Trommelschlag."""
    dur = 1.1
    voices = []
    for f, a in ((110.0, 1.0), (165.0, 0.8), (220.0, 0.7)):
        voices.append(gain(osc("saw", f, dur, 0.006, 5.4), a))
    song = filt(mix(*voices), "lp", 820, 1.0)
    song = env(song, lambda t: smooth(t, 0.0, 0.16) * (1.0 - smooth(t, 0.7, 1.1)))
    drum = env(osc("sine", lambda t: 50.0 + 60.0 * math.exp(-t / 0.05), dur), decay(0.16))
    return mix(gain(song, 0.8), gain(drum, 0.9))


def s_fall():
    """Ein Mann geht zu Boden: Aufschlag, Klirren der Ausruestung."""
    dur = 0.8
    thud = env(osc("sine", lambda t: 40.0 + 45.0 * math.exp(-t / 0.07), dur), decay(0.14))
    dull = env(filt(noise(dur), "lp", 420, 0.9), decay(0.05))
    tracks = [gain(thud, 1.2), gain(dull, 0.7)]
    for t0 in (0.09, 0.15, 0.27, 0.34):
        tick = env(filt(noise(0.2), "hp", 2600, 1.0), decay(0.01))
        tracks.append(delay(gain(tick, 0.28), t0))
    return mix(*tracks)


def s_wail():
    """Die Totenklage: ein hohler, schwankender Ton."""
    dur = 1.5
    x = osc("sine", lambda t: 330.0 - 70.0 * smooth(t, 0.2, 1.4), dur, 0.03, 5.5)
    y = osc("saw", lambda t: 331.0 - 70.0 * smooth(t, 0.2, 1.4), dur, 0.03, 5.0)
    y = filt(y, "bp", 600, 2.0)
    z = filt(noise(dur), "bp", 900, 3.0)
    mixed = mix(x, gain(y, 0.6), gain(z, 0.18))
    return env(mixed, lambda t: smooth(t, 0.0, 0.35) * (1.0 - smooth(t, 0.9, 1.5)))


def s_shield():
    """Der Schild wird hochgerissen: Holz klackt, Eisenbeschlag scheppert."""
    dur = 0.5
    knock = env(osc("sine", lambda t: 260.0 - 80.0 * min(t / 0.04, 1.0), dur), decay(0.045))
    rim = env(osc("sine", 1700.0, dur), decay(0.06))
    scrape = env(sweep(noise(dur), "bp", lambda t: 1800.0 - 900.0 * min(t / 0.15, 1.0), 1.0), lambda t: math.exp(-t / 0.05))
    return mix(gain(knock, 1.0), gain(rim, 0.25), gain(scrape, 0.5), delay(gain(knock, 0.5), 0.1))


def s_kraken_roar():
    """Gewaltiges Bruellen aus der Tiefe."""
    dur = 2.0
    f_base = lambda t: 52.0 + 18.0 * math.sin(math.pi * min(t / 1.4, 1.0))
    x = osc("saw", lambda t: f_base(t) * (1.0 + 0.08 * math.sin(TAU * 17.0 * t)), dur)
    x = sweep(x, "lp", lambda t: 200.0 + 750.0 * math.sin(math.pi * min(t / 1.5, 1.0)), 1.4)
    air = sweep(noise(dur), "bp", lambda t: 300.0 + 500.0 * math.sin(math.pi * min(t / 1.5, 1.0)), 1.0)
    return env(mix(x, gain(air, 0.5)), lambda t: smooth(t, 0.0, 0.25) * (1.0 - smooth(t, 1.3, 2.0)))


def s_tentacle():
    """Nasser, schwerer Schlag eines Fangarms."""
    dur = 0.7
    slap = env(filt(noise(dur), "lp", 1100, 0.9), decay(0.05))
    thump = env(osc("sine", lambda t: 60.0 + 60.0 * math.exp(-t / 0.05), dur), decay(0.1))
    squelch = env(sweep(noise(dur), "bp", lambda t: 1500.0 - 1000.0 * min(t / 0.25, 1.0), 2.5), lambda t: math.exp(-t / 0.12))
    return mix(gain(slap, 1.0), gain(thump, 1.1), delay(gain(squelch, 0.5), 0.03))


def s_ink():
    """Blubbernde Tintenwolke."""
    dur = 1.2
    tracks = [env(filt(noise(dur), "lp", 500, 0.8), lambda t: smooth(t, 0.0, 0.15) * math.exp(-t / 0.5)) ]
    for _ in range(9):
        t0 = random.uniform(0.0, 0.8)
        f0 = random.uniform(130, 260)
        bub = env(osc("sine", lambda t, f0=f0: f0 * (1.0 + 1.6 * min(t / 0.07, 1.0)), 0.12), decay(0.04))
        tracks.append(delay(gain(bub, 0.35), t0))
    return mix(*tracks)


def s_heroic():
    """Heldenmut: ein heller Hornruf nach oben, getragen von einem vollen Akkord."""
    dur = 1.5
    tracks = []
    for t0, f, d in ((0.0, 293.66, 0.16), (0.16, 440.0, 0.16), (0.32, 587.33, 1.1)):
        tone = mix(osc("saw", f, d + 0.1, 0.004, 5.5), gain(osc("square", f * 2.0, d + 0.1), 0.18))
        tone = filt(tone, "lp", 2600, 0.9)
        tone = env(tone, lambda t, d=d: smooth(t, 0.0, 0.02) * (1.0 - smooth(t, d * 0.7, d + 0.1)))
        tracks.append(delay(gain(tone, 0.8), t0))
    chord = mix(*[gain(osc("saw", f, 1.2), a) for f, a in ((146.83, 1.0), (220.0, 0.7), (293.66, 0.6), (369.99, 0.4))])
    chord = filt(chord, "lp", 1500, 0.8)
    chord = env(chord, lambda t: smooth(t, 0.0, 0.25) * (1.0 - smooth(t, 0.7, 1.2)))
    shine = env(filt(noise(dur), "hp", 5000, 0.8), lambda t: smooth(t, 0.0, 0.01) * math.exp(-t / 0.35))
    tracks.append(delay(gain(chord, 0.5), 0.3))
    tracks.append(delay(gain(shine, 0.25), 0.32))
    return mix(*tracks)


def s_snap():
    """Zusammenbruch: etwas reisst wie Glas, darunter sackt ein dunkler Ton ab, zwei schwere Herzschlaege."""
    dur = 1.5
    crack = env(filt(noise(dur), "hp", 3200, 0.9), decay(0.025))
    glass = mix(*[gain(env(osc("sine", f, dur), decay(0.09)), a) for f, a in ((2100.0, 0.5), (3300.0, 0.3), (4700.0, 0.2))])
    fall = osc("saw", lambda t: 260.0 * math.exp(-t / 0.7) + 48.0, dur, 0.02, 6.0)
    fall = filt(fall, "lp", 520, 1.0)
    fall = env(fall, lambda t: smooth(t, 0.0, 0.05) * math.exp(-t / 0.65))
    beat = mix(*[delay(env(osc("sine", lambda t: 40.0 + 30.0 * math.exp(-t / 0.05), 0.4), decay(0.1)), t0) for t0 in (0.35, 0.65)])
    return mix(gain(crack, 0.7), gain(glass, 0.5), gain(fall, 0.9), gain(beat, 0.9))


def s_musket():
    """Musketenschuss: scharfer Knall, tiefer Schlag, Pulverrauch faucht nach."""
    dur = 1.0
    crack = env(sweep(noise(dur), "lp", lambda t: 6500.0 * math.exp(-t / 0.03) + 500.0, 0.8), decay(0.05))
    boom = env(osc("sine", lambda t: 62.0 + 80.0 * math.exp(-t / 0.05), dur), decay(0.16))
    tail = env(filt(noise(dur), "lp", 260, 0.9), decay(0.25))
    hiss = env(filt(noise(dur), "hp", 3500, 0.8), lambda t: smooth(t, 0.0, 0.02) * math.exp(-t / 0.18))
    return mix(gain(crack, 1.0), gain(boom, 1.1), gain(tail, 0.6), delay(gain(hiss, 0.18), 0.03))


def s_pistol():
    """Pistole: kurz, hell, trocken."""
    dur = 0.5
    crack = env(filt(noise(dur), "hp", 1800, 0.8), decay(0.018))
    pop = env(osc("sine", lambda t: 110.0 + 120.0 * math.exp(-t / 0.02), dur), decay(0.05))
    tail = env(filt(noise(dur), "lp", 900, 0.9), decay(0.07))
    return mix(gain(crack, 1.0), gain(pop, 0.9), gain(tail, 0.5))


def s_reload():
    """Ladestock und Hahn: Metall klickt, ein Ruck, der Hahn rastet ein."""
    dur = 0.7
    tracks = []
    for t0, f, a in ((0.0, 1900.0, 0.5), (0.13, 2400.0, 0.8), (0.31, 1500.0, 0.6), (0.46, 2800.0, 1.0)):
        click = mix(env(osc("sine", f, 0.1), decay(0.008)), gain(env(filt(noise(0.1), "bp", f, 1.2), decay(0.006)), 0.8))
        tracks.append(delay(gain(click, a), t0))
    scrape = env(sweep(noise(dur), "bp", lambda t: 1200.0 + 2200.0 * min(t / 0.25, 1.0), 2.0), lambda t: smooth(t, 0.1, 0.14) * (1.0 - smooth(t, 0.22, 0.3)))
    tracks.append(gain(scrape, 0.35))
    return mix(*tracks)


def s_bones():
    """Knochen klappern und fuegen sich zusammen."""
    dur = 1.0
    tracks = []
    for _ in range(14):
        t0 = random.uniform(0.0, 0.7)
        f = random.uniform(700, 1800)
        tick = mix(env(osc("sine", f, 0.1), decay(0.01)), gain(env(filt(noise(0.1), "hp", 2500, 0.9), decay(0.005)), 0.5))
        tracks.append(delay(gain(tick, random.uniform(0.3, 0.9)), t0))
    whoosh = sweep(noise(dur), "bp", lambda t: 300.0 + 900.0 * t, 1.5)
    whoosh = env(whoosh, lambda t: smooth(t, 0.0, 0.4) * (1.0 - smooth(t, 0.6, 1.0)))
    tracks.append(gain(whoosh, 0.35))
    return mix(*tracks)


# --- Spielautomaten ----------------------------------------------------------

def read_wav(path):
    """Eine WAV-Datei (16 Bit, mono) als Liste von -1..1 und ihre Abtastrate."""
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        ch = w.getnchannels()
        raw = w.readframes(w.getnframes())
    vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
    return [v / 32768.0 for v in vals[::ch]], rate


def resample(x, rate_in, ratio):
    """Mit ratio < 1 abspielen: tiefer und langsamer (ratio 0,5 = eine Oktave tiefer)."""
    step = ratio * rate_in / SR
    out = []
    pos = 0.0
    last = len(x) - 1
    while pos < last:
        i = int(pos)
        f = pos - i
        out.append(x[i] * (1 - f) + x[i + 1] * f)
        pos += step
    return out


def drive(x, k):
    d = math.tanh(k)
    return [math.tanh(k * v) / d for v in x]


def ping(f, dur, tau):
    return env(mix(osc("sine", f, dur), gain(osc("sine", f * 2.76, dur), 0.35), gain(osc("sine", f * 5.4, dur), 0.12)), decay(tau))


def brass(f, dur, att=0.05, rel=0.25):
    x = mix(osc("saw", f, dur), gain(osc("saw", f * 1.005, dur), 0.8), gain(osc("sine", f * 0.5, dur), 0.5))
    x = sweep(x, "lp", lambda t: 700.0 + 2400.0 * smooth(t, 0.0, 0.25), 0.9)
    return env(x, lambda t: smooth(t, 0.0, att) * (1.0 - smooth(t, dur - rel, dur)))


def s_slot_lever():
    """Hebel: Ratschen beim Herunterziehen, dumpfer Schlag am Ende."""
    ticks = []
    for k in range(7):
        t0 = 0.02 + k * 0.045
        ticks.append(delay(gain(env(filt(noise(0.05), "bp", 3200 - 150 * k, 2.0), decay(0.004)), 0.8), t0))
    clunk = delay(mix(env(osc("sine", lambda t: 95.0 - 40.0 * t, 0.3), decay(0.07)), gain(env(filt(noise(0.2), "lp", 900, 0.8), decay(0.02)), 0.8)), 0.34)
    return mix(*ticks, clunk)


def s_slot_spin():
    """Walzen laufen an: Surren mit schnellem Ticken."""
    dur = 0.9
    whirr = sweep(noise(dur), "bp", lambda t: 500.0 + 700.0 * smooth(t, 0.0, 0.4), 1.2)
    whirr = env(whirr, lambda t: (0.6 + 0.4 * math.sin(TAU * 24.0 * t)) * smooth(t, 0.0, 0.08) * (1 - smooth(t, 0.8, 0.9)))
    ticks = []
    for k in range(18):
        ticks.append(delay(gain(env(filt(noise(0.03), "hp", 2000, 1.0), decay(0.003)), 0.5), 0.02 + k * 0.047))
    return mix(gain(whirr, 0.6), *ticks)


def s_slot_stop():
    """Eine Walze rastet ein."""
    thunk = env(osc("sine", lambda t: 150.0 - 80.0 * min(t * 8.0, 1.0), 0.25), decay(0.05))
    click = env(filt(noise(0.1), "bp", 1800, 1.5), decay(0.006))
    return mix(thunk, gain(click, 0.7))


def s_slot_tick():
    return mix(env(osc("sine", 1900, 0.05), decay(0.005)), gain(env(noise(0.05), decay(0.002)), 0.3))


def s_slot_win1():
    return mix(*[delay(gain(ping(f, 0.6, 0.14), 0.8), k * 0.085) for k, f in enumerate((1046.5, 1318.5, 1568.0))])


def s_slot_win2():
    tracks = [delay(gain(ping(f, 0.9, 0.2), 0.7), k * 0.09) for k, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0, 1568.0, 2093.0))]
    tracks.append(gain(brass(262.0, 0.9), 0.4))
    tracks.append(delay(gain(brass(392.0, 0.9), 0.4), 0.0))
    return mix(*tracks)


def s_slot_win3():
    tracks = []
    for k, f in enumerate((523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0, 2093.0, 2637.0)):
        tracks.append(delay(gain(ping(f, 1.4, 0.3), 0.6), k * 0.075))
    for t0, f in ((0.0, 196.0), (0.5, 261.6), (1.0, 329.6)):
        tracks.append(delay(gain(brass(f, 1.2, 0.04, 0.35), 0.45), t0))
    tracks.append(delay(gain(brass(392.0, 1.6, 0.04, 0.5), 0.5), 1.0))
    tracks.append(delay(gain(s_slot_coins_core(1.8, 90), 0.5), 0.3))
    return mix(*tracks)


def s_slot_coins_core(dur, count):
    tracks = []
    for _ in range(count):
        t0 = (random.random() ** 1.7) * dur
        f = random.choice((1760.0, 2093.0, 2349.0, 2637.0, 3136.0))
        tracks.append(delay(gain(ping(f * random.uniform(0.97, 1.03), 0.35, 0.05), random.uniform(0.15, 0.5)), t0))
    return mix(*tracks)


def s_slot_coins():
    return s_slot_coins_core(2.2, 120)


def s_slot_jackpot():
    dur = 4.2
    tracks = []
    for t0, f in ((0.0, 98.0), (0.0, 147.0), (0.7, 130.8), (1.4, 196.0), (2.1, 261.6)):
        tracks.append(delay(gain(brass(f, 2.4 if t0 > 1.0 else 1.8, 0.2, 0.9), 0.55), t0))
    for k in range(10):
        tracks.append(delay(gain(ping(784.0 * (1.0 + 0.25 * (k % 5)), 1.6, 0.4), 0.45), 0.5 + k * 0.17))
    tracks.append(gain(s_thunder(), 0.7))
    tracks.append(delay(gain(s_slot_coins_core(2.4, 160), 0.6), 1.2))
    tracks.append(delay(gain(s_bell(), 0.5), 0.4))
    return mix(*tracks)


def s_slot_tease():
    """Trommelwirbel, immer schneller, mit steigendem Ton: gleich entscheidet es sich."""
    dur = 1.5
    tracks = []
    t = 0.0
    gap = 0.2
    while t < dur - 0.05:
        a = 0.35 + 0.65 * (t / dur)
        hit = mix(env(osc("sine", 90.0 + 30.0 * (t / dur), 0.2), decay(0.04)), gain(env(filt(noise(0.15), "lp", 1500, 0.8), decay(0.012)), 0.6))
        tracks.append(delay(gain(hit, a), t))
        gap = max(gap * 0.88, 0.035)
        t += gap
    rise = osc("saw", lambda tt: 110.0 * math.exp(1.1 * tt), dur)
    rise = sweep(rise, "lp", lambda tt: 500.0 + 3000.0 * (tt / dur), 1.0)
    rise = env(rise, lambda tt: smooth(tt, 0.0, 1.2) * (1 - smooth(tt, 1.4, 1.5)))
    tracks.append(gain(rise, 0.25))
    return mix(*tracks)


def s_slot_zap():
    dur = 0.55
    x = [0.0] * n(dur)
    i = 0
    while i < len(x):
        burst = random.randint(40, 260)
        amp = random.uniform(0.3, 1.0)
        for j in range(burst):
            if i + j < len(x):
                x[i + j] = random.uniform(-1.0, 1.0) * amp
        i += burst + random.randint(30, 500)
    x = filt(x, "bp", 3500, 0.7)
    buzz = env(osc("saw", 60.0, dur), lambda t: 0.4 * math.exp(-t / 0.3))
    return mix(env(x, lambda t: math.exp(-t / 0.28)), gain(filt(buzz, "lp", 600, 0.8), 0.7))


def s_slot_coil():
    """Tesla-Spule fährt hoch: Summen, das ansteigt, dazu Knistern."""
    dur = 1.8
    hum = osc("saw", lambda t: 55.0 * math.exp(1.15 * t), dur)
    hum = sweep(hum, "lp", lambda t: 400.0 + 2600.0 * (t / dur), 1.1)
    hum = env(hum, lambda t: smooth(t, 0.0, 0.5) * (1 - smooth(t, 1.7, 1.8)))
    crackle = env(filt(noise(dur), "hp", 3500, 0.8), lambda t: (random.random() < 0.18) * smooth(t, 0.3, 1.5) * 0.5)
    return mix(hum, gain(crackle, 0.5))


def s_slot_alive():
    """It's alive! Donner, zweimal die tiefe, verzerrte Stimme, dazu Chor aus Sägezähnen und Blitze."""
    here = os.path.dirname(os.path.abspath(__file__))
    voice, rate = read_wav(os.path.join(here, "voice", "its_alive.wav"))
    mx = max(abs(v) for v in voice) or 1.0
    voice = [v / mx for v in voice]
    first = next(i for i, v in enumerate(voice) if abs(v) > 0.03)
    last = len(voice) - next(i for i, v in enumerate(reversed(voice)) if abs(v) > 0.03)
    voice = voice[max(first - 200, 0):last]

    def shout(r1, r2, k2, drv):
        x = mix(resample(voice, rate, r1), gain(resample(voice, rate, r2), k2))
        x = drive(x, drv)
        x = filt(x, "lp", 5200, 0.8)
        return mix(x, gain(delay(x, 0.08), 0.35), gain(delay(x, 0.19), 0.2))

    one = delay(env(shout(0.62, 0.46, 0.75, 3.2), lambda t: min(1.0, t * 60.0)), 0.55)
    two = delay(env(shout(0.78, 0.6, 0.7, 4.0), lambda t: min(1.0, t * 60.0)), 2.2)
    dur = 4.0
    choir = []
    for f in (73.4, 110.0, 146.8):
        choir.append(filt(osc("saw", f, dur, 0.004, 5.5), "lp", 900, 1.0))
    choir = env(mix(*choir), lambda t: smooth(t, 0.3, 1.6) * (1 - smooth(t, 3.3, 4.0)))
    boom = env(osc("sine", lambda t: 70.0 - 30.0 * min(t, 1.0), 1.4), lambda t: math.exp(-t / 0.5))
    zaps = mix(delay(s_slot_zap(), 0.1), delay(s_slot_zap(), 0.45), delay(s_slot_zap(), 1.1), delay(s_slot_zap(), 2.2), delay(s_slot_zap(), 2.7), delay(s_slot_zap(), 3.2))
    thunder = s_thunder()
    crack = env(thunder[:n(1.6)], lambda t: 1.0 - smooth(t, 1.1, 1.6))
    return filt(mix(gain(thunder, 0.8), gain(delay(crack, 2.2), 0.7), gain(boom, 0.9), gain(delay(boom, 2.2), 0.8),
                    gain(one, 1.4), gain(two, 1.6), gain(choir, 0.22), gain(zaps, 0.55)), "hp", 32, 0.7)

def s_slot_flip():
    """Münze wirbelt hoch und landet."""
    spin = env(osc("sine", lambda t: 1800.0 + 1200.0 * math.sin(TAU * 7.0 * t), 0.6), lambda t: 0.3 * smooth(t, 0.0, 0.05) * (1 - smooth(t, 0.4, 0.55)))
    land = delay(mix(ping(1568.0, 0.5, 0.08), gain(ping(2093.0, 0.5, 0.06), 0.6), gain(env(filt(noise(0.1), "hp", 3000, 0.8), decay(0.01)), 0.4)), 0.5)
    return mix(spin, land)


def s_slot_lose():
    dur = 0.9
    f = lambda t: 330.0 * math.exp(-0.9 * t)
    x = sweep(osc("saw", f, dur, 0.02, 6.0), "lp", lambda t: 1400.0 - 700.0 * t, 1.0)
    return env(x, lambda t: smooth(t, 0.0, 0.05) * (1 - smooth(t, 0.7, 0.9)))


def s_slot_curse():
    """Lokis Streich: tiefes Grollen, fallender Tritonus, Kichern aus Rauschen."""
    dur = 1.8
    growl = sweep(osc("saw", lambda t: 62.0 + 6.0 * math.sin(TAU * 7.0 * t), dur), "lp", lambda t: 380.0, 1.2)
    growl = env(growl, lambda t: smooth(t, 0.0, 0.1) * (1 - smooth(t, 1.4, 1.8)))
    tri = mix(env(osc("sine", lambda t: 466.0 * math.exp(-0.5 * t), 1.2), decay(0.5)), env(osc("sine", lambda t: 329.6 * math.exp(-0.5 * t), 1.2), decay(0.5)))
    giggle = []
    for k in range(7):
        giggle.append(delay(gain(env(filt(noise(0.09), "bp", 1500 + 120 * (k % 3), 3.0), lambda t: math.sin(math.pi * min(t / 0.09, 1.0))), 0.7), 0.5 + k * 0.11))
    return mix(gain(growl, 0.9), gain(tri, 0.5), *giggle)


def s_slot_power():
    """Multiplikator: aufsteigender Sweep mit hellem Ping."""
    dur = 1.0
    x = sweep(osc("saw", lambda t: 220.0 * math.exp(1.6 * t), dur), "lp", lambda t: 800.0 + 3000.0 * t, 1.0)
    x = env(x, lambda t: smooth(t, 0.0, 0.05) * (1 - smooth(t, 0.85, 1.0)))
    return mix(gain(x, 0.5), delay(gain(ping(2093.0, 0.8, 0.2), 0.8), 0.7), delay(gain(ping(3136.0, 0.8, 0.2), 0.6), 0.78))


def s_slot_stack():
    return mix(gain(s_slot_zap(), 0.9), delay(gain(env(osc("sine", lambda t: 90.0 - 40.0 * t, 0.6), decay(0.12)), 0.9), 0.0))


SOUNDS = {
    "click": (s_click, 1.0),
    "horn": (s_horn, 0.8),
    "sail": (s_sail, 0.7),
    "creak": (s_creak, 0.75),
    "crash": (s_crash, 0.85),
    "wave": (s_wave, 0.8),
    "gust": (s_gust, 0.7),
    "splash": (s_splash, 0.8),
    "rope": (s_rope, 0.65),
    "rescue_ok": (s_rescue_ok, 0.7),
    "drown": (s_drown, 0.75),
    "death": (s_death, 0.85),
    "hammer": (s_hammer, 0.75),
    "coin": (s_coin, 0.6),
    "thunder": (s_thunder, 0.85),
    "bell": (s_bell, 0.7),
    "sting": (s_sting, 0.85),
    "heartbeat": (s_heartbeat, 0.8),
    "mug": (s_mug, 0.7),
    "fog": (s_fog, 0.7),
    "cannon": (s_cannon, 0.85),
    "swing": (s_swing, 0.7),
    "whiff": (s_whiff, 0.5),
    "slash": (s_slash, 0.8),
    "clash": (s_clash, 0.75),
    "chop": (s_chop, 0.85),
    "bash": (s_bash, 0.85),
    "bow": (s_bow, 0.75),
    "arrow_hit": (s_arrow_hit, 0.8),
    "bite": (s_bite, 0.75),
    "heal": (s_heal, 0.65),
    "harp": (s_harp, 0.65),
    "warsong": (s_warsong, 0.75),
    "fall": (s_fall, 0.8),
    "wail": (s_wail, 0.65),
    "shield": (s_shield, 0.75),
    "kraken_roar": (s_kraken_roar, 0.9),
    "tentacle": (s_tentacle, 0.85),
    "ink": (s_ink, 0.6),
    "heroic": (s_heroic, 0.8),
    "snap": (s_snap, 0.85),
    "musket": (s_musket, 0.9),
    "pistol": (s_pistol, 0.8),
    "reload": (s_reload, 0.7),
    "bones": (s_bones, 0.7),
    "slot_lever": (s_slot_lever, 0.8),
    "slot_spin": (s_slot_spin, 0.6),
    "slot_stop": (s_slot_stop, 0.8),
    "slot_tick": (s_slot_tick, 0.5),
    "slot_win1": (s_slot_win1, 0.7),
    "slot_win2": (s_slot_win2, 0.8),
    "slot_win3": (s_slot_win3, 0.85),
    "slot_coins": (s_slot_coins, 0.7),
    "slot_jackpot": (s_slot_jackpot, 0.9),
    "slot_tease": (s_slot_tease, 0.8),
    "slot_zap": (s_slot_zap, 0.75),
    "slot_coil": (s_slot_coil, 0.7),
    "slot_alive": (s_slot_alive, 0.95),
    "slot_flip": (s_slot_flip, 0.7),
    "slot_lose": (s_slot_lose, 0.6),
    "slot_curse": (s_slot_curse, 0.8),
    "slot_power": (s_slot_power, 0.75),
    "slot_stack": (s_slot_stack, 0.85),
}


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(v * 32767)))) for v in x))


def png(path, w, h, rows):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(rows[y])

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def preview(path, rendered):
    """Ein Streifen pro Klang: Lautstaerkeverlauf ueber 4 Sekunden, Beschriftung als Farbblock links."""
    width, row_h, bins = 640, 30, 560
    h = row_h * len(rendered)
    rows = [bytearray([14, 16, 22] * width) for _ in range(h)]
    for r, (name, x) in enumerate(rendered):
        per_bin = SR * 4.0 / bins
        for b in range(bins):
            seg = x[int(b * per_bin):int((b + 1) * per_bin)]
            if not seg:
                break
            amp = max(abs(v) for v in seg)
            half = int(amp * (row_h // 2 - 2))
            cy = r * row_h + row_h // 2
            for y in range(cy - half, cy + half + 1):
                px = 70 + b
                rows[y][px * 3:px * 3 + 3] = bytes([210, 180, 90])
        for y in range(r * row_h + 2, r * row_h + row_h - 2):
            rows[y][4 * 3:60 * 3] = bytes([60 + (r * 37) % 120, 90, 120 + (r * 53) % 100]) * 56
    png(path, width, h, rows)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "sfx")
    rendered = []
    print("%-11s %6s %6s %6s %7s" % ("Klang", "Dauer", "Spitze", "Effekt", "Mittel"))
    for name, (fn, peak) in SOUNDS.items():
        x = finish(fn(), peak)
        rendered.append((name, x))
        save(os.path.join(out, name + ".wav"), x)
        rms = math.sqrt(sum(v * v for v in x) / len(x))
        dc = sum(x) / len(x)
        print("%-11s %5.2fs %6.2f %6.3f %7.4f" % (name, len(x) / SR, max(abs(v) for v in x), rms, dc))
    print("%d Klaenge nach assets/sfx geschrieben" % len(rendered))
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(folder, exist_ok=True)
        preview(os.path.join(folder, "sfx_overview.png"), rendered)
        print("Vorschau:", folder)


if __name__ == "__main__":
    main()
