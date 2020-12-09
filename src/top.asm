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
    ticks_per_frame = 8
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

macro set_background_a
    sta ula_palette
    if slow_palette
        eor #%00010000:sta ula_palette
        eor #%00110000:sta ula_palette
        eor #%00010000:sta ula_palette
        eor #%01010000:sta ula_palette
        eor #%00010000:sta ula_palette
        eor #%00110000:sta ula_palette
        eor #%00010000:sta ula_palette
    endif
endmacro

macro advance_to_next_led_fall_through
    inx
    bne led_loop
endmacro

; Note that this macro's body is also generated at runtime by compile_led_shape,
; so the two must be kept in sync.
macro advance_to_next_led
    advance_to_next_led_fall_through
    beq advance_to_next_led_group \ always branch
endmacro

macro inc_word x
    inc x
    bne no_carry
    inc x+1
.no_carry
endmacro

macro inc_word_high x
    bcc no_carry
    inc x
.no_carry
endmacro

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

\ TODO NEED TO MOVE ALL THIS CODE OUT OF TOP.ASM INTO ANIMATION.ASM OR SIMILAR
.start_animation
{
    \ Select mode 4 and set the foreground and background colours.
    lda #4:jsr set_mode
    ldx #0:ldy option_panel_colour:jsr set_palette_x_to_y
    ldx #1:ldy option_led_colour:jsr set_palette_x_to_y

    ; Set all the LEDs to be off and just about to turn on, so they start in sync.
    assert led_count == 5*256
    ldx #0
.init_state_loop
    lda #0
    sta state_table     ,x
    sta state_table+&100,x
    sta state_table+&200,x
    sta state_table+&300,x
    sta state_table+&400,x
    lda #1
    sta count_table     ,x
    sta count_table+&100,x
    sta count_table+&200,x
    sta count_table+&300,x
    sta count_table+&400,x
    dex:bne init_state_loop

    ; Compile code to poke the selected LED bitmap into screen RAM.
    lda option_led_shape:asl a:clc:adc option_led_size:asl a
    tay:ldx led_shape_list,y
    lda led_shape_list+1,y:tay
    jsr compile_led_shape

    \ Set up the LEDs based on the panel template.
    \ TODO: RENAME PTR TO TEMPLATE_PTR OR SOMETHING?
    lda option_panel_template:jsr get_panel_template_a_address
    stx ptr:sty ptr+1

    \ The first two bytes of the template are the number of LEDs; we need to set up
    \ the per-frame initialisation accordingly, and if we don't have an exact
    \ multiple of 256 LEDs we need to take that into account by starting with X>0.
    ldy #1:lda (ptr),y:sta lda_imm_led_groups+1
    dey:lda (ptr),y:beq exact_multiple
    inc lda_imm_led_groups+1
    lda #0:sec:sbc (ptr),y
.exact_multiple
    sta lda_imm_initial_x+1:sta working_index
    clc:lda ptr:adc #2:sta ptr
    inc_word_high ptr+1

    \ TODO PROB WANT TO PUT A INTO X OR SOMETHING FOR FOLLOWING CODE TO WORK WITH

    lda #hi(inverse_row_table):sta SFTODOPATCHME1+2
    lda #hi(address_low_table):sta SFTODOPATCHME2+2
    lda #hi(address_high_table):sta SFTODOPATCHME3+2

    lda #0:sta led_x:sta led_y
    ; If we have large LEDs, "Y=0" is actually scanline 1 within the character
    ; cell; for small LEDs, "Y=0" is scanline 2.
    lda option_led_size:clc:adc #1
    sta screen_ptr
    lda #&58:sta screen_ptr+1
    \ TODO WE NEED TO SET UP inverse_row_table, address_{low,high}_table - OTHER TABLES CAN SAFELY BE OVER-FILLED
.SFTODOLOOP
    ldy #0:lda (ptr),y
    ldx #8
.SFTODOLOOP2
    asl a
    pha \ TODO PROB EASIER JUST TO USE A ZP LOC INSTEAD OF A FOR THE SHIFTING
    bcc empty
    ldy working_index
    lda #32:sec:sbc led_y
.SFTODOPATCHME1
    sta &ff00,y \ patched
    lda screen_ptr
.SFTODOPATCHME2
    sta &ff00,y \ patched
    lda screen_ptr+1
.SFTODOPATCHME3
    sta &ff00,y \ patched
    inc working_index
    bne not_next_led_group
    inc SFTODOPATCHME1+2
    inc SFTODOPATCHME2+2
    inc SFTODOPATCHME3+2
.not_next_led_group
.empty
    lda screen_ptr:clc:adc #8:sta screen_ptr
    inc_word_high screen_ptr+1
    inc led_x
    pla
    dex:bne SFTODOLOOP2
    inc_word ptr
    lda led_x:cmp #40:bne SFTODOLOOP
    lda #0:sta led_x
    inc led_y
    lda led_y:cmp #32:bne SFTODOLOOP



}

    \ Interrupt code based on https://github.com/kieranhj/intro-to-interrupts/blob/master/source/screen-example.asm
    scanline_to_interrupt_at = -2
    vsync_position = 35
    total_rows = 39
    us_per_scanline = 64
    us_per_row = 8*us_per_scanline
    vsync_to_visible_start_us = (total_rows-vsync_position)*us_per_row - 2*us_per_scanline + scanline_to_interrupt_at*us_per_scanline
    row_us = us_per_row - 2
   
    sei
    \ We're going to shut the OS out of the loop to make things more stable, so
    \ disable all interrupts then re-enable the ones we're interested in.
    lda #&7f
    sta system_via_interrupt_enable_register
    sta user_via_interrupt_enable_register
    lda #&82:sta system_via_interrupt_enable_register \ enable VSYNC interrupt
    lda #&c0:sta user_via_interrupt_enable_register \ enable timer 1 interrupt
    \ Set timer 1 to continuous interrupts mode.
    lda #&40:sta user_via_auxiliary_control_register
    lda #lo(irq_handler):sta irq1v
    lda #hi(irq_handler):sta irq1v+1
    lda #0:sta frame_count
    cli
    jmp forever_loop

    \ TODO: Pay proper attention to alignment so the branches in the important code never take longer than necessary - this is a crude hack which will probably do the job but I haven't checked.
    align &100
