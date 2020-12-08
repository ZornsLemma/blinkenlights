{
    ; TODO: PROPER ALLOCATION OF ZERO PAGE
    src = ptr
    dest = screen_ptr
    toggle = working_index
  
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
    jsr show_led_options
    jsr show_panel_colour
    lda option_led_colour:clc:adc #1:and #7:sta option_led_colour
    lda option_panel_colour:clc:adc #1:and #7:sta option_panel_colour
    lda option_led_colour:bne SFTODO91
    lda option_led_size:eor #1:sta option_led_size
    bne SFTODO91
    lda option_led_shape:clc:adc #1:cmp #5:bne SFTODO99
    lda #0
.SFTODO99
    sta option_led_shape
.SFTODO91
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
    lda option_panel_colour:ldyx_mode_7 25, 6 \ TODO: MOVE MAGIC CONSTANTS TO NAMED CONSTANTS AT TOP?
    fall_through_to show_colour

; Display a colour swatch for colour A at screen memory address YX.
; TODO: De-subroutine this if it's only used in one place?
; TODO: Use oswrch here instead of direct screen access?
.show_colour
{
    ; TODO: Wait for vsync?
    stx dest:sty dest+1
    tax:beq black
    clc:adc #mode_7_graphics_colour_base:pha
    ldy #0:sta (dest),y
    lda #255
    iny:sta (dest),y
    iny:sta (dest),y
    lda #181
    iny:sta (dest),y
    ldy #40:pla:sta (dest),y
    lda #175
    iny:sta (dest),y
    iny:sta (dest),y
    lda #165
    iny:sta (dest),y
    rts

.black
    lda #mode_7_graphics_colour_base+7:ldy #0:sta (dest),y
    lda #183:iny:sta (dest),y
    lda #163:iny:sta (dest),y
    lda #181:iny:sta (dest),y
    lda #mode_7_graphics_colour_base+7:ldy #40:sta (dest),y
    lda #173:iny:sta (dest),y
    lda #172:iny:sta (dest),y
    lda #165:iny:sta (dest),y
    rts
}

; Update the LED image in the menu to reflect the colour, shape and size
; options.
.show_led_options
{
    ; TODO: WAIT FOR VSYNC? OR MAYBE OUR CALLER SHOULD DO IT SO INITIAL UPDATE DOESN'T REQUIRE MULTIPLE FRAMES?
    ldyx_mode_7 10,6 \ TODO: MAGIC CONSTANTS - POSS OK IF NOT DUPLICATED ELSEWHERE
    stx dest:sty dest+1
    ldx #0:lda option_led_colour:bne not_black
    ldx #%01011111:lda #colour_white
.not_black
    stx toggle
    clc:adc #mode_7_graphics_colour_base
    ldy #0:sta (dest),y
    ldy #40:sta (dest),y
    ldy #80:sta (dest),y
    inc_word dest
    lda option_led_shape:asl a:clc:adc option_led_size:asl a:asl a:asl a:asl a
    clc:adc #lo(mode_7_led_bitmap_base):sta src
    lda #hi(mode_7_led_bitmap_base):adc #0:sta src+1
    ldx #2
.line_loop
    ldy #3
.character_loop
    lda (src),y:eor toggle:sta (dest),y
    dey:bpl character_loop
    clc:lda src:adc #4:sta src:inc_word_high src+1
    clc:lda dest:adc #mode_7_width:sta dest:inc_word_high dest+1
    dex:bpl line_loop
    rts

}

.option_led_colour
    equb colour_red
.option_led_shape
    equb 0
.option_led_size
    equb 0
.option_panel_colour
    equb 0

.menu_template
    incbin "../res/menu-template.bin"
}

.mode_7_led_bitmap_base
include "../res/menu-led-template.asm"
