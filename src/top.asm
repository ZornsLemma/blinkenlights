include "macros.asm"
include "constants.asm"

    org &70
    guard &90
.led_group_count
    equb 0
.frame_count
    equb 0
.inverse_raster_row
    equb 0
.ptr
    equw 0
.screen_ptr
    equw 0
.working_index
    equb 0
.led_x
    equb 0
.led_y
    equb 0

    ; random.asm workspace; some of this could potentially overlap with other
    ; zero page users if necessary, but for now we don't need to do this.
.SEED0
    equb 0
.SEED1
    equb 0
.SEED2
    equb 0
.SEED3
    equb 0
.TMP
    equd 0
.MOD
    equb 0
.REM
    equb 0

    org &2000
    guard &5800

    panel_width = 40
    panel_height = 32
    led_count = panel_width*panel_height
    show_missed_vsync = FALSE
    show_rows = FALSE
    assert not(show_missed_vsync and show_rows)
    slow_palette = TRUE
    big_leds = TRUE
    \ TODO: Triangular LEDs are a bit unsatisfactory in both big and small forms
    led_style = 3 \ 0=circular, 1=diamond, 2=rectangular, 3=square, 4=triangular
    if big_leds
        led_start_line = 1
        led_max_line = 5
    else
        led_start_line = 2
        led_max_line = 3
    endif

    panel_template_top_left_x = 19
    panel_template_top_left_y = 9

    irq1v = &204

    ula_palette = &fe21

    system_via_register_a = &fe41
    system_via_interrupt_flag_register = &fe4d
    system_via_interrupt_enable_register = &fe4e

    user_via_timer_1_low_order_latch = &fe64
    user_via_timer_1_high_order_counter = &fe65
    user_via_auxiliary_control_register = &fe6b
    user_via_interrupt_flag_register = &fe6d
    user_via_interrupt_enable_register = &fe6e

.start
    ; Refuse to run on a second processor. (Because we want to re-enter this
    ; code using CALL on BREAK via *KEY10, we can't just set our load/exec
    ; addresses to force execution in the host.)
    lda #osbyte_read_high_order_address:jsr osbyte
    inx:bne tube
    iny:beq not_tube
.tube
    brk
    equs 0, "Please turn off your second processor!", 0
.not_tube

    ; Set up the BREAK key to re-enter this code. (We don't do this in !BOOT
    ; because that would cause a crash if the user pressed BREAK before this
    ; code has loaded.) We could use *FX247 but that would also trap CTRL-BREAK;
    ; we're not trying to make ourselves unkillable, just taking advantage of
    ; BREAK's hardware reset ability to interrupt the running animation without
    ; us needing to spend CPU cycles checking the keyboard.
    ldx #lo(key10_command)
    ldy #hi(key10_command)
    jsr oscli

include "menu.asm"
if FALSE
\ START TEMP HACK
{
    lda #22:jsr &ffee:lda #7:jsr &ffee
    ldy #24
.loop
    lda #145:jsr &ffee:lda #154:jsr &ffee:jsr &ffe7
    dey:bne loop
    ldx #lo(panel_template):ldy #hi(panel_template):jsr show_panel_template
.HANG JMP HANG
}
\ END TEMP HACk
endif

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
\ TODO: Standardise on & vs $ for hex - probably &

include "animate.asm"
include "utilities.asm"
include "random.asm"
     

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    ; TODO: ALL OF THESE TABLES CAN BE MOVED AFTER ".end" AND THEREFORE WON'T TAKE UP SPACE ON DISC OR TAKE TIME TO LOAD FROM DISC - BUT AM WAITING UNTIL I PROGRAMATICALLY POPULATE period_table BEFORE MAKING THIS CHANGE
    align &100
.count_table
    skip led_count ; TODO: rename this max_led_count?

    align &100
.period_table
    skip led_count

    align &100
.state_table
    skip led_count

    align &100
.inverse_row_table
    skip led_count

    align &100
.address_low_table
    skip led_count

    align &100
.address_high_table
    skip led_count

; TODO DELETE .panel_template ; TODO: THIS LABEL IS PROB TEMP NOW, UNTIL I REWORK THE ANIM CODE
.panel_template_circle_32
    incbin "../res/circle-32.bin"
.panel_template_rectangle_32
    incbin "../res/rectangle-32.bin"
.panel_template_triangle_32
    incbin "../res/triangle-32.bin"

.panel_template_list
    equw panel_template_circle_32
    equw panel_template_rectangle_32
    equw panel_template_triangle_32

include "../res/led-shapes.asm"
.led_shape_list ; TODO: Generate this list in led-shapes.asm?
    equw led_shape_0_large, led_shape_0_small
    equw led_shape_1_large, led_shape_1_small
    equw led_shape_2_large, led_shape_2_small
    equw led_shape_3_large, led_shape_3_small
    equw led_shape_4_large, led_shape_4_small

.key10_command
    equs "KEY10 CALL &"
    equ_hex16 start
    equs "|M", 13

.end

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

; TODO: I am currently *maybe* seeing a slight weirdness with some of the LEDs when they first start animating - it's probably fine, but have a look and see if not all are initialised or the fact that some panels don't use *all* the LED slots has some kind of impact - I *think* this was caused by not initialising state_table and count_table every time, so after the first animation the LEDs didn't all start in sync - if so I have now fixed this, will leave this TODO in place for a bit in case there was another cause
