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
    jsr update_random_seed

    ; TODO WAIT FOR VSYNC?
    jsr show_led_visual_options
    jsr show_led_frequency
    jsr show_led_spread
    jsr show_led_distribution
    jsr show_panel_colour
    jsr show_panel_template_SFTODO2

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
    ; The key at current_index is pressed; deal with it. We assume the handler
    ; subroutine corrupts all memory in zero page, so we stack current_index
    ; first.
    jsr update_random_seed
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
    equb keyboard_4:equw adjust_led_frequency
    equb keyboard_5:equw adjust_led_spread
    equb keyboard_6:equw adjust_led_distribution
    equb keyboard_7:equw adjust_panel_colour
    equb keyboard_8:equw adjust_panel_template
    ; TODO: Don't forget to do the randomise option!
    equb keyboard_space:equw start_animation
    equb 0

.adjust_led_colour
    ldy #option_led_colour-option_base:jsr adjust_option
    jmp show_led_visual_options

.adjust_led_shape
    ldy #option_led_shape-option_base:jsr adjust_option
    jmp show_led_visual_options

.adjust_led_size
    ldy #option_led_size-option_base:jsr adjust_option
    jmp show_led_visual_options

.adjust_led_frequency
    ldy #option_led_frequency-option_base:jsr adjust_option
    jmp show_led_frequency

.adjust_led_spread
    ldy #option_led_spread-option_base:jsr adjust_option
    jmp show_led_spread

.adjust_led_distribution
    ldy #option_led_distribution-option_base:jsr adjust_option
    jmp show_led_distribution

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
.show_led_visual_options
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
    ; TODO: I should maybe undo this (and on teletext template too), because
    ; the actual mode 4 diamond LEDs are smaller/less diamondy than the
    ; teletext ones now - unless I can improve (and I don't think I can) the
    ; mode 4 ones, it's probably better (and avoids this special case too)
    ; for the teletext to look like the mode 4 ones.
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

.show_led_frequency
{
    ; TODO WAIT FOR VSYNC?
    ; All the entries at frequency_text are exactly three characters long.
    lda option_led_frequency:asl a:adc option_led_frequency:tax
    ldy #0
.loop
    lda frequency_text,x
    sta mode_7_screen + (11 * mode_7_width) + 4,y
    inx
    iny:cpy #3:bne loop
    rts
}

.show_led_spread
{
    ; TODO VSYNC?
    ; All the entries at spread_text are exactly two characters long.
    lda option_led_spread:asl a:tax
    ldy #0
.loop
    lda spread_text,x
    sta mode_7_screen + (12 * mode_7_width) + 8,y
    inx
    iny:cpy #2:bne loop
    rts
}

.show_led_distribution
{
    ; TODO VSYNC
    ldx option_led_distribution:beq uniformly
    ldx #text_binomially-text_uniformly
.uniformly
    ldy #0
.loop
    lda text_uniformly,x
    sta mode_7_screen + (13 * mode_7_width) + 4,y
    inx
    iny:cpy #text_binomially-text_uniformly:bne loop
    rts

.text_uniformly
    equs "uniformly "
.text_binomially
    equs "binomially"
}

.option_base
.*option_led_colour
    equb colour_red
.*option_led_shape
    equb 0
.*option_led_size
    equb 0
.*option_led_frequency
    equb 1
.*option_led_spread
    equb 2
.*option_led_distribution
    equb 0
.*option_panel_colour
    equb 0
.*option_panel_template
    equb 0

.option_max
    equb 7 ; LED colour
    equb 4 ; LED shape
    equb 1 ; LED size
    equb num_frequencies - 1 ; LED frequency
    equb num_spreads - 1 ; LED spread
    equb 1 ; LED distribution
    equb 7 ; panel colour
    equb 2 ; panel template

.menu_template
    incbin "../res/menu-template.bin"

\ TODO: COMMENT AND RENAME VARS/LABELS IN THIS ROUTINE
\ Display the panel template at YX using mode 7 graphics at panel_template_top_left_[xy].
.show_panel_template
{
\ TODO: WE SHOULD HAVE A GENERAL "TMP ZP" AREA AND USE THAT, RATHER THAN PRE-ALLOCATING *BASED* ON THE FLASHING CODE
pixel_bitmap = working_index \ TODO HACK
template_rows_left = inverse_raster_row \ TODO HACK
sixel_inverse_row = frame_count \ TODO HACK
x_group_count = led_group_count \ TODO HACK

\ TODO: Not too happy with some of these names
sixel_width = 2
sixel_height = 3
width_chars = panel_width/sixel_width
x_group_chars = 4
x_groups = width_chars / x_group_chars

    \ SFTODO: WAIT FOR VSYNC?
    \ SFTODO: DO I NEED TO DO ANYHTHING TO BLANK OUT ANYTHING ALREADY THERE?
    \ Skip the count of LEDs at the start of the panel template.
    txa:clc:adc #2:sta ptr
    tya:adc #0:sta ptr+1
    screen_address_top_left = mode_7_screen + panel_template_top_left_y*mode_7_width + panel_template_top_left_x
    lda #lo(screen_address_top_left):sta screen_ptr
    lda #hi(screen_address_top_left):sta screen_ptr+1
    lda #panel_height:sta template_rows_left
.template_row_loop
    lda #sixel_height-1:sta sixel_inverse_row
.sixel_row_loop
    lda #x_groups-1:sta x_group_count
    lda sixel_inverse_row:asl a:asl a
    clc:adc #lo(pixel_to_sixel_row_table):sta lda_pixel_to_sixel_row_table_y+1
    lda #hi(pixel_to_sixel_row_table):adc #0:sta lda_pixel_to_sixel_row_table_y+2
.x_group_loop
    ldy #0:lda (ptr),y:sta pixel_bitmap
    ldx #x_group_chars-1
.sixel_for_x_group_loop
    lda #0
    asl pixel_bitmap:rol a
    asl pixel_bitmap:rol a
    tay
.lda_pixel_to_sixel_row_table_y
    lda $ffff,y \ patched
    ldy sixel_inverse_row:cpy #sixel_height-1:bne not_first_sixel_row
    ldy #0:sta (screen_ptr),y:jmp done_first_sixel_row
.not_first_sixel_row
    ldy #0:ora (screen_ptr),y:sta (screen_ptr),y
.done_first_sixel_row
    inc_word screen_ptr
    dex:bpl sixel_for_x_group_loop
    inc_word ptr
    dec x_group_count:bpl x_group_loop
    dec template_rows_left:beq done
    sec:lda screen_ptr:sbc #width_chars:sta screen_ptr
    bcs no_borrow:dec screen_ptr+1:.no_borrow
    dec sixel_inverse_row:bpl sixel_row_loop
    clc:lda screen_ptr:adc #mode_7_width:sta screen_ptr
    inc_word_high screen_ptr+1
    jmp template_row_loop
.done
    rts

.pixel_to_sixel_row_table
    \ Bottom row of sixel
    \ Sixel value    pixels
    equb %10100000 \ %00
    equb %11100000 \ %01
    equb %10110000 \ %10
    equb %11110000 \ %11
    \ Middle row of sixel
    \ Sixel value    pixels
    equb %10100000 \ %00
    equb %10101000 \ %01
    equb %10100100 \ %10
    equb %10101100 \ %11
    \ Top row of sixel
    \ Sixel value    pixels
    equb %10100000 \ %00
    equb %10100010 \ %01
    equb %10100001 \ %10
    equb %10100011 \ %11
}
}

.mode_7_led_bitmap_base
include "../res/menu-led-template.asm"

include "../res/led-freq-spread.asm"
