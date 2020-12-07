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
.SFTODOHACK8
    jsr show_panel_colour
    lda option_panel_colour:clc:adc #1:and #7:sta option_panel_colour
    lda #50:sta &70
.SFTODOHACK8B
    lda #19:jsr osbyte
    dec &70
    bne SFTODOHACK8B
    beq SFTODOHACK8

.input_loop
    lda #osbyte_flush_buffer:ldx #buffer_keyboard:jsr osbyte
    jsr osrdch
    jmp input_loop

.show_panel_colour
    lda option_panel_colour:ldyx_mode7 25, 6
    fall_through_to show_colour

; Display a colour swatch for colour A at screen memory address YX.
; TODO: De-subroutine this if it's only used in one place?
; TODO: Use oswrch here instead of direct screen access?
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
    lda #mode_7_graphics_colour_base+7:ldy #0:sta (ptr),y
    lda #183:iny:sta (ptr),y
    lda #163:iny:sta (ptr),y
    lda #181:iny:sta (ptr),y
    lda #mode_7_graphics_colour_base+7:ldy #40:sta (ptr),y
    lda #173:iny:sta (ptr),y
    lda #172:iny:sta (ptr),y
    lda #165:iny:sta (ptr),y
    rts
}

.option_panel_colour
    equb 0

.menu_template
    incbin "../res/menu-template.bin"
}
