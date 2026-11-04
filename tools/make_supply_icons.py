"""Symbole der Vorräte und des Fokus (reines Python, nur Standardbibliothek).

Aufruf aus dem Projektordner:
    python -X utf8 -I tools/make_supply_icons.py [--preview ordner]

Schreibt assets/supply_icons.png: ein Streifen aus 16x16-Feldern, Reihenfolge ORDER (wie Supplies.ORDER in
scripts/supplies.gd, danach "fokus"). Jedes Symbol hat einen eigenen 1-Pixel-Umriss (#), damit es auf Holz, Stein
und Nachtblau gleich gut steht.
"""
import os
import struct
import sys
import zlib

PAL = {
    "#": (13, 11, 16), "w": (228, 220, 196), "W": (250, 246, 236), "g": (163, 155, 132), "G": (110, 104, 90),
    "r": (200, 69, 61), "R": (122, 36, 36),
    "b": (122, 84, 52), "B": (78, 52, 32), "n": (164, 118, 72),          # Holz
    "k": (36, 30, 34), "K": (64, 56, 60),                                  # Teer
    "a": (176, 214, 226), "A": (110, 150, 168), "s": (214, 168, 74),       # Glas, Schnaps
    "i": (170, 176, 186), "I": (110, 116, 128), "c": (226, 230, 236),      # Eisen
    "y": (224, 184, 74), "h": (246, 220, 90), "Y": (168, 132, 42),         # Gold
    "v": (169, 127, 214), "V": (98, 66, 140), "q": (214, 190, 240),        # Violett (Fokus)
}

ICONS = [
    ("verband", [
        "................",
        "................",
        "....##########..",
        "...#gwwwwwwwwww#",
        "..#gg#wwwwwwwww#",
        "..#g#g#wwwwwwww#",
        "..#g#gWrrrrrrrr#",
        "..#g#g#wwwwwwww#",
        "..#gg#wwwwwwwww#",
        "...#gwwwwwwwwwg#",
        "....###########.",
        "..........#wW#..",
        ".........#wr#...",
        "........#wW#....",
        ".......#ww#.....",
        "........##......",
    ]),
    ("schnaps", [
        "................",
        "......####......",
        "......#BB#......",
        "......#nn#......",
        ".......##.......",
        "......#aa#......",
        ".....#aAAa#.....",
        "....#aAAAAa#....",
        "...#aassssAa#...",
        "...#asshsssA#...",
        "...#assssssA#...",
        "...#asssssYA#...",
        "...#aAsssYYA#...",
        "....#AAAAAA#....",
        ".....######.....",
        "................",
    ]),
    ("teer", [
        "................",
        "....#######.....",
        "...#kKkkkKk#....",
        "..#bbbbbbbbb#...",
        "..#iiiiiiiii#...",
        "..#bnbbbnbbb#...",
        ".#bbnbbbnbbbb#..",
        ".#bbnbbbnbbbb#..",
        ".#iiiiiiiiiii#..",
        ".#bbnbbbnbbbb#..",
        ".#bbnbbbnbbbB#..",
        "..#bnbbbnbbB#...",
        "..#iiiiiiiii#...",
        "..#BbbbbbbBB#...",
        "...#########....",
        "................",
    ]),
    ("harpune", [
        "............##..",
        "...........#cc#.",
        "..........#ciI#.",
        ".........#ciI##.",
        "........#ciI#.#.",
        ".......##iI#....",
        "......#bn##.....",
        ".....#bn#.......",
        "....#bn#........",
        "...#bn#.........",
        "..#bn#..........",
        ".#gB#...........",
        "#g#g#...........",
        "#gG#............",
        ".##.............",
        "................",
    ]),
    ("fokus", [
        "................",
        "......####......",
        "....##vvvv##....",
        "...#vvqqqqvv#...",
        "..#vq######qv#..",
        ".#vq#wwwwww#qv#.",
        "#vq#wwW##Www#qv#",
        "#vq#wW#hh#Ww#qv#",
        "#vq#wW#hh#Ww#qv#",
        "#vq#wwW##Www#qv#",
        ".#vq#wwwwww#qv#.",
        "..#vq######qv#..",
        "...#vvqqqqvv#...",
        "....##vVVv##....",
        "......####......",
        "................",
    ]),
]
ORDER = [n for n, _ in ICONS]


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def pixels(sketch):
    return [[PAL[ch] + (255,) if ch in PAL else (0, 0, 0, 0) for ch in row] for row in sketch]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    n = len(ICONS)
    for name, sk in ICONS:
        assert len(sk) == 16 and all(len(r) == 16 for r in sk), name
        for row in sk:
            for ch in row:
                assert ch == "." or ch in PAL, (name, ch)
    rows = [[(0, 0, 0, 0)] * (16 * n) for _ in range(16)]
    for i, (_, sk) in enumerate(ICONS):
        px = pixels(sk)
        for y in range(16):
            for x in range(16):
                rows[y][i * 16 + x] = px[y][x]
    out = os.path.join(here, "..", "assets", "supply_icons.png")
    write_png(out, 16 * n, 16, rows)
    print("geschrieben:", os.path.normpath(out), ORDER)
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(folder, exist_ok=True)
        z, pad = 8, 4
        cell = 16 * z + 2 * pad
        sheet = []
        for band, bg in enumerate([(59, 42, 29), (20, 26, 40)]):
            for y in range(cell):
                sheet.append([bg + (255,)] * (cell * n))
        for band in range(2):
            for i, (_, sk) in enumerate(ICONS):
                px = pixels(sk)
                for y in range(16):
                    for x in range(16):
                        c = px[y][x]
                        if c[3] == 0:
                            continue
                        for dy in range(z):
                            for dx in range(z):
                                sheet[band * cell + pad + y * z + dy][i * cell + pad + x * z + dx] = c
        write_png(os.path.join(folder, "supply_icons_preview.png"), cell * n, cell * 2, sheet)


if __name__ == "__main__":
    sys.exit(main())
