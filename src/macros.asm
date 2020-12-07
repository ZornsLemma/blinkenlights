; Assert that a particular label immediately follows; this documents where code
; falls through into following code and helps to detect problems if other code
; is accidentally interposed.
macro fall_through_to target
    assert P% == target
endmacro

; Load YX with the mode 7 screen address of character cell (x, y).
macro ldyx_mode7 x, y
    ldx #lo(mode_7_screen + y*mode_7_width + x)
    ldy #hi(mode_7_screen + y*mode_7_width + x)
endmacro
