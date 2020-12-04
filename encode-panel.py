import sys
from PIL import Image

im = Image.open(sys.argv[1])
assert im.size == (40, 32)

c = 0
bitmap = []
for y in range(32):
    for x in range(0, 40, 8):
        b = 0
        for x2 in range(7, -1, -1):
            p = im.getpixel((x+x2, y))
            assert p in (0, 1)
            if p == 1:
                c += 1
            b = (b << 1) | p
        bitmap.append(b)

with open(sys.argv[2], "wb") as f:
    f.write(chr(c & 0xff))
    f.write(chr(c >> 8))
    for b in bitmap:
        f.write(chr(b))
