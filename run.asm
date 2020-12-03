    org &70
    guard &90
.led_group_count
    equb 0
.vsync_count
    equb 0
.SFTODOTHING
    equb 0
.screen_ptr
    equw 0


    org &2000
    guard &5800

    led_count = 40*32
    ticks_per_frame = 8
    show_missed_vsync = FALSE
    big_leds = TRUE
    if big_leds
        led_start_line = 1
        led_max_line = 5
    else
        led_start_line = 2
        led_max_line = 3
    endif

    sys_int_vsync = 2
    sys_via_ifr = &fe40+13
    irq1v = &204

    user_via_auxiliary_control_register = &fe6b
    user_via_interrupt_flag_register = &fe6d
    user_via_interrupt_enable_register = &fe6e


macro advance_to_next_led_fall_through
    inx
    bne led_loop
endmacro

macro advance_to_next_led
    advance_to_next_led_fall_through
    beq advance_to_next_led_group \ always branch
endmacro

.start
    \ Interrupt code based on https://github.com/kieranhj/intro-to-interrupts/blob/master/source/screen-example.asm
    scanline_to_interrupt_at = -2
    vsync_position = 35
    total_rows = 39
    us_per_scanline = 64
    us_per_row = 8*us_per_scanline
    timer2_value_in_us = (total_rows-vsync_position)*us_per_row - 2*us_per_scanline + scanline_to_interrupt_at*us_per_scanline
    timer1_value_in_us = us_per_row - 2 \ us_per_row \ - 2*us_per_scanline
   
    sei
    lda #&7f:sta &fe4e:sta user_via_interrupt_enable_register \ disable all interrupts
    lda #&82
    sta &fe4e
    lda #&a0
    sta user_via_interrupt_enable_register
    lda #%11000000:sta user_via_interrupt_enable_register
    lda #%01000000:sta user_via_auxiliary_control_register
    lda &fe64
    lda irq1v:sta jmp_old_irq_handler+1
    lda irq1v+1:sta jmp_old_irq_handler+2
    lda #lo(irq_handler):sta irq1v
    lda #hi(irq_handler):sta irq1v+1
    lda #0:sta vsync_count
    cli
    jmp forever_loop

    \ TODO: Pay proper attention to alignment so the branches in the important code never take longer than necessary - this is a crude hack which will probably do the job but I haven't checked.
    align &100
.forever_loop

    \ Initialise all the addresses in the self-modifying code.
    lda #hi(count_table):sta lda_count_x+2:sta sta_count_x_1+2:sta sta_count_x_1b+2:sta sta_count_x_2+2
    lda #hi(period_table):sta adc_period_x+2
    lda #hi(state_table):sta lda_state_x+2:sta sta_state_x+2
    lda #hi(address_low_table):sta lda_address_low_x_1+2
    lda #hi(address_high_table):sta lda_address_high_x_1+2

    \ Reset X and led_group_count.
    \ At the moment we have 5*256 LEDs; if we had a number which wasn't a multiple of
    \ 256 we'd need to start the first pass round the loop with X>0 so we end neatly
    \ on a multiple of 256.
    lda #5:sta led_group_count \ TODO: SHOULD BE 5
    ldx #0

    \ The idea here is that if we took less than 1/50th second to process the last update we
    \ wait for VSYNC (well, more precisely, the start of the blank area at the bottom of the
    \ screen), but if we took longer we just keep going until we catch up.
    dec vsync_count
    bpl missed_vsync
.vsync_wait_loop
    lda vsync_count
    bmi vsync_wait_loop
if show_missed_vsync
    jmp SFTODOHACK
endif
.missed_vsync
if show_missed_vsync
    lda #1 eor 7:sta &fe21
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
.lda_address_low_x_1 \ TODO: _1 suffix now redundant
    lda $ff00,x \ patched
    sta screen_ptr
.lda_address_high_x_1 \ TODO: _1 suffix now redundant
    lda $ff00,x \ patched
    sta screen_ptr+1
.lda_state_x
    lda $ff00,x \ patched
    eor #255
.sta_state_x
    sta $ff00,x \ patched
.reset_toggle_byte_done
    beq turn_led_off

    \ Turn this LED on.
    \ TIME: This takes 2+2*(2+6)+2+4*(2+6)=52 cycles (for big LEDs)
