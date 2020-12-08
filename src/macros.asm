; Assert that a particular label immediately follows; this documents where code
; falls through into following code and helps to detect problems if other code
; is accidentally interposed.
macro fall_through_to target
    assert P% == target
endmacro

; Load YX with the mode 7 screen address of character cell (x, y).
; TODO: Just move this into menu.asm? It's not generally useful.
macro ldyx_mode_7 x, y
    ldx #lo(mode_7_screen + y*mode_7_width + x)
    ldy #hi(mode_7_screen + y*mode_7_width + x)
endmacro

; Helper macro for equ_hex_char
macro equ_hex_digit n
    assert n <= &f
    if n <= &9
        equb '0' + n
    else
        equb 'A' + (n - 10)
    endif
endmacro

; Helper macro for equ_hex16
macro equ_hex_char word, digit
    equ_hex_digit (word >> (digit*4)) and &f
endmacro

; Generate a string representation of a value as 16-digit hex
macro equ_hex16 word
    equ_hex_char word, 3
    equ_hex_char word, 2
    equ_hex_char word, 1
    equ_hex_char word, 0
endmacro
