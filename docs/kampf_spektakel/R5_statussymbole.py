"""Entwurf der Statussymbole für den Deckkampf (Runde R5, Oberfläche).

Reines Python (nur Standardbibliothek). Aufruf aus dem Projektordner:
    python -X utf8 -I docs/kampf_spektakel/R5_statussymbole.py

Schreibt
    docs/kampf_spektakel/img/r5_status_atlas.png     Streifen aus 9x9-Feldern (so käme es nach assets/status_icons.png)
    docs/kampf_spektakel/img/r5_status_sheet.png     Vorschau, 8-fach vergrößert, auf Deck-Braun und auf Nachtblau

Jedes Symbol ist 9x9 Pixel groß, mit eigenem 1-Pixel-Umriss (#). Die Reihenfolge ist die Spalte im Streifen und gehört
später als Tabelle in scripts/status_icons.gd (wie scripts/skill_icons.gd).
"""
import os
import struct
import sys
import zlib

PAL = {
    "#": (13, 11, 16), "w": (228, 220, 196), "W": (244, 241, 232), "g": (163, 155, 132),
    "r": (200, 69, 61), "R": (122, 36, 36), "l": (238, 122, 102),
    "p": (138, 98, 166), "P": (74, 50, 98), "q": (196, 160, 224),
    "y": (224, 184, 74), "Y": (168, 132, 42), "h": (246, 220, 90),
    "b": (91, 143, 208), "B": (47, 82, 136), "c": (169, 205, 245),
    "k": (42, 32, 56), "o": (232, 144, 58), "e": (92, 174, 90), "E": (176, 228, 140), "D": (40, 92, 52),
}

# Reihenfolge = Spalte im Streifen. Name, Schlüssel für Tooltip-Titel (siehe R5_oberflaeche.md Abschnitt 3).
ICONS = [
    ("schwelle", [
        "..#####..",
        ".#wwwww#.",
        "#wwwwwww#",
        "#w##w##w#",
        "#w#R#R#w#",
        "#wwwWwww#",
        ".#wwwww#.",
        "..#w#w#..",
        "..#####..",
    ]),
    ("griff", [
        "..#####..",
        ".#ppqpp#.",
        "#pp###pp#",
        "#p#...#p#",
        "#p#...#p#",
        "#pp#.#pp#",
        ".#pp#pP#.",
        "..#pppP#.",
        "...####..",
    ]),
    ("blind", [
        "...###...",
        "..#ppp#..",
        ".#pqqpp#.",
        "#ppqppPP#",
        "#pppppPP#",
        "#ppppPPP#",
        ".#pPPPP#.",
        "..#P#P#..",
        "...#.#...",
    ]),
    ("quetschen", [
        "....#....",
        "...#r#...",
        "...#r#...",
        "..#rWr#..",
        "..#rWr#..",
        ".#rrWrr#.",
        ".#rrrrr#.",
        "#rrrWrrr#",
        "#########",
    ]),
    ("betaeubt", [
        "....#....",
        "...#y#...",
        "..#yhy#..",
        ".##yyy##.",
        "#yyyhyyy#",
        ".##yyy##.",
        "..#yhy#..",
        "...#y#...",
        "....#....",
    ]),
    ("blutet", [
        "....#....",
        "...#r#...",
        "...#r#...",
        "..#rrr#..",
        "..#rlr#..",
        ".#rrlrr#.",
        ".#rrrrr#.",
        "..#rrR#..",
        "...###...",
    ]),
    ("markiert", [
        "..#####..",
        ".#rrrrr#.",
        "#rr###rr#",
        "#r#rrr#r#",
        "#r#rWr#r#",
        "#r#rrr#r#",
        "#rr###rr#",
        ".#rrrrr#.",
        "..#####..",
    ]),
    ("schildwall", [
        ".#######.",
        "#bbbbbbb#",
        "#bcbbbBb#",
        "#bcbhbBb#",
        "#bbhhhbB#",
        "#bbbhbbB#",
        ".#bbbbB#.",
        "..#bbB#..",
        "...###...",
    ]),
    ("kriegslied", [
        "....#....",
        "...#e#...",
        "..#eEe#..",
        ".#eeEee#.",
        "#eeeEeee#",
        ".##eEe##.",
        "...#e#...",
        "...#D#...",
        "...###...",
    ]),
    # zweite Stufe (Zustände, die es im Kampf gibt, aber heute nirgends sichtbar sind)
    ("spott", [
        "..#####..",
        ".#ooWoo#.",
        "#oooWooo#",
        "#oooWooo#",
        "#oooWooo#",
        "#ooooooo#",
        "#oooWooo#",
        ".#ooooo#.",
        "..#####..",
    ]),
    ("panik", [
        "....####.",
        "...#ccc#.",
        "..#ccc#..",
        ".#ccc#...",
        "#cccccc#.",
        ".###cc#..",
        "...#cc#..",
        "...#c#...",
        "...##....",
    ]),
    ("leer", [
        "....#....",
        "...#g#...",
        "..#g.g#..",
        "..#g.g#..",
        "..#g.g#..",
        "..#g.g#..",
        "..#g.g#..",
        ".#######.",
        ".........",
    ]),
]


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def icon_pixels(sketch):
    return [[PAL[ch] + (255,) if ch in PAL else (0, 0, 0, 0) for ch in row] for row in sketch]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "img")
    os.makedirs(out, exist_ok=True)
    n = len(ICONS)
    for name, sk in ICONS:
        assert len(sk) == 9 and all(len(r) == 9 for r in sk), name
    rows = [[(0, 0, 0, 0)] * (9 * n) for _ in range(9)]
    for i, (_, sk) in enumerate(ICONS):
        px = icon_pixels(sk)
        for y in range(9):
            for x in range(9):
                rows[y][i * 9 + x] = px[y][x]
    write_png(os.path.join(out, "r5_status_atlas.png"), 9 * n, 9, rows)
    # Vorschau: 8-fach, zwei Hintergründe (Deck-Braun, Nachtblau), je Symbol ein Feld mit 2 Pixel Rand
    z, pad = 8, 3
    cell = 9 * z + pad * 2
    W, H = cell * n, cell * 2
    sheet = [[(0, 0, 0, 255)] * W for _ in range(H)]
    for band, bg in enumerate([(59, 42, 29), (20, 26, 40)]):
        for y in range(cell):
            for x in range(W):
                sheet[band * cell + y][x] = bg + (255,)
        for i, (_, sk) in enumerate(ICONS):
            px = icon_pixels(sk)
            for y in range(9):
                for x in range(9):
                    c = px[y][x]
                    if c[3] == 0:
                        continue
                    for dy in range(z):
                        for dx in range(z):
                            sheet[band * cell + pad + y * z + dy][i * cell + pad + x * z + dx] = c
    write_png(os.path.join(out, "r5_status_sheet.png"), W, H, sheet)
    print("geschrieben:", os.path.join(out, "r5_status_atlas.png"), os.path.join(out, "r5_status_sheet.png"))


if __name__ == "__main__":
    sys.exit(main())
