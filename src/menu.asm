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

if FALSE
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
else
    ; TODO WAIT FOR VSYNC?
    jsr show_led_options
    jsr show_panel_colour
    jsr show_panel_template_SFTODO2
endif

    ; Repeatedly check for keys pressed and process them.
.input_loop
{
current_index = working_index ; TODO PROPER ZP ALLOC
    lda #-3 and &ff:sta current_index
.key_loop
    clc:lda current_index:adc #3:sta current_index
    tay:ldx input_table,y:beq input_loop
    lda #osbyte_read_key:ldy #&ff:jsr osbyte
    inx:bne key_loop
    ; The key at current_index is pressed; deal with it. We assume this
    ; corrupts all memory in zero page, so we stack current_index first.
    lda current_index:pha:tay
    lda input_table+1,y:sta ptr
    lda input_table+2,y:sta ptr+1
    jsr jmp_via_ptr
    ; Now wait until the key is released before continuing with the input loop.
    pla:sta current_index
.still_down
    ldy current_index:ldx input_table,y
    lda #osbyte_read_key:ldy #&ff:jsr osbyte
    inx:beq still_down
    bne key_loop

.jmp_via_ptr
    jmp (ptr)
}

.input_table
    equb keyboard_1:equw adjust_led_colour
    equb keyboard_2:equw adjust_led_shape
    equb keyboard_3:equw adjust_led_size
    equb keyboard_7:equw adjust_panel_colour
    equb keyboard_8:equw adjust_panel_template
    equb keyboard_space:equw start_animation
    equb 0

.adjust_led_colour
    ldy #option_led_colour-option_base:jsr adjust_option
    jmp show_led_options

.adjust_led_shape
    ldy #option_led_shape-option_base:jsr adjust_option
    jmp show_led_options

.adjust_led_size
    ldy #option_led_size-option_base:jsr adjust_option
    jmp show_led_options

.adjust_panel_colour
    ldy #option_panel_colour-option_base:jsr adjust_option
    jmp show_panel_colour ; TODO: fall through

.adjust_panel_template
    ldy #option_panel_template-option_base:jsr adjust_option
    jmp show_panel_template_SFTODO2 ; TODO RENAME THIS LABEL, TODO: JUST FALL THRU?

; Increment or decrement option Y (depending whether SHIFT is pressed or not),
; wrapping around at the ends of the range.
.adjust_option
{
    sty working_index
    lda #osbyte_read_key:ldx #lo(keyboard_shift):ldy #hi(keyboard_shift):jsr osbyte
    tya:bne shift_down
    lda #1
.shift_down
    ; A is now -1 or 1 depending on whether SHIFT is pressed or not.
    ldy working_index
    clc:adc option_base,y:bpl not_negative
    lda option_max,y
.not_negative
    cmp option_max,y:bcc not_too_large:beq not_too_large
    lda #0
.not_too_large
    sta option_base,y
    rts
}

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

.show_panel_template_SFTODO2
    lda option_panel_template:jsr get_panel_template_a_address
    jmp show_panel_template ; SFTODO JUST FALL THRU? THIS NEEDS MOVING INTO THIS FILE ANYWAY

; Set YX to point to panel template A.
.*get_panel_template_a_address ; TODO: MOVE INTO ANOTHER FILE?
    asl a:tay
    ldx panel_template_list,y
    lda panel_template_list+1,y:tay
    rts

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
    ; As a special case, the "diamond" LED shape gets an extra row of pixels at
    ; the right when it's shown in "reverse video" for black, otherwise it
    ; touches the right margin of the reverse video area and looks ugly.
    lda #0
    ldy toggle:beq not_special_case
    ldy option_led_shape:cpy #1:bne not_special_case
    lda #181
.not_special_case
    ldy #4:sta (dest),y
    clc:lda src:adc #4:sta src:inc_word_high src+1
    clc:lda dest:adc #mode_7_width:sta dest:inc_word_high dest+1
    dex:bpl line_loop
    rts

}

.option_base
.*option_led_colour
    equb colour_red
.*option_led_shape
    equb 0
.*option_led_size
    equb 0
.*option_panel_colour
    equb 0
.*option_panel_template
    equb 0

.option_max
    equb 7 ; LED colour
    equb 4 ; LED shape
    equb 1 ; LED size
    equb 7 ; panel colour
    equb 2 ; panel template

.menu_template
    incbin "../res/menu-template.bin"
}

.mode_7_led_bitmap_base
include "../res/menu-led-template.asm"
