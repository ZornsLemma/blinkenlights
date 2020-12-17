; End-of-text marker for print_string_*
eot = 128

; Select mode A and turn the cursor off.
.set_mode
    pha
    lda #vdu_set_mode:jsr oswrch
    pla:jsr oswrch
    jsr print_string_inline:equb 23, 1, 0, 0, 0, 0, 0, 0, 0, 0, eot
    rts

; Set logical colour X to physical colour Y.
.set_palette_x_to_y
    lda #vdu_set_palette:jsr oswrch
    txa:jsr oswrch
    tya:jsr oswrch
    jsr print_string_inline:equb 0, 0, 0, eot
    rts

; Print the string following "jsr print_string_inline" (terminated by eot) using
; OSWRCH.
.print_string_inline
{
    ptr = zp_tmp
   
    pla:sta ptr
    pla:sta ptr+1
    ldy #0
.loop
    inc_word ptr
    lda (ptr),y
    cmp #eot:beq done
    jsr oswrch
    jmp loop
.done
    lda ptr+1:pha
    lda ptr:pha
    rts
}
