import os
import sys
from PIL import Image

def encode(png):
    im = Image.open(png)
    assert im.size == (40, 32)

    c = 0
    bitmap = []
    for y in range(32):
        for x in range(0, 40, 8):
            b = 0
            for x2 in range(8):
                p = im.getpixel((x+x2, y))
                assert p in (0, 1)
                if p == 1:
                    c += 1
                b = (b << 1) | p
            bitmap.append(b)

    output = os.path.splitext(png)[0] + ".bin"
    with open(output, "wb") as f:
        f.write(chr(c & 0xff))
        f.write(chr(c >> 8))
        for b in bitmap:
            f.write(chr(b))
    return output

with open("res/panel-templates.asm", "w") as f:
    f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])

    labels = []
    for png in sys.argv[1:]:
        label = "panel_template_" + os.path.splitext(os.path.basename(png))[0].replace("-", "_")
        labels.append(label)
        output = os.path.basename(encode(png))
        f.write(".%s\n" % label)
        f.write('    incbin "../res/%s"\n' % output)
    f.write("\nnum_panel_templates = %d\n" % len(labels))
    f.write(".panel_template_list\n")
    for label in labels:
        f.write("    equw %s\n" % label)

