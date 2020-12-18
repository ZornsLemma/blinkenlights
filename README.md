# Blinkenlights

A novelty flashing display of virtual LEDs for the Acorn BBC B, B+ and Master computers. The general idea is that it should look something like a classic TV/film sci-fi "supercomputer".

## Links and credits

The stardot thread at TODO contains a pre-built version of this code, if you don't want to assemble it yourself. There's also a link you can use to run the code directly in your web browser using the jsbeeb emulator.

The basic idea - a panel of flashing LEDs which flash at approximately the same rate but which are not synchronised with each other - was inspired by Big Clive's "Gallium" PCB, as seen here: https://www.youtube.com/watch?v=H1k7mxhWQ5Q

Interrupts are used to track the current location of the CRT raster in order to prevent any visible artefacts (tearing) when updating the LEDs. The interrupt code is based on Kieran Connell's tutorial (video at http://abug.org.uk/index.php/2020/08/20/bbc-micro-interrupts-part-1/, code at https://github.com/kieranhj/intro-to-interrupts) with some additional inspiration from "dave j"'s code at https://stardot.org.uk/forums/viewtopic.php?f=54&t=20287&p=284490.

https://edit.tf was used to design the mode 7 user interface.

Bruce Clark's article on random number generation at http://6502.org/source/integers/random/random.html was very helpful, although in the end I decided to write my own RNG code. The multiplier for my RNG was taken from Guy Steele and Sebastiano Vigna's "Computationally easy, spectrally good multipliers for congruential pseudorandom number generators" (https://arxiv.org/abs/2001.05304).

## Building

You'll need a copy of [BeebAsm](https://github.com/stardot/beebasm/) and Python to build this yourself.

If you're on a Unix-like system and have beebasm on your PATH, running "./make.sh" should do everything necessary. If you're on another platform it shouldn't be too hard to translate make.sh into your platform's equivalent, or to execute the commands manually.

## Technical notes

At the start of the animation each LED is assigned a randomly generated frequency based on the parameters specified in the user interface. The LED flashes at that exact frequency forever; the patterns arise from the interactions of the LEDs all flashing at slightly different frequencies. The patterns are entirely in the eye of the beholder; the LEDs don't interact with one another in any way, except that they are all started off initially in sync.

The animation tries to run at 50 frames per second; VSYNC interrupts are counted and the animation code will wait for the next VSYNC once it's updated all the LEDs, or it will continue to run until it catches up if it had more work to do than it could accomplish in one frame's worth of time. The idea is that the LEDs should toggle at a consistent rate, even if the on-screen animation can't quite keep up.

(I say VSYNC; it's actually the start of the blank region at the bottom of the screen which is used, as identified by a combination of VSYNC+timer interrupts.)

The more LEDs are on screen the less likely it is that the code can maintain 50 fps, of course. Actually tracking the state of the LEDs and deciding when to toggle them on or off is relatively cheap; the expensive part is updating the screen RAM to produce the desired effect. This means that the frames most likely to overrun are ones where a lot of LEDs happen to toggle on the same frame.

The code to write an LED into screen memory or erase one from screen memory is created dynamically at runtime, taking into account the LED size and shape selected by the user. This means that smaller and simpler LEDs will draw faster and be erased faster, so this can also have an effect on how well the code is able to maintain 50 fps. On machines with a 65C02, the CMOS instructions will be used to gain a little extra performance.

In order to avoid tearing, the code will wait for the raster to pass if it's currently on the same vertical (character) row as the LED we are going to plot or erase. This will slow things down, of course, but I think it improves the effect and I think it's mostly unnoticeable when the code doesn't maintain 50 fps smoothly as a result. (With tight spreads on the LED frequencies, the display will sometimes develop a kind of slow jerkiness, but I think this is a "real" phenomenon caused by the LEDs drifting back ito something approximating synchronisation, not a problem with updating the display fast enough.)

The initial version of the code used the 50Hz screen refresh rate as the basis for the LED flashing - an LED would toggle every n frames. The effect was quite disappointing as many LEDs tended to remain syncrhonised due to the low time resolution. I changed it so there are multiple "LED ticks" per frame, which allows greater time resolution; we toggle an LED when it's internal count goes negative, at which point we add the half-period back on to its internal count, so we are effectively sampling its higher frequency oscillation at the screen refresh rate. The resolution is still not all that could be desired, because it's tracked using an 8-bit value per LED to save memory and speed up the processing, but I think the effect works fairly well.

The panel templates are in res/*.png. If you want to design your own panel, you can just add a new 40x32 1-bit indexed colour PNG image in the res directory, making sure it has a ".png" extension, and it should be picked up automatically. It might be easiest to start by copying one of the existing files to ensure it's the right format; the conversion code is quite picky and won't (for example) accept an RGB PNG file which happens to contain only pure black and pure white.