.forever_loop

    \ Initialise all the addresses in the self-modifying code.
    lda #hi(count_table):sta lda_count_x+2:sta sta_count_x_1+2:sta sta_count_x_1b+2:sta sta_count_x_2+2
    lda #hi(period_table):sta adc_period_x+2
    lda #hi(state_table):sta lda_state_x+2:sta sta_state_x+2
    lda #hi(address_low_table):sta lda_address_low_x+2
    lda #hi(address_high_table):sta lda_address_high_x+2
    lda #hi(inverse_row_table):sta lda_inverse_row_x+2

    \ Reset X and led_group_count.
.lda_imm_led_groups
    lda #&ff \ patched
    sta led_group_count
.lda_imm_initial_x
    ldx #0 \ patched

    ; The idea here is that if we took less than 1/50th second to process the
    ; last update we wait for the next frame to start, but if we took longer we
    ; just keep going until we catch up.
    dec frame_count
    bpl missed_vsync
.vsync_wait_loop
    lda frame_count
    bmi vsync_wait_loop
if show_missed_vsync
    jmp SFTODOHACK
endif
.missed_vsync
if show_missed_vsync
    lda #1 eor 7:set_background_a
.SFTODOHACK
endif

.led_loop

    \ Decrement this LED's count and do nothing else if it's not yet zero.
    \ TODO: Relatively little code here touches carry; it may be possible to optimise away the sec/clc instructions here.
.lda_count_x
    lda $ff00,x \ patched
    sec
    \ TODO: This bmi at the cost of 2/3 cycles per LED means we can use the full 8-bit range of
    \ the count. This is an experiment.
    bmi not_going_to_toggle
    sbc #ticks_per_frame
    bmi toggle_led
.sta_count_x_1
    sta $ff00,x \ patched
    advance_to_next_led
.not_going_to_toggle
    sbc #ticks_per_frame
