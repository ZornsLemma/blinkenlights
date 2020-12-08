#!/bin/sh
# TODO: Ideally this would work with both Python 2 and 3...
python decode-teletext.py res/menu-template.txt res/menu-template.bin
python decode-teletext.py --led res/menu-led-template.txt res/menu-led-template.asm
for x in res/*.png; do
	python encode-panel.py "$x" "res/$(basename $x .png).bin"
done
python encode-led-shapes.py res/led-shapes.asm
cd src
beebasm -w -v -i top.asm -do ../blinkenlights.ssd -opt 3 > ../top.lst
