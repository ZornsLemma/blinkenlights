    org &70
    guard &90
.led_group_count
    equb 0

    org &2000
    guard &5800

    led_count = 40*32

    sys_int_vsync = 2
    sys_via_ifr = &fe40+13


macro advance_to_next_led_fall_through
    inx
    bne led_loop
endmacro

macro advance_to_next_led
    advance_to_next_led_fall_through
    beq advance_to_next_led_group \ always branch
endmacro

.start

.forever_loop

    sei \ TODO: EXPERIMENTAL

    \ Initialise all the addresses in the self-modifying code.
    lda #hi(count_table):sta dec_count_x+2:sta sta_count_x+2
    lda #hi(period_table):sta lda_period_x+2
    lda #hi(state_table):sta lda_state_x+2:sta sta_state_x+2
    lda #hi(address_low_table):sta lda_address_low_x_1+2:sta lda_address_low_x_2+2
    lda #hi(address_high_table):sta lda_address_high_x_1+2:sta lda_address_high_x_2+2

    \ Reset X and led_group_count.
    \ At the moment we have 5*256 LEDs; if we had a number which wasn't a multiple of
    \ 256 we'd need to start the first pass round the loop with X>0 so we end neatly
    \ on a multiple of 256.
    lda #1:sta led_group_count \ TODO: SHOULD BE 5
    ldx #0

    \ TODO: This messes things up, I *guess* because I'm not always completing in less than
    \ a frame and therefore it causes some "frames" to actually take two frames, or similar.
if TRUE 
    \ Wait for VSYNC.
    lda #sys_int_vsync
    sta sys_via_ifr
.vsync_loop
    bit sys_via_ifr
    beq vsync_loop
endif

    \ TIME: No-toggle time is: 7+2+2+3=14 cycles. That burns 15918 cycles for 1137 non-toggling LEDs, leaving 24082 cycles for toggling, giving an approx toggle budget of 168 cycles. This is borderline achievable (my cycle counts are a bit crude and slightly optimistic).
.led_loop

    \ Decrement this LED's count and do nothing else if it's not yet zero.
.dec_count_x
    dec $ff00,x \ patched
    beq toggle_led
    advance_to_next_led

    \ Toggle this LED.
.toggle_led
    \ TIME: LED toggle is: 4+5+7+3+2+4+4+4+4+2+111+2+3=155 cycles ignoring the 1-in-8 cost of reset_toggle_byte and the relatively rare advance_to_next_led_group case
    \ This LED's count has hit zero; reset it.
.lda_period_x
    lda $ff00,x \ patched
.sta_count_x
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
    \ TIME: Following loop is 8*(4+5+2)+7*3+2=111 cycles - no, it's now 6*...
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
    inc dec_count_x+2:inc sta_count_x+2
    inc lda_period_x+2
    inc lda_state_x+2:inc sta_state_x+2
    inc lda_address_low_x_1+2:inc lda_address_low_x_2+2
    inc lda_address_high_x_1+2:inc lda_address_high_x_2+2
    dec led_group_count:bne led_loop
    jmp forever_loop

.led_pattern
    equb %00111100
    equb %01111110
    equb %01111110
    equb %01111110
    equb %01111110
    equb %00111100

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    align &100
.count_table
    for i, 0, led_count-1
        equb 1
    next

    align &100
.period_table
    for i, 0, led_count-1
        equb 20+rnd(9)
    next

    align &100
.state_table
    for i, 0, led_count-1
        equb 0
    next

    \ We do +1 in the address calculations because the LED only occupies lines 1-6
    \ of the character cell, not the full lines 0-7.

    align &100
.address_low_table
    for i, 0, led_count-1
        equb lo(&5800 + i*8 + 1)
    next

    align &100
.address_high_table
    for i, 0, led_count-1
        equb hi(&5800 + i*8 + 1)
    next

.end

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

\ TODO: In mode 4 we potentially have enough RAM to double buffer the screen to avoid flicker