.sta_count_x_1b \ TODO: RENUMBER TO GET RID OF "b"
    sta $ff00,x \ patched
    advance_to_next_led

    \ Toggle this LED.
.toggle_led
    \ This LED's count has gone negative; add the period.
    clc
.adc_period_x
    adc $ff00,x \ patched
.sta_count_x_2
    sta $ff00,x \ patched
    \ Toggle the LED's state.
.lda_address_low_x
    lda $ff00,x \ patched
    sta screen_ptr
.lda_address_high_x
    lda $ff00,x \ patched
    sta screen_ptr+1
    ; We're about to modify screen memory, so if the raster is currently on this
    ; row, wait for it to pass.
.lda_inverse_row_x
    lda $ff00,x \ patched
.raster_loop
    cmp inverse_raster_row
    beq raster_loop
    ; TIME: From this point, we will take 4+2+5+2.5=14.5 cycles toggling the
    ; state and up to 52 cycles altering screen memory; that's 66.5 cycles. A
    ; scanline is 128 cycles and the top and bottom scanlines of each character
    ; row are always blank, so we should always avoid any visible tearing even
    ; if there's a little jitter or if the raster enters this character row
    ; immediately after the above test passed.
.lda_state_x
    lda $ff00,x \ patched
    eor #255
.sta_state_x
    sta $ff00,x \ patched
    beq turn_led_off

    ; compile_led_shape generates code at runtime here
.turn_led_on_start
    brk
    equs 0, "No LED!", 0
    skip 32 ; TODO: MAGIC CONSTANT
.turn_led_on_end

if FALSE ; TODO DELETE
    \ Turn this LED on.
    \ TIME: This takes 2+2*(2+6)+2+4*(2+6)=52 cycles (for big LEDs)
    \ TODO: We could offer other LED shapes, e.g. diamond, rectangular
if big_leds
    if led_style == 0
        lda #%00111100
        ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
        ldy #5:sta (screen_ptr),y
        lda #%01111110
        dey:sta (screen_ptr),y
        dey:sta (screen_ptr),y
        dey:sta (screen_ptr),y
        dey:sta (screen_ptr),y
    elif led_style == 1
        lda #%00010000
        ldy #0:sta (screen_ptr),y \ TODO: CMOS?
        ldy #4:sta (screen_ptr),y
        lda #%00111000
        dey:sta (screen_ptr),y
        ldy #1:sta (screen_ptr),y
        lda #%01111100
        iny:sta (screen_ptr),y
    elif led_style == 2
        lda #%01111110
        ldy #1:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
    elif led_style == 3
        lda #%01111110
        ldy #0:sta (screen_ptr),y \ TODO CMOS
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
    elif led_style == 4
        lda #%00010000
        ldy #0:sta (screen_ptr),y \ TODO CMOS
        iny:sta (screen_ptr),y
        lda #%00111000
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        lda #%01111100
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
    else
        error "Unknown led_style"
    endif
else
    if led_style == 0
        lda #%00011000
        ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
        ldy #3:sta (screen_ptr),y
        lda #%00111100
        dey:sta (screen_ptr),y
        dey:sta (screen_ptr),y
    elif led_style == 1
        lda #%00010000
        ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
        ldy #2:sta (screen_ptr),y
        lda #%00111000
        dey:sta (screen_ptr),y
    elif led_style == 2
        lda #%00111100
        ldy #1:sta (screen_ptr),y
        iny:sta (screen_ptr),y
    elif led_style == 3
        lda #%00111100
        ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
        iny:sta (screen_ptr),y
    elif led_style == 4
        lda #%00010000
        ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
        lda #%00111000
        iny:sta (screen_ptr),y
        lda #%01111100
        iny:sta (screen_ptr),y
    else
        error "Unknown led_style"
    endif
endif
    advance_to_next_led
endif

.turn_led_off
    \ Turn this LED off.
    \ TIME: This takes 2+6*(2+6)=50 cycles (for big LEDs)
    lda #0
    for y, 0, led_max_line
        \ TODO: Scope for using CMOS
        if y == 0
            ldy #0 \ TODO: tay would save one byte, but no faster and more obscure
        else
            iny
        endif
        sta (screen_ptr),y
    next
    advance_to_next_led_fall_through

