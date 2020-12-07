{
    ; TODO: I probably need to remove the "variable" elements from the template, to avoid
    ; them briefly flickering into view before we update them after copying the template.
    lda #7:jsr set_mode
    ; TODO: Wait for vsync?
    {
        ldx #0
    .loop
        lda menu_template     ,x:sta mode_7_screen     ,x
        lda menu_template+&100,x:sta mode_7_screen+&100,x
        lda menu_template+&200,x:sta mode_7_screen+&200,x
        lda menu_template+&300,x:sta mode_7_screen+&300,x
        inx
        bne loop
    }

    ; TODO: SEMI-EXPERIMENTAL
    jsr show_led_colour

.input_loop
    lda #osbyte_flush_buffer:ldx #buffer_keyboard:jsr osbyte
    jsr osrdch
    jmp input_loop

.show_led_colour
    lda option_led_colour:ldyx_mode7 11, 6
    fall_through_to show_colour

; Display a colour swatch for colour A at screen memory address YX.
.show_colour
{
    ; TODO: Wait for vsync?
    stx ptr:sty ptr+1
    tax:beq black
    clc:adc #mode_7_graphics_colour_base:pha
    ldy #0:sta (ptr),y
    lda #255
    iny:sta (ptr),y
    iny:sta (ptr),y
    lda #181
    iny:sta (ptr),y
    ldy #40:pla:sta (ptr),y
    lda #175
    iny:sta (ptr),y
    iny:sta (ptr),y
    lda #165
    iny:sta (ptr),y
    rts

.black
.TODOHACK2 JMP TODOHACK2
}

.option_led_colour
    equb 1

.menu_template
    incbin "../res/menu-template.bin"
}
