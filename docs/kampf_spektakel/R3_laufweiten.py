import sys, zlib, struct

def load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8
    idat = b''
    w = h = 0
    ct = 0
    while pos < len(d):
        ln, = struct.unpack('>I', d[pos:pos+4])
        typ = d[pos+4:pos+8]
        body = d[pos+8:pos+8+ln]
        if typ == b'IHDR':
            w, h, bd, ct, _, _, _ = struct.unpack('>IIBBBBB', body)
        elif typ == b'IDAT':
            idat += body
        pos += 12 + ln
    bpp = {2: 3, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    i = 0
    for y in range(h):
        f = raw[i]; i += 1
        line = bytearray(raw[i:i+stride]); i += stride
        if f == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x-bpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x-bpp] if x >= bpp else 0
                p = a + b - c
                pa = abs(p - a); pb = abs(p - b); pc = abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows

def px(rows, bpp, x, y):
    r = rows[y]
    return tuple(r[x*bpp:x*bpp+3])

def runs_row(rows, bpp, y, x0, x1, thr=128):
    out = []
    cur = None
    n = 0
    for x in range(x0, x1):
        p = px(rows, bpp, x, y)
        v = sum(p) // 3 > thr
        if v == cur:
            n += 1
        else:
            if cur is not None:
                out.append((cur, n))
            cur = v
            n = 1
    out.append((cur, n))
    return out


# Aufruf: python -I R3_laufweiten.py bild.png [skala_faktor_zoom...]
# Misst in einem Bildschirmfoto der Spielfeldgroesse 480x320 die Breiten hell/dunkel abwechselnder Streifen (Test d/v):
# gleichmaessig = Pixelgitter sauber, ungleich (z. B. 12/6 statt 9/9) = Zoom auf ganzen Spielpixeln gerundet.
if __name__ == '__main__':
    w, h, bpp, rows = load(sys.argv[1])
    S = w / 480.0
    print(sys.argv[1], "Skala", round(S, 3))
    for z in (1.0, 1.5, 2.0):
        s = [1.0, 1.5, 2.0].index(z)
        x = 20.0 + s * 150.0
        yy = int((6.0 + 58.0 * z + 2.0 * z) * S)
        r = runs_row(rows, bpp, yy, int((x - 2) * S), int((x + 16 * z + 2) * S))
        print("%.1fx" % z, [(('H' if v else 'D'), n) for v, n in r])
