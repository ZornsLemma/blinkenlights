#!/bin/sh
for x in panels/*.png; do
	python encode-panel.py "$x" "panels/$(basename $x .png).bin"
done
beebasm -w -v -i top.asm -do blinkenlights.ssd -opt 3 > top.lst