.advance_to_next_led_group
    \ X has wrapped around to 0, so advance all the addresses in the self-modifying
    \ code to the next page.
    inc lda_count_x+2:inc sta_count_x_1+2:inc sta_count_x_1b+2:inc sta_count_x_2+2
    inc adc_period_x+2
    inc lda_state_x+2:inc sta_state_x+2
    inc lda_address_low_x+2
    inc lda_address_high_x+2
    inc lda_inverse_row_x+2
    dec led_group_count:beq forever_loop_indirect
    jmp led_loop
.forever_loop_indirect
    jmp forever_loop

; inverse_raster_row is used to track where we are on the screen, in terms of
; character rows. This is used to avoid updating LEDs when the raster is passing
; over them, which would cause visible tearing. It's 255 from VSYNC to the first
; visible scan line. In the visible region, it ranges from 32 on the top
; character row to 1 on the bottom character row. Below the last visible scan
; line it's 0.
.irq_handler
{
    lda &fc:pha
    lda system_via_interrupt_flag_register:and #&02:beq try_timer1
    \ Handle VSYNC interrupt.
    lda #lo(vsync_to_visible_start_us):sta user_via_timer_1_low_order_latch
    lda #hi(vsync_to_visible_start_us):sta user_via_timer_1_high_order_counter
    lda system_via_register_a \ clear the VSYNC interrupt
    lda #255:sta inverse_raster_row
.do_rti
    pla:sta &fc:rti

.try_timer1
    bit user_via_interrupt_flag_register:bvc do_rti
    \ Handle timer 1 interrupt.
    lda user_via_timer_1_low_order_latch \ clear timer 1 interrupt flag
    dec inverse_raster_row:bmi start_of_visible_region:beq end_of_visible_region
if show_rows
    \lda inverse_raster_row:and #1:clc:adc #1:eor #7:set_background_a
    lda inverse_raster_row:and #3:eor #7:set_background_a
endif
    pla:sta &fc:rti

.start_of_visible_region
    lda #lo(row_us):sta user_via_timer_1_low_order_latch
    lda #hi(row_us):sta user_via_timer_1_high_order_counter
    lda #32:sta inverse_raster_row
if show_rows
    lda #4 eor 7:set_background_a
endif
    pla:sta &fc:rti

.end_of_visible_region
    lda #&ff:sta user_via_timer_1_low_order_latch:sta user_via_timer_1_high_order_counter
    inc frame_count
if show_rows
    lda #5 eor 7:set_background_a
endif
if show_missed_vsync
    lda #0 eor 7:set_background_a
endif
    pla:sta &fc:rti \ jmp return_to_os
.return_to_os_hack
    pla:sta &fc:rti
}

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

