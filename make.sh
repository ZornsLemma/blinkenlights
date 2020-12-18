#!/bin/sh
# TODO: Ideally this would work with both Python 2 and 3...
set -e
mkdir -p tmp
cd src
RES=../res
TMP=../tmp
python decode-teletext.py $RES/menu-template.txt $TMP/menu-template.bin
python decode-teletext.py --led $RES/menu-led-template.txt $TMP/menu-led-template.asm
python encode-panel.py $RES/*.png
python encode-led-shapes.py $TMP/led-shapes.asm
python make-led-freq-spread.py $TMP/led-freq-spread.asm
python make-random-tables.py $TMP/random-tables.asm
beebasm -w -v -i top.asm -do ../blinkenlights.ssd -opt 3 > ../top.lst
# TODO: Add a LICENCE file? Seems a bit overkill but probably a good idea. MIT?
