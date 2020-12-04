    org &70
    guard &90
.led_group_count
    equb 0
.frame_count
    equb 0
.inverse_raster_row
    equb 0
.screen_ptr
    equw 0


    org &2000
    guard &5800

    led_count = 40*32
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
    \ At the moment we have 5*256 LEDs; if we had a number which wasn't a multiple of
    \ 256 we'd need to start the first pass round the loop with X>0 so we end neatly
    \ on a multiple of 256.
    lda #5:sta led_group_count \ TODO: SHOULD BE 5
    ldx #0

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
        equb 32 - (i div 40)
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
