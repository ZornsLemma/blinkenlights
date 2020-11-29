    ; TODO: This will take equal time to turn an LED on or off. We could
    ; potentially have different code for turning on and off, in order to avoid
    ; doing "and mask" for every row, and we could make off faster (if that
    ; didn't cause annoying or at least useless asymmetries) by avoiding the
    ; user of led_pattern when turning off.
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