\ TODO: START EXPERIMENTAL
; TODO: GIVE THIS ITS OWN FILE??
; TODO: THIS SHOULD TAKE ADVANTAGE OF CMOS INSTRUCTIONS IF AVAILABLE
.compile_led_shape
{
; TODO: PROPER ZP ALLOCATION
    src = ptr
    dest = screen_ptr
    runtime_y = working_index
   
    stx src:sty src+1
    lda #lo(turn_led_on_start):sta dest
    lda #hi(turn_led_on_start):sta dest+1

    ; Emit code to store the LED bitmap on the screen.
    lda #128:sta runtime_y
.bitmap_loop
    ; Emit an "lda #bitmap" instruction.
    ldy #0:lda (src),y:beq done
    ; TODO: NEXT THREE LINES MIGHT BE WORTH FACTORING OUT INTO SUBROUTINE
    pha
    lda #opcode_lda_imm:jsr emit
    pla:jsr emit
    ; Loop over the scanlines this bitmap needs to be written to and emit code.
.line_loop
    inc_word src
    ldy #0:lda (src),y:bmi line_loop_done
    ; A now contains the scanline index, held in Y at runtime.
    ldx is_65c02:beq not_65c02_line_0
    tax:bne not_65c02_line_0
    ; We're on a 65C02 and we're modifying scanline 0, so we can use the
    ; zp indirect addressing mode.
    lda #opcode_sta_zp_ind:jsr emit
    lda #screen_ptr:jsr emit
    jmp line_loop
.not_65c02_line_0
    ; Can we get set Y appropriately using iny or dey? (This is no faster than
    ; "ldy #n", but it's shorter.)
    inc runtime_y:cmp runtime_y:beq emit_iny
    dec runtime_y:dec runtime_y:cmp runtime_y:beq emit_dey
    ; No, we can't, so emit "ldy #n".
    sta runtime_y
    lda #opcode_ldy_imm:jsr emit
    lda runtime_y:jsr emit
    jmp y_set
.emit_iny
    lda #opcode_iny:bne emit_iny_dey
.emit_dey
    lda #opcode_dey
.emit_iny_dey
    jsr emit
.y_set
    ; Y is now set, so emit "sta (screen_ptr),y".
    lda #opcode_sta_zp_ind_y:jsr emit
    lda #screen_ptr:jsr emit
    jmp line_loop
.line_loop_done
    inc_word src
    jmp bitmap_loop
.done

    ; Emit code equivalent to our "advance_to_next_led" macro.
    lda #opcode_inx:jsr emit
    lda #opcode_bne:jsr emit
    sec:lda #lo(led_loop-1):sbc dest:jsr emit
    lda #opcode_beq:jsr emit
    sec:lda #lo(advance_to_next_led_group-1):sbc dest:jsr emit

    ; Check we haven't overflowed the available space; we have iff
    ; turn_led_on_end < dest.
    lda #hi(turn_led_on_end):cmp dest+1:bne use_high_byte_result
    lda #lo(turn_led_on_end):cmp dest
.use_high_byte_result
    bcs not_overflowed
    brk
    equs 0, "Code overflowed!", 0
.not_overflowed
    rts

.emit
    ldy #0:sta (dest),y
    inc_word dest
    rts

.is_65c02 equb 1 ; TODO: SHOULD AUTO-DETECT AT RUNTIME!
}

\ TODO: END EXPERIMENTAL

include "utilities.asm"
include "random.asm"
     

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    ; TODO: ALL OF THESE TABLES CAN BE MOVED AFTER ".end" AND THEREFORE WON'T TAKE UP SPACE ON DISC OR TAKE TIME TO LOAD FROM DISC - BUT AM WAITING UNTIL I PROGRAMATICALLY POPULATE period_table BEFORE MAKING THIS CHANGE
    align &100
.count_table
    skip led_count ; TODO: rename this max_led_count?

    ; TODO: PERIOD TABLE NEEDS TO BE GENERATED EVERY TIME USING USER'S FREQ CHOICES
macro pequb x
    assert x >= 0 and x <= 255
    equb x
endmacro

    align &100
.period_table
    for i, 0, led_count-1
        \ TODO: original try: equb 20+rnd(9)
        \ equb 23+rnd(5)
        \ equb 10+rnd(6)
        \ equb 12+rnd(4)
        \ equb 20+rnd(6) \ maybe not too bad
        \ equb 40+rnd(18) \ TODO EXPERIMENTAL - MAYBE NOT TOO BAD
        \ equb 40+rnd(7)
        \ equb 45+rnd(9)
        \ equb 47+rnd(5)
        \ equb 22+rnd(5)
        \ equb 22+rnd(9) \ maybe not too bad
        \ equb 22+rnd(7) \ maybe not too bad
        \ equb 30+rnd(9)
        \ equb 40+rnd(18)
        \ equb 20+rnd(18) \ TODO EXPERIMENTAL
        \ equb 46+rnd(4)+rnd(4)
        \ equb 30+rnd(5)+rnd(5)
        \ equb 30+rnd(3)+rnd(3)
        \ equb 50+rnd(5)+rnd(5)
        \ equb 40*ticks_per_frame+rnd(ticks_per_frame*2)
        pequb 22*ticks_per_frame+rnd(ticks_per_frame*5) \ fairly good (tpf=3, 4, 8)
    next

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
