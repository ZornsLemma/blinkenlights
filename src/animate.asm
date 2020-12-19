{ ; open file scope

; Debug options
show_missed_vsync_1 = FALSE
show_missed_vsync_2 = FALSE
show_rows = FALSE
assert not(show_missed_vsync_1 and show_rows)
slow_palette = TRUE
; check_carry makes the code a little bit bigger as well as slower, and if
; the runtime-generated branches would be out of range it can have odd
; effects, so if things go wrong when it's enabled it might be that instead
; of invalid carry values.
check_carry = FALSE

scanline_to_interrupt_at = -2
vsync_position = 35
total_rows = 39
us_per_scanline = 64
us_per_row = 8*us_per_scanline
vsync_to_visible_start_us = (total_rows-vsync_position)*us_per_row - 2*us_per_scanline + scanline_to_interrupt_at*us_per_scanline
row_us = us_per_row - 2

animate_start = *

org shared_zp_start
guard shared_zp_end
clear shared_zp_start, shared_zp_end
.led_group_count
    skip 1
.frame_count
    skip 1
.inverse_raster_row
    skip 1
.working_index
    skip 1
.led_x
    skip 1
.led_y
    skip 1

org animate_start
guard mode_4_screen

irq_tmp_a = &fc

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

; A macro for use after performance-critical branch instructions to check that
; no page-crossing penalty is incurred.
macro check_no_page_crossing target
    assert hi(*) == hi(target)
endmacro

macro bmi_npc target
    bmi target
    check_no_page_crossing target
endmacro

macro beq_npc target
    beq target
    check_no_page_crossing target
endmacro

macro bne_npc target
    bne target
    check_no_page_crossing target
endmacro

macro xclc
    if check_carry
        .hang
            bcs hang
    endif
endmacro

macro xsec
    if check_carry
        .hang
            bcc hang
    endif
endmacro

; Note that the following two macros are also expanded at runtime by
; compile_led_shape, so they must be kept in sync.

macro advance_to_next_led_fall_through
    inx
    bne_npc led_loop
endmacro

macro advance_to_next_led
    advance_to_next_led_fall_through
    beq advance_to_next_led_group \ always branch
endmacro

.*start_animation
{
    \ Select mode 4 and set the foreground and background colours.
    lda #4:jsr set_mode
    ldx #0:ldy option_panel_colour:jsr set_palette_x_to_y
    ldx #1:ldy option_led_colour:jsr set_palette_x_to_y

    ; Set all the LEDs to be off and just about to turn on, so they start in sync.
    assert max_led_count == 5*256
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
    {
        jsr get_panel_template_address
        stx src:sty src+1

        \ The first two bytes of the template are the number of LEDs; we need to set up
        \ the per-frame initialisation accordingly, and if we don't have an exact
        \ multiple of 256 LEDs we need to take that into account by starting with X>0.
        ldy #1:lda (src),y:sta lda_imm_led_groups+1
        dey:lda (src),y:beq exact_multiple
        inc lda_imm_led_groups+1
        lda #0:sec:sbc (src),y
    .exact_multiple
        sta lda_imm_initial_x+1:sta working_index
        clc:lda src:adc #2:sta src
        inc_word_high src+1

        lda #hi(inverse_row_table):sta sta_inverse_row_table_x+2
        lda #hi(address_low_table):sta sta_address_low_table_x+2
        lda #hi(address_high_table):sta sta_address_high_table_x+2

        lda #0:sta led_x:sta led_y
        ; If we have large LEDs, "Y=0" is actually scanline 1 within the character
        ; cell; for small LEDs, "Y=0" is scanline 2.
        lda option_led_size:clc:adc #1
        sta dest
        lda #&58:sta dest+1
    .outer_loop
        ldy #0:lda (src),y
        ; A contains a bitmap representing potential LED positions from led_x to
        ; led_x+7 in row led_y.
        ldx #8
    .group_of_8_loop
        asl a
        pha
        bcc empty
        ldy working_index
        lda #mode_4_height:sec:sbc led_y
    .sta_inverse_row_table_x
        sta &ff00,y \ patched
        lda dest
    .sta_address_low_table_x
        sta &ff00,y \ patched
        lda dest+1
    .sta_address_high_table_x
        sta &ff00,y \ patched
        inc working_index
        bne not_next_led_group
        inc sta_inverse_row_table_x+2
        inc sta_address_low_table_x+2
        inc sta_address_high_table_x+2
    .not_next_led_group
    .empty
        lda dest:clc:adc #mode_4_char_lines:sta dest
        inc_word_high dest+1
        inc led_x
        pla
        dex:bne group_of_8_loop
        inc_word src
        lda led_x:cmp #mode_4_width:bne outer_loop
        lda #0:sta led_x
        inc led_y
        lda led_y:cmp #mode_4_height:bne outer_loop
    }

    ; Initialise the LED periods using randomly generated values based on the
    ; chosen parameters.
    {
        parameter_a = zp_tmp
        parameter_b = zp_tmp+1
        parameter_c = zp_tmp+2
        period = zp_tmp+3

        ; Set src=frequency_spread_parameters +
        ;         4*((option_led_frequency * num_spreads) + option_led_spread).
        ; We just do a naive multiplication by addition here, it's simple and
        ; not performance-sensitive.
        lda option_led_spread:sta src
        lda #0:sta src+1
        ldx option_led_frequency:beq multiply_done
    .multiply_loop
        clc:lda src:adc #num_spreads:sta src
        inc_word_high src+1
        dex:bne multiply_loop
    .multiply_done
        asl src:asl src+1
        asl src:asl src+1
        clc:lda src:adc #lo(frequency_spread_parameters):sta src
        lda src+1:adc #hi(frequency_spread_parameters):sta src+1

        ; Set the runtime ticks-per-frame.
        ldy #0:lda (src),y
        sta sbc_imm_ticks_per_frame_1+1:sta sbc_imm_ticks_per_frame_2+1

        ; Generate the random LED periods.
        iny:lda (src),y:sta parameter_a
        iny:lda (src),y:sta parameter_b
        iny:lda (src),y:sta parameter_c
        lda option_led_distribution:bne binomially_distributed
        clc:lda parameter_b:adc parameter_c:sta parameter_b:dec parameter_b
        lda #0:sta parameter_c
    .binomially_distributed
        lda lda_imm_led_groups+1:sta led_group_count
        lda lda_imm_initial_x+1:sta working_index
        lda #hi(period_table):sta sta_period_table_x+2
    .generate_random_led_loop
        lda parameter_a:sta period
        lda parameter_b:jsr urandom8:clc:adc period:sta period
        lda parameter_c:beq no_parameter_c
        jsr urandom8:clc:adc period:sta period
    .no_parameter_c
        ldx working_index
        lda period
    .sta_period_table_x
        sta &ff00,x \ patched
        inc working_index:bne generate_random_led_loop
        inc sta_period_table_x+2
        dec led_group_count:bne generate_random_led_loop
    }

    \ Interrupt code based on https://github.com/kieranhj/intro-to-interrupts/blob/master/source/screen-example.asm

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

.forever_loop

    \ Initialise all the addresses in the self-modifying code.
    lda #hi(count_table):sta lda_count_x+2:sta sta_count_x_1+2:sta sta_count_x_2+2:sta sta_count_x_3+2
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
if show_missed_vsync_1
    jmp no_missed_vsync
endif
.missed_vsync
if show_missed_vsync_2
    lda frame_count:sta &5800
endif
if show_missed_vsync_1
    lda #colour_red eor 7:set_background_a
.no_missed_vsync
endif

    sec
.^led_loop

    \ Decrement this LED's count and do nothing else if it's not yet negative.
.lda_count_x
    lda &ff00,x \ patched
    xsec
    ; We need to be able to detect if the LED's count has gone negative. By
    ; checking the count before we subtract ticks_per_frame, we can use the full
    ; 8-bit unsigned range of the count.
    bmi_npc not_going_to_toggle
.sbc_imm_ticks_per_frame_1
    sbc #&ff \ patched
    bmi_npc toggle_led
.sta_count_x_1
    sta &ff00,x \ patched
    advance_to_next_led
.not_going_to_toggle
.sbc_imm_ticks_per_frame_2
    sbc #&ff \ patched
.sta_count_x_2
    sta &ff00,x \ patched
    advance_to_next_led

    \ Toggle this LED.
.toggle_led
    \ This LED's count has gone negative; add the period.
    xclc
.adc_period_x
    adc &ff00,x \ patched
.sta_count_x_3
    sta &ff00,x \ patched
    \ Toggle the LED's state.
.lda_address_low_x
    lda &ff00,x \ patched
    sta dest
.lda_address_high_x
    lda &ff00,x \ patched
    sta dest+1
    ; We're about to modify screen memory, so if the raster is currently on this
    ; row, wait for it to pass.
.lda_inverse_row_x
    lda &ff00,x \ patched
.raster_loop
    eor inverse_raster_row ; use eor so we don't alter carry
    beq raster_loop
    ; TIME: From this point, we will take 4+2+5+2.5=14.5 cycles toggling the
    ; state and up to 52 cycles altering screen memory; that's 66.5 cycles. A
    ; scanline is 128 cycles and the top and bottom scanlines of each character
    ; row are always blank, so we should always avoid any visible tearing even
    ; if there's a little jitter or if the raster enters this character row
    ; immediately after the above test passed.
.lda_state_x
    lda &ff00,x \ patched
    eor #255
.sta_state_x
    sta &ff00,x \ patched
.^beq_turn_led_off
    beq_npc advance_to_next_led_group \ patched

    ; compile_led_shape generates code at runtime here.
.^turn_led_on_start
    brk
    equs 0, "No LED!", 0
    skip 31
.^turn_led_on_end
    skip 23

.^advance_to_next_led_group
    \ X has wrapped around to 0, so advance all the addresses in the self-modifying
    \ code to the next page.
    inc lda_count_x+2:inc sta_count_x_1+2:inc sta_count_x_2+2:inc sta_count_x_3+2
    inc adc_period_x+2
    inc lda_state_x+2:inc sta_state_x+2
    inc lda_address_low_x+2
    inc lda_address_high_x+2
    inc lda_inverse_row_x+2
    dec led_group_count:beq forever_loop_indirect
    jmp led_loop
.forever_loop_indirect
    jmp forever_loop
}

; inverse_raster_row is used to track where we are on the screen, in terms of
; character rows. This is used to avoid updating LEDs when the raster is passing
; over them, which would cause visible tearing. It's 255 from VSYNC to the first
; visible scan line. In the visible region, it ranges from 32 on the top
; character row to 1 on the bottom character row. Below the last visible scan
; line it's 0.
.irq_handler
{
    lda irq_tmp_a:pha
    lda system_via_interrupt_flag_register:and #&02:beq try_timer1
    \ Handle VSYNC interrupt.
    lda #lo(vsync_to_visible_start_us):sta user_via_timer_1_low_order_latch
    lda #hi(vsync_to_visible_start_us):sta user_via_timer_1_high_order_counter
    lda system_via_register_a \ clear the VSYNC interrupt
    lda #255:sta inverse_raster_row
.do_rti
    pla:sta irq_tmp_a:rti

.try_timer1
    bit user_via_interrupt_flag_register:bvc do_rti
    \ Handle timer 1 interrupt.
    lda user_via_timer_1_low_order_latch \ clear timer 1 interrupt flag
    dec inverse_raster_row:bmi start_of_visible_region:beq end_of_visible_region
if show_rows
    lda inverse_raster_row:and #3:eor #7:set_background_a
endif
    pla:sta irq_tmp_a:rti

.start_of_visible_region
    lda #lo(row_us):sta user_via_timer_1_low_order_latch
    lda #hi(row_us):sta user_via_timer_1_high_order_counter
    lda #32:sta inverse_raster_row
if show_rows
    lda #colour_blue eor 7:set_background_a
endif
    pla:sta irq_tmp_a:rti

.end_of_visible_region
    lda #&ff:sta user_via_timer_1_low_order_latch:sta user_via_timer_1_high_order_counter
    inc frame_count
if show_rows
    lda #colour_magenta eor 7:set_background_a
endif
if show_missed_vsync_1
    lda #colour_black eor 7:set_background_a
endif
    pla:sta irq_tmp_a:rti \ jmp return_to_os
.return_to_os_hack
    pla:sta irq_tmp_a:rti
}

.compile_led_shape
{
    runtime_y = zp_tmp

    ; Emit code to store the LED bitmap on the screen.
    {
        stx src:sty src+1
        lda #lo(turn_led_on_start):sta dest
        lda #hi(turn_led_on_start):sta dest+1
        lda #128:sta runtime_y
    .bitmap_loop
        ; Emit an "lda #bitmap" instruction.
        ldy #0:lda (src),y:beq done
        pha
        lda #opcode_lda_imm:jsr emit_inc
        pla:jsr emit_inc
        ; Loop over the scanlines this bitmap needs to be written to and emit code.
    .line_loop
        inc_word src
        ldy #0:lda (src),y:bmi line_loop_done
        ; A now contains the scanline index, held in Y at runtime.
        ldx cpu_type:beq not_65c02_line_0
        tax:bne not_65c02_line_0
        ; We're on a 65C02 and we're modifying scanline 0, so we can use the
        ; zp indirect addressing mode.
        lda #opcode_sta_zp_ind:jsr emit_inc
        lda #dest:jsr emit_inc
        jmp line_loop
    .not_65c02_line_0
        ; Can we set Y appropriately using iny or dey? (This is no faster than "ldy
        ; #n", but it's shorter.)
        inc runtime_y:cmp runtime_y:beq emit_iny
        dec runtime_y:dec runtime_y:cmp runtime_y:beq emit_dey
        ; No, we can't, so emit "ldy #n".
        sta runtime_y
        lda #opcode_ldy_imm:jsr emit_inc
        lda runtime_y:jsr emit_inc
        jmp y_set
    .emit_iny
        lda #opcode_iny:bne emit_iny_dey
    .emit_dey
        lda #opcode_dey
    .emit_iny_dey
        jsr emit_inc
    .y_set
        ; Y is now set, so emit "sta (dest),y".
        lda #opcode_sta_zp_ind_y:jsr emit_inc
        lda #dest:jsr emit_inc
        jmp line_loop
    .line_loop_done
        inc_word src
        jmp bitmap_loop
    .done

        ; Emit code equivalent to our "advance_to_next_led" macro.
        lda #opcode_inx:jsr emit_inc
        lda #opcode_bne:jsr emit_inc
        sec:lda #lo(led_loop-1):sbc dest:jsr emit_inc
        lda #opcode_beq:jsr emit_inc
        sec:lda #lo(advance_to_next_led_group-1):sbc dest:jsr emit_inc

        ; Check we haven't overflowed the available space; we have iff
        ; turn_led_on_end < dest.
        lda #hi(turn_led_on_end):cmp dest+1:bne use_high_byte_result
        lda #lo(turn_led_on_end):cmp dest
    .use_high_byte_result
        bcs not_overflowed
        brk
        equs 0, "Code overflowed!", 0
    .not_overflowed
    }

    ; Emit code to clear the LED bitmap from the screen. We emit this backwards,
    ; so we can fall through into advance_to_next_led_group. The entry to the
    ; code is via beq_turn_led_off, which we patch to refer to the correct start
    ; address.
    {
        lda #lo(advance_to_next_led_group-1):sta dest
        lda #hi(advance_to_next_led_group-1):sta dest+1
        ; Emit advance_to_next_led_fall_through.
        sec:lda #lo(led_loop-1):sbc dest:jsr emit_dec
        lda #opcode_bne:jsr emit_dec
        lda #opcode_inx:jsr emit_dec
        ldx #led_height_large-1
        lda option_led_size:beq large_led
        ldx #led_height_small-1
    .large_led
    .line_loop
        lda #dest:jsr emit_dec
        lda cpu_type:beq not_65c02_line_0
        txa:bne not_65c02_line_0
        lda #opcode_sta_zp_ind:jsr emit_dec
        jmp y_set
    .not_65c02_line_0
        lda #opcode_sta_zp_ind_y:jsr emit_dec
        txa:beq line_0
        lda cpu_type:beq not_65c02_line_1
        cpx #1:bne not_65c02_line_1
        txa:jsr emit_dec
        lda #opcode_ldy_imm:jsr emit_dec
        jmp y_set
    .not_65c02_line_1
        lda #opcode_iny:jsr emit_dec
        jmp y_set
    .line_0
        lda #opcode_tay:jsr emit_dec ; set Y=0
    .not_line_0
    .y_set
        dex:bpl line_loop
        lda #0:jsr emit_dec
        lda #opcode_lda_imm:jsr emit_dec
        ; Check we haven't overflowed the available space; we have iff dest <
        ; turn_led_on_end-1.
        lda dest+1:cmp #hi(turn_led_on_end-1):bne use_high_byte_result
        lda dest:cmp #lo(turn_led_on_end-1)
    .use_high_byte_result
        bcs not_overflowed
        brk
        equs 0, "Code overflowed!", 0
    .not_overflowed
        ; Patch up beq_turn_led_off to transfer control to dest+1.
        sec:lda dest:sbc #lo(beq_turn_led_off+1):sta beq_turn_led_off+1
    }

    rts

.emit_inc
    ldy #0:sta (dest),y
    inc_word dest
    rts

.emit_dec
    ldy #0:sta (dest),y
    lda dest:bne no_borrow
    dec dest+1
.no_borrow
    dec dest
    rts
}

} ; close file scope

; TODO: STANDARDISE ON ; NOT \ FOR COMMENTS
