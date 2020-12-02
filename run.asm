    org &70
    guard &90
.led_group_count
    equb 0
.vsync_count
    equb 0

    org &2000
    guard &5800

    led_count = 40*32
    ticks_per_frame = 4

    sys_int_vsync = 2
    sys_via_ifr = &fe40+13
    irq1v = &204


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
    scanline_to_interrupt_at = 128
    vsync_position = 35
    total_rows = 39
    us_per_scanline = 64
    us_per_row = 8*us_per_scanline
    timer2_value_in_us = (total_rows-vsync_position)*us_per_row - 2*us_per_scanline + scanline_to_interrupt_at*us_per_scanline
    
    sei
    lda #&82
    sta &fe4e
    lda #&a0
    sta &fe6e
    lda #lo(irq_handler):sta irq1v
    lda #hi(irq_handler):sta irq1v+1
    lda #0:sta vsync_count
    cli
    jmp forever_loop

    \ TODO: Pay proper attention to alignment so the branches in the important code never take longer than necessary - this is a crude hack which will probably do the job but I haven't checked.
    align &100
.forever_loop

    \ Initialise all the addresses in the self-modifying code.
    lda #hi(count_table):sta lda_count_x+2:sta sta_count_x_1+2:sta sta_count_x_2+2
    lda #hi(period_table):sta adc_period_x+2
    lda #hi(state_table):sta lda_state_x+2:sta sta_state_x+2
    lda #hi(address_low_table):sta lda_address_low_x_1+2:sta lda_address_low_x_2+2
    lda #hi(address_high_table):sta lda_address_high_x_1+2:sta lda_address_high_x_2+2

    \ Reset X and led_group_count.
    \ At the moment we have 5*256 LEDs; if we had a number which wasn't a multiple of
    \ 256 we'd need to start the first pass round the loop with X>0 so we end neatly
    \ on a multiple of 256.
    lda #2:sta led_group_count \ TODO: SHOULD BE 5
    ldx #0

    \ The idea here is that if we took less than 1/50th second to process the last update we
    \ wait for VSYNC (well, more precisely, the start of the blank area at the bottom of the
    \ screen), but if we took longer we just keep going until we catch up.
    dec vsync_count
    bpl missed_vsync
.vsync_wait_loop
    lda vsync_count
    bmi vsync_wait_loop
    jmp SFTODOHACK
.missed_vsync
    lda #1 eor 7:sta &fe21
.SFTODOHACK

    \ TIME: No-toggle time is: 7+2+2+3=14 cycles. That burns 15918 cycles for 1137 non-toggling LEDs, leaving 24082 cycles for toggling, giving an approx toggle budget of 168 cycles. This is borderline achievable (my cycle counts are a bit crude and slightly optimistic). No, this is overly simplistic, because occasionally LEDs with different periods will all end up toggling on the same frame.
.led_loop

    \ TODO: Can I give LEDs a higher resolution blink period? Obviously it has to be "rounded" to the 50Hz display, but this might result in an LED flashing "on average" at (say) 24.5Hz, giving more variety to the display. One easyish way to do this might be to have two different initial counts, one for after toggling on and one for toggling off, then (say) one could be 24 and the other could be 25 to give a 24.5Hz flash. (I have got the Hz figures totally wrong there, but it gives the idea anyway.)
    \ Decrement this LED's count and do nothing else if it's not yet zero.
.lda_count_x
    lda $ff00,x \ patched
    sec:sbc #ticks_per_frame
    bmi toggle_led
.sta_count_x_1
    sta $ff00,x \ patched
    advance_to_next_led

    \ Toggle this LED.
.toggle_led
    \ TIME: LED toggle is: 4+5+4+2+5+2+4+4+4+4+2+89+2+3=134 cycles, so ignoring any other overhead I can toggle 298 LEDs per frame
    \ This LED's count has gone negative; add the period.
    clc
.adc_period_x
    adc $ff00,x \ patched
.sta_count_x_2
    sta $ff00,x \ patched
    \ Toggle the LED's state.
.lda_state_x
    lda $ff00,x \ patched
    eor #255
.sta_state_x
    sta $ff00,x \ patched
.reset_toggle_byte_done
    beq turn_led_off

    \ Turn this LED on.
    \ Patch the screen update loop to use the right address.
.lda_address_low_x_1
    lda $ff00,x \ patched
    sta sta_led_address_y_1+1
.lda_address_high_x_1
    lda $ff00,x \ patched
    sta sta_led_address_y_1+2
    ldy #5
    \ TIME: Following loop is 6*(4+5+2)+7*3+2=89 cycles
.led_line_loop1
    lda led_pattern,y
.sta_led_address_y_1
    sta $ffff,y \ patched
    dey:bpl led_line_loop1
    advance_to_next_led

.turn_led_off
    \ Turn this LED off.
    \ Patch the screen update loop to use the right address.
.lda_address_low_x_2
    lda $ff00,x \ patched
    sta sta_led_address_y_2+1
.lda_address_high_x_2
    lda $ff00,x \ patched
    sta sta_led_address_y_2+2
    ldy #5
    lda #0
.led_line_loop2
.sta_led_address_y_2
    sta $ffff,y \ patched
    dey:bpl led_line_loop2
    advance_to_next_led_fall_through

.advance_to_next_led_group
    \ X has wrapped around to 0, so advance all the addresses in the self-modifying
    \ code to the next page.
    inc lda_count_x+2:inc sta_count_x_1+2:inc sta_count_x_2+2
    inc adc_period_x+2
    inc lda_state_x+2:inc sta_state_x+2
    inc lda_address_low_x_1+2:inc lda_address_low_x_2+2
    inc lda_address_high_x_1+2:inc lda_address_high_x_2+2
    dec led_group_count:bne led_loop
    jmp forever_loop

.irq_handler
{
    lda &fc:pha
    lda &fe4d:and #&02:beq try_timer2
    \ Handle VSYNC interrupt.
    lda #0 eor 7:sta &fe21
    lda #lo(timer2_value_in_us):sta &fe68
    lda #hi(timer2_value_in_us):sta &fe69
.do_rti
    pla:sta &fc
    jmp &e5ff \ rti \ TODO!?
.try_timer2
    lda &fe6d:and #&20:beq do_rti
    inc vsync_count
    lda &fe68
    \lda #4 eor 7:sta &fe21
    jmp do_rti
}
     

.led_pattern
if TRUE
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

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    align &100
.count_table
    for i, 0, led_count-1
        equb 1
    next

macro pequb x
    assert x >= 0 and x <= 127
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
        pequb 22*ticks_per_frame+rnd(ticks_per_frame*5) \ fairly good (tpf=3, 4)
    next

    align &100
.state_table
    for i, 0, led_count-1
        equb 0
    next

    \ We do +1 in the address calculations because the LED only occupies lines 1-6
    \ of the character cell, not the full lines 0-7.
    HACKTODO=0

    align &100
.address_low_table
    for i, 0, led_count-1
        equb lo(&5800 + i*8 +HACKTODO*40*8 + 1)
    next

    align &100
.address_high_table
    for i, 0, led_count-1
        equb hi(&5800 + i*8 +HACKTODO*40*8 + 1)
    next

.end

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

\ TODO: In mode 4 we potentially have enough RAM to double buffer the screen to avoid flicker

\ TODO: I should keep on with the mode 4 version, but I should also do a mode 7 version using separated graphics - that should be super smooth as it's character based and I can easily toggle individual sixels=LEDs
