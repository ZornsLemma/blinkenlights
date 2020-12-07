#!/bin/sh
python decode-teletext.py res/menu-template.txt res/menu-template.bin
for x in res/*.png; do
	python encode-panel.py "$x" "res/$(basename $x .png).bin"
done
cd src
beebasm -w -v -i top.asm -do ../blinkenlights.ssd -opt 3 > ../top.lst
