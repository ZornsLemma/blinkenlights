#!/bin/sh
beebasm -v -i run.asm -do blinkenlights.ssd -opt 3 > run.lst
beebasm -v -i run7.asm -do blinkenlights7.ssd -opt 3 > run7.lst
