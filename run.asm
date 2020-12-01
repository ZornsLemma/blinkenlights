    ; TODO: This will take equal time to turn an LED on or off. We could
    ; potentially have different code for turning on and off, in order to avoid
    ; doing "and mask" for every row, and we could make off faster (if that
    ; didn't cause annoying or at least useless asymmetries) by avoiding the
    ; user of led_pattern when turning off.
    \ TODO: We should maybe do screen_ptr+1 *first* (probably re-organising the
    \ table so they are still in ascending byte order) because then we can use
    \ a `beq done_this_frame` after loading screen_ptr+1 byte from table,
    \ because it can't legitimately be zero.
    ldy tmp_y \ 3
    lda (table),y:sta mask:eor #255:sta (table),y \ 5+3+2+6=16
    iny:lda (table),y:sta screen_ptr \ 2+5+4=11
    iny:lda (table),y:sta screen_ptr+1 \ 2+5+4=11
    sty tmp_y \ 4
    ldy #7 \ 2
.loop
    lda led_pattern,y:and mask:sta (screen_ptr),y \ 4+3+6=13
    dey:bpl loop \ 2+3=5 (ignoring 2 cycle non-branch)
    \ adds to 3+16+11+11+4+2+(13+5)*8=191 cycles per LED, ignoring any overhead
    \ on timing loop (i.e. we can't wait for 0 cycles because there will be some
    \ overhead in setting it up). But 191 cycles per LED would allow us to
    \ toggle 209 LEDs per 1/50th second frame.
    
    \ Of course we don't actually need a timing loop. We just need a "wait for
    \ next frame" indicator in our LED data list, since there is no point doing
    \ toggles at a higher rate.



.led_pattern
    equb %00000000
    equb %00111100
    equb %01111110
    equb %01111110
    equb %01111110
    equb %01111110
    equb %00111100
    equb %00000000




\ "No toggle" case is 23 cycles most of the time
\ On average 143 LEDs will toggle per tick, leaving 1137 no toggles
\ That leaves us 13849 cycles (a bit less really) per frame to do the toggles, or
\ 96 cycles per LED. The code below is looking at very very approximately 140 cycles per LED,
\ so we're not going to hit 50Hz on a full screen at this rate. Of course, half the toggles
\ will be to off and that code is potentially a little bit faster, but still probably not
\ enough.

.outer_loop \ TODO: rename
    \ TODO: We need to break out of this outer_loop when we've done all the LEDs
    lda (table),y
    sec:sbc #1
    bne no_toggle
    lda (table2),y:eor #255:sta (table2),y
    beq led_off
    \ TODO: table3/table4 are only read once, so we could potentially use self-modify abs,y instead of indirect y
    lda (table3),y:sta sta_abs_x+1
    lda (table4),y:sta sta_abs_x+2
    ldx #7
.loop
    lda led_pattern,x
.sta_abs_x
    sta $ffff,x \ address is patched by earlier code
    dex:bpl loop
    bmi SFTODO \ always branch
.led_off
    \ SFTODO: Very similar to above but all-0 writes
.SFTODO
    lda SFTODORESETCOUNT
.no_toggle
    sta (table),y \ TODO: IS Y STILL SET!?

    iny
    bne outer_loop
    inc table+1
    inc table2+1
    inc table3+1
    inc table4+1
    jmp outer_loop \ SFTODO: could prob bne=always




    \ TODO: Need to initialise all the self-modifying addresses before entering loop
    ldx #0
    \ TODO: Need to break out of led_loop after doing all LEDs
    \ TIME: No-toggle time is: 7+2+2+3=14 cycles. That burns 15918 cycles for 1137 non-toggling LEDs, leaving 24082 cycles for toggling, giving an approx toggle budget of 168 cycles. This is borderline achievable (my cycle counts are a bit crude and slightly optimistic).
.led_loop
    \ Decrement this LED's count and do nothing else if it's not yet zero.
.dec_count_x
    dec $ffff,x \ patched
    beq toggle_led
    inx:bne led_loop
    beq next_led_group \ always branch
    \ TIME: LED toggle is: 4+5+7+3+2+4+4+4+4+2+111+2+3=155 cycles ignoring the 1-in-8 cost of reset_toggle_byte and the relatively rare next_led_group case
    \ This LED's count has hit zero; reset it.
.lda_initial_count_x
    lda $ffff,x \ patched
.sta_count_x
    sta $ffff,x \ patched
    \ Toggle the LED's state SFTODO IN TABLE? ON SCREEN? DO WE ONLY HAVE SCREEN?
    asl $ffff,x \ patched
    beq reset_toggle_byte \ reset to %01010101 if 0
.reset_toggle_byte_done
    bcc turn_led_off
    \ Patch the screen update loop to use the right address.
    lda $ffff,x \ patched
    sta sta_led_address_y+1
    lda $ffff,x \ patched
    sta sta_led_address_y+2
    ldy #7
    \ TIME: Following loop is 8*(4+5+2)+7*3+2=111 cycles
.led_line_loop
    lda led_pattern,y
.sta_led_address_y
    sta $ffff,y \ patched
    dey:bpl led_line_loop
    \ Move on to the next LED.
    inx:bne led_loop
    beq next_led_group \ always branch
.led_off
    \ TODO!
.led_done
    \ Move on to the next LED.
    inx:bne led_loop
.next_led_group
    inc dec_count_x+2
    inc lda_initial_count_x+2
    inc sta_count_x+2
    \ TODO: MORE
    jmp led_loop

.reset_toggle_byte
    txa:tay
    lda #%01010101 \ note LSB is 1, so we don't reset this early
    sta (asl_state_x+1),y \ TODO: only works if code is in zero page!
    bne reset_toggle_byte_done



\ TODO: In mode 4 we potentially have enough RAM to double buffer the screen to avoid flicker
