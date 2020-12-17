#!/bin/sh
# TODO: Ideally this would work with both Python 2 and 3...
set -e
python decode-teletext.py res/menu-template.txt res/menu-template.bin
python decode-teletext.py --led res/menu-led-template.txt res/menu-led-template.asm
python encode-panel.py res/*.png
python encode-led-shapes.py res/led-shapes.asm
python make-random.py res/led-freq-spread.asm # SFTODO: RENAME THIS .PY
python make-random-tables.py res/random-tables.asm
cd src
beebasm -w -v -i top.asm -do ../blinkenlights.ssd -opt 3 > ../top.lst