if big_leds
    lda #%00111100
    ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
    ldy #5:sta (screen_ptr),y
    lda #%01111110
    dey:sta (screen_ptr),y
    dey:sta (screen_ptr),y
    dey:sta (screen_ptr),y
    dey:sta (screen_ptr),y
else
    lda #%00011000
    ldy #0:sta (screen_ptr),y \ TODO: could use CMOS instruction here
    ldy #3:sta (screen_ptr),y
    lda #%00111100
    dey:sta (screen_ptr),y
    dey:sta (screen_ptr),y
endif
    advance_to_next_led

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
    inc lda_address_low_x_1+2
    inc lda_address_high_x_1+2
    dec led_group_count:beq forever_loop_indirect
    jmp led_loop
.forever_loop_indirect
    jmp forever_loop

.irq_handler
{
    lda &fc:pha
    lda &fe4d:and #&02:beq try_timer1
    \ Handle VSYNC interrupt.
if show_missed_vsync
    lda #0 eor 7:sta &fe21
endif
    lda #0 eor 7:sta &fe21
    lda &fe41 \ SFTODO: clear this interrupt
    lda #lo(timer2_value_in_us):sta &fe68
    lda #hi(timer2_value_in_us):sta &fe69
    pla:sta &fc:rti \ SFTODO dont enter OS, hence clearing interrupt ourselves
.return_to_os
    pla:sta &fc
.^jmp_old_irq_handler
    jmp &ffff \ patched
.try_timer1
    \jmp try_timer2
    lda user_via_interrupt_flag_register \:bpl return_to_os
    and #&40:beq try_timer2 \ TODO: we could use bit instead of lda and and
    lda &fe64 \ clear timer1 interrupt flag
    dec SFTODOTHING:bmi bottom_of_screen
    lda SFTODOTHING:and #1:clc:adc #1:eor #7:sta &fe21
    pla:sta &fc:rti \ jmp return_to_os
.try_timer2
    lda user_via_interrupt_flag_register:and #&20:beq return_to_os_hack
    \lda #%11000000:sta user_via_interrupt_enable_register
    lda #lo(timer1_value_in_us):sta &fe64
    lda #hi(timer1_value_in_us):sta &fe65
    lda &fe68 \ TODO: POSS NOT NEEDED IF WE ARE DOING STA TO IT
    lda #4 eor 7:sta &fe21
    lda #31:sta SFTODOTHING
    pla:sta &fc:rti \ jmp return_to_os
.bottom_of_screen
    lda #5 eor 7:sta &fe21
    \lda #%01000000:sta user_via_interrupt_enable_register
    lda #&ff:sta &fe64:sta &fe65
    \lda &fe64 \ clear timer1 interrupt flag *again*!?
    \lda #0:sta &fe64:sta &fe65
    inc vsync_count
    pla:sta &fc:rti \ jmp return_to_os
.return_to_os_hack
    pla:sta &fc:rti
}
     

if FALSE \ TODO: DELETE
.led_pattern
if FALSE
    equb %00111100
    equb %01111110
    equb %01111110
    equb %01111110
    equb %01111110
    equb %00111100
else
    \ TODO: If I stick with this, I can avoid plotting the all 0s rows
    equb %00000000
    equb %00011000
    equb %00111100
    equb %00111100
    equb %00011000
    equb %00000000
endif
endif

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    align &100
.count_table
    for i, 0, led_count-1
        equb 1
    next

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
    for i, 0, led_count-1
        equb 0
    next

    HACKTODO=0

    align &100
.inverse_row_table
    for i, 0, led_count - 1
        equb 31 - (i % 40)
    next

    align &100
.address_low_table
    for i, 0, led_count-1
        equb lo(&5800 + i*8 +HACKTODO*40*8 + led_start_line)
    next

    align &100
.address_high_table
    for i, 0, led_count-1
        equb hi(&5800 + i*8 +HACKTODO*40*8 + led_start_line)
    next

.end

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

\ TODO: In mode 4 we potentially have enough RAM to double buffer the screen to avoid flicker

\ TODO: I should keep on with the mode 4 version, but I should also do a mode 7 version using separated graphics - that should be super smooth as it's character based and I can easily toggle individual sixels=LEDs

\ TODO: I should look into having the timer update (approximately; just sketching out a solution here) a "current line number" variable, and then before toggling an LED we would wait for the raster to pass if it's on our line or the line before - this would slow things down slightly, but we'd avoid any tearing
