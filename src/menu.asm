{
    led_top_left_x = 10
    led_top_left_y = 6
    led_frequency_x = 4
    led_frequency_y = 11
    led_spread_x = 8
    led_spread_y = 12
    led_distribution_x = 4
    led_distribution_y = 13
    panel_colour_top_left_x = 25
    panel_colour_top_left_y = 6
    panel_template_top_left_x = 19
    panel_template_top_left_y = 9

; Load YX with the mode 7 screen address of character cell (x, y).
macro ldyx_mode_7 x, y
    ldx #lo(mode_7_screen + y*mode_7_width + x)
    ldy #hi(mode_7_screen + y*mode_7_width + x)
endmacro

    menu_start = *

    org shared_zp_start
    guard shared_zp_end
    clear shared_zp_start, shared_zp_end
.working_index
    skip 1

    org menu_start
    guard mode_4_screen

.*show_menu
{
    jsr wait_for_vsync
    ldx #0
.loop
    lda menu_template     ,x:sta mode_7_screen     ,x
    lda menu_template+&100,x:sta mode_7_screen+&100,x
    lda menu_template+&200,x:sta mode_7_screen+&200,x
    lda menu_template+&300,x:sta mode_7_screen+&300,x
    inx
    bne loop
    jsr show_led_visual_options_no_vsync
    jsr show_led_frequency_no_vsync
    jsr show_led_spread_no_vsync
    jsr show_led_distribution_no_vsync
    jsr show_panel_colour_no_vsync
    jsr show_panel_template

    ; There might be some entropy in the current system time, especially if the
    ; user hasn't done CTRL-BREAK/power on recently.
    jsr update_random_seed

    ; Repeatedly check for keys pressed and process them.
.input_loop
    lda #-3 and &ff:sta working_index
.key_loop
    clc:lda working_index:adc #3:sta working_index
    tay:ldx input_table,y:beq input_loop
    lda #osbyte_read_key:ldy #&ff:jsr osbyte
    inx:bne key_loop
    ; The key at working_index is pressed; deal with it. We assume the handler
    ; subroutine corrupts all memory in zero page, so we stack working_index
    ; first.
    jsr update_random_seed
    lda working_index:pha:tay
    lda input_table+1,y:sta src
    lda input_table+2,y:sta src+1
    jsr jmp_via_src
    ; Now wait until the key is released before continuing with the input loop.
    pla:sta working_index
.still_down
    ldy working_index:ldx input_table,y
    lda #osbyte_read_key:ldy #&ff:jsr osbyte
    inx:beq still_down
    bne key_loop

.jmp_via_src
    jmp (src)
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
    equb keyboard_0:equw randomise_options
    equb keyboard_space:equw pre_start_animation
    equb 0

; The user wants to start the animation; check that the LED and panel colours
; aren't the same first and show a message instead if they are.
.pre_start_animation
{
    mode_7_screen_copy = mode_7_screen - &400
    graphics = mode_7_graphics_colour_base+1
    text = mode_7_text_colour_base+7
    start_y = 10
    offset = start_y*mode_7_width
    lda option_led_colour:cmp option_panel_colour:beq same_colours
    jmp start_animation
.same_colours
    ; In order to avoid ugly screen flickering, we save the part of the screen
    ; we're about to overwrite with the warning and restore it afterwards. (If
    ; we just did jmp show_menu afterwards, that would take a couple of frames
    ; and the variable parts would be blanked out during those frames.)
    ldx #0
.save_loop
    lda mode_7_screen+offset,x:sta mode_7_screen_copy,x
    dex:bne save_loop
    jsr wait_for_vsync
    jsr print_string_inline
    equb vdu_move_text_cursor, 1, start_y
    equb graphics, 188
    for i, 1, 35
        equb 172
    next
    equb 236
    equb vdu_move_text_cursor, 1, start_y+1
    equb graphics, 181, text, "Sorry, please select different   ", graphics, 234
    equb vdu_move_text_cursor, 1, start_y+2
    equb graphics, 181, text, "LED and panel colours before     ", graphics, 234
    equb vdu_move_text_cursor, 1, start_y+3
    equb graphics, 181, text, "starting. Press SPACE...         ", graphics, 234
    equb vdu_move_text_cursor, 1, start_y+4
    equb graphics, 173
    for i, 1, 35
        equb 172
    next
    equb 174
    equb eot
    ; Now wait for the user to release SPACE (the press which tried to start the
    ; animation) and press it again to dismiss the message. (input_loop will
    ; wait until the press of SPACE to dismiss the message is released.)
.wait_for_no_space
    lda #osbyte_read_key:ldx #lo(keyboard_space):ldy #hi(keyboard_space):jsr osbyte
    inx:beq wait_for_no_space
.wait_for_space
    lda #osbyte_read_key:ldx #lo(keyboard_space):ldy #hi(keyboard_space):jsr osbyte
    inx:bne wait_for_space
    jsr wait_for_vsync
    ldx #0
.restore_loop
    lda mode_7_screen_copy,x:sta mode_7_screen+offset,x
    dex:bne restore_loop
    rts
}

.randomise_options
{
    ; We don't randomise the colours because that's likely to be ugly, and the
    ; user probably has a stronger preference about colours than about the other
    ; options.
    ldy #option_led_shape-option_base:jsr randomise_option
    ldy #option_led_size-option_base:jsr randomise_option
    ldy #option_led_frequency-option_base:jsr randomise_option
    ldy #option_led_spread-option_base:jsr randomise_option
    ldy #option_led_distribution-option_base:jsr randomise_option
    ldy #option_panel_template-option_base:jsr randomise_option
    jsr wait_for_vsync
    jsr show_led_visual_options_no_vsync
    jsr show_led_frequency_no_vsync
    jsr show_led_spread_no_vsync
    jsr show_led_distribution_no_vsync
    jmp show_panel_template

.randomise_option
    sty working_index
    lda option_max,y:clc:adc #1:jsr urandom8
    ldy working_index:sta option_base,y
    rts
}

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

.adjust_panel_colour
    ldy #option_panel_colour-option_base:jsr adjust_option
    fall_through_to show_panel_colour

.show_panel_colour
    jsr wait_for_vsync
.show_panel_colour_no_vsync
{
    lda option_panel_colour
    ldyx_mode_7 panel_colour_top_left_x, panel_colour_top_left_y
    stx dest:sty dest+1
    tax:beq black
    clc:adc #mode_7_graphics_colour_base:pha
    ldy #0:sta (dest),y
    lda #255
    iny:sta (dest),y
    iny:sta (dest),y
    lda #181
    iny:sta (dest),y
    ldy #mode_7_width:pla:sta (dest),y
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
    lda #mode_7_graphics_colour_base+7:ldy #mode_7_width:sta (dest),y
    lda #173:iny:sta (dest),y
    lda #172:iny:sta (dest),y
    lda #165:iny:sta (dest),y
    rts
}

; Update the LED image in the menu to reflect the colour, shape and size
; options.
.show_led_visual_options
    jsr wait_for_vsync
.show_led_visual_options_no_vsync
{
    toggle = zp_tmp
   
    ldyx_mode_7 led_top_left_x, led_top_left_y
    stx dest:sty dest+1
    ldx #0:lda option_led_colour:bne not_black
    ldx #%01011111:lda #colour_white
.not_black
    stx toggle
    clc:adc #mode_7_graphics_colour_base
    ldy #0:sta (dest),y
    ldy #mode_7_width:sta (dest),y
    ldy #mode_7_width*2:sta (dest),y
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

.show_led_frequency
    jsr wait_for_vsync
.show_led_frequency_no_vsync
{
    ; All the entries at frequency_text are exactly three characters long.
    lda option_led_frequency:asl a:adc option_led_frequency:tax
    ldy #0
.loop
    lda frequency_text,x
    ; TODO: NOT JUST HERE, SOMETIMES I USE THIS VERY SPACEY ARITHMETIC STYLE, SOMETIMES I USE A MORE COMPACT ONE - STANDARDISE (PROB ON MORE COMPACT)
    sta mode_7_screen + (led_frequency_y * mode_7_width) + led_frequency_x,y
    inx
    iny:cpy #3:bne loop
    rts
}

.show_led_spread
    jsr wait_for_vsync
.show_led_spread_no_vsync
{
    ; All the entries at spread_text are exactly two characters long.
    lda option_led_spread:asl a:tax
    ldy #0
.loop
    lda spread_text,x
    sta mode_7_screen + (led_spread_y * mode_7_width) + led_spread_x,y
    inx
    iny:cpy #2:bne loop
    rts
}

.show_led_distribution
    jsr wait_for_vsync
.show_led_distribution_no_vsync
{
    ldx option_led_distribution:beq uniformly
    ldx #text_binomially-text_uniformly
.uniformly
    ldy #0
.loop
    lda text_uniformly,x
    sta mode_7_screen + (led_distribution_y * mode_7_width) + led_distribution_x,y
    inx
    iny:cpy #text_binomially-text_uniformly:bne loop
    rts

.text_uniformly
    equs "uniformly "
.text_binomially
    equs "binomially"
}

.adjust_panel_template
    ldy #option_panel_template-option_base:jsr adjust_option
    fall_through_to show_panel_template

.show_panel_template
{
    pixel_bitmap = zp_tmp
    template_rows_left = zp_tmp + 1
    sixel_inverse_row = zp_tmp + 2
    x_group_count = zp_tmp + 3

    mode_7_screen_copy = mode_7_screen - &400
    offset = panel_template_top_left_y*mode_7_width
    screen_address_top_left = mode_7_screen_copy + panel_template_top_left_x

    sixel_width = 2
    sixel_height = 3
    width_chars = panel_width/sixel_width
    x_group_chars = 4
    x_groups = width_chars / x_group_chars

    ; This is a moderately slow process; in an attempt to avoid tearing when we update
    ; the screen, we generate the mode 7 graphics on a copy of the mode 7 screen and
    ; copy that back to the actual screen RAM afterwards.
    {
        ldx #0
    .loop
        lda mode_7_screen+offset,x:sta mode_7_screen_copy,x
        lda mode_7_screen+&100+offset,x:sta mode_7_screen_copy+&100,x
        dex:bne loop
    }

    \ Skip the count of LEDs at the start of the panel template.
    jsr get_panel_template_address
    txa:clc:adc #2:sta src
    tya:adc #0:sta src+1
    lda #lo(screen_address_top_left):sta dest
    lda #hi(screen_address_top_left):sta dest+1
    lda #panel_height:sta template_rows_left
.template_row_loop
    lda #sixel_height-1:sta sixel_inverse_row
.sixel_row_loop
    lda #x_groups-1:sta x_group_count
    lda sixel_inverse_row:asl a:asl a
    clc:adc #lo(pixel_to_sixel_row_table):sta lda_pixel_to_sixel_row_table_y+1
    lda #hi(pixel_to_sixel_row_table):adc #0:sta lda_pixel_to_sixel_row_table_y+2
.x_group_loop
    ldy #0:lda (src),y:sta pixel_bitmap
    ldx #x_group_chars-1
.sixel_for_x_group_loop
    lda #0
    asl pixel_bitmap:rol a
    asl pixel_bitmap:rol a
    tay
.lda_pixel_to_sixel_row_table_y
    lda &ffff,y \ patched
    ldy sixel_inverse_row:cpy #sixel_height-1:bne not_first_sixel_row
    ldy #0:sta (dest),y:jmp done_first_sixel_row
.not_first_sixel_row
    ldy #0:ora (dest),y:sta (dest),y
.done_first_sixel_row
    inc_word dest
    dex:bpl sixel_for_x_group_loop
    inc_word src
    dec x_group_count:bpl x_group_loop
    dec template_rows_left:beq done
    sec:lda dest:sbc #width_chars:sta dest
    bcs no_borrow:dec dest+1:.no_borrow
    dec sixel_inverse_row:bpl sixel_row_loop
    clc:lda dest:adc #mode_7_width:sta dest
    inc_word_high dest+1
    jmp template_row_loop
.done

    ; Copy the generated data back to screen RAM.
    jsr wait_for_vsync
    {
        ldx #0
    .loop
        lda mode_7_screen_copy,x:sta mode_7_screen+offset,x
        lda mode_7_screen_copy+&100,x:sta mode_7_screen+&100+offset,x
        dex:bne loop
    }
    rts

; Set YX to point to current panel template.
.*get_panel_template_address
    lda option_panel_template:asl a:tay
    ldx panel_template_list,y
    lda panel_template_list+1,y:tay
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

.wait_for_vsync
    lda #osbyte_wait_for_vsync:jmp osbyte

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

; Maximum (inclusive) values for the options at option_base, in the same order.
.option_max
    equb 7 ; LED colour
    equb num_led_shapes-1 ; LED shape
    equb 1 ; LED size
    equb num_frequencies-1 ; LED frequency
    equb num_spreads-1 ; LED spread
    equb 1 ; LED distribution
    equb 7 ; panel colour
    equb num_panel_templates-1 ; panel template

.menu_template
    incbin "../tmp/menu-template.bin"
}

.mode_7_led_bitmap_base
include "../tmp/menu-led-template.asm"

include "../tmp/led-freq-spread.asm"
