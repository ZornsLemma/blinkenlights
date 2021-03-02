#!/bin/sh
set -e
mkdir -p tmp
cd src
RES=../res
TMP=../tmp
PYTHON=python
$PYTHON decode-teletext.py $RES/menu-template.txt $TMP/menu-template.bin
$PYTHON decode-teletext.py --led $RES/menu-led-template.txt $TMP/menu-led-template.asm
$PYTHON encode-panel.py $RES/*.png
$PYTHON encode-led-shapes.py $TMP/led-shapes.asm
$PYTHON make-led-freq-spread.py $TMP/led-freq-spread.asm
$PYTHON make-random-tables.py $TMP/random-tables.asm
beebasm -w -v -i top.asm -do ../blinkenlights.ssd -opt 3 > ../top.lst
