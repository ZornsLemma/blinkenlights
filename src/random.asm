{

; The idea of multiplying using a table in advance_seed_randomise_a and the
; observation that the low byte of the seed will always be odd were originated
; by Bruce Clark (http://6502.org/source/integers/random/random.html).

c = 1

; Set seed = seed*a + c (mod 2^32).
.advance_seed_randomise_a
{
    ; a*seed = a*(seed0 + seed1<<8 + seed2<<16 + seed3<<24)
    ;        = a*seed0 + a*(seed1<<8) + a*(seed2<<16) + a*(seed3<<24)
    ;        = a*seed0 + (a*seed1)<<8 + (a*seed2)<<16 + (a*seed3)<<24

    clc
    ldx seed0
    ldy seed1
    lda mult_by_a_table0,x:adc #c:sta seed0
    lda mult_by_a_table1,x:adc mult_by_a_table0,y:sta seed1
    lda mult_by_a_table2,x:adc mult_by_a_table1,y:sta rng_tmp
    lda mult_by_a_table3,x:adc mult_by_a_table2,y:tay

    clc
    ldx seed2
    lda mult_by_a_table0,x:adc rng_tmp:sta seed2
    tya:adc mult_by_a_table1,x

    clc
    ldx seed3
    adc mult_by_a_table0,x:sta seed3

    ; A contains the most significant byte of the seed, which is a reasonable choice
    ; for a random 8-bit byte. (We must not use seed0 as it will always be odd.)
    rts
}

; Return a uniformly distributed random number between 0 and A-1 inclusive in A.
.*urandom8
{
    ; Note that advance_seed_randomise_a corrupts rng_tmp.
    upper_threshold = rng_tmp + 1
    divisor = rng_tmp + 2
    dividend = rng_tmp + 3

    sta divisor

    ; In order to avoid bias if the range of a full byte isn't an exact multiple
    ; of the range of our output, we discard random values >= upper_threshold.
    ; This is a bit wasteful but in this application I think it's acceptable.
    tax:lda upper_threshold_table,x:beq no_threshold:sta upper_threshold
.discard_loop
    jsr advance_seed_randomise_a
    cmp upper_threshold:bcs discard_loop
    bcc a_randomised ; always branch
.no_threshold
    jsr advance_seed_randomise_a
.a_randomised

    ; Now divide A by divisor and take the remainer.
    ; Terminology: dividend/divisor => result, remainder
    sta dividend
    ldx #8
    lda #0 ; working remainder is held in A
.divide_loop
    asl dividend:rol a
    cmp divisor:bcc too_small
    ; C is already set ready for sbc
    sbc divisor
.too_small
    dex:bne divide_loop
    rts
}

; Mix the current system clock into the random seed.
.*update_random_seed
{
    ; Rotate the seed by 8 bits; this will spread the highly-variable low bits
    ; of the system clock across more of the seed over multiple calls to this
    ; subroutine.
    ldx #3
    ldy seed0
.rotate_loop
    lda seed0,x
    sty seed0,x
    tay
    dex
    bpl rotate_loop

    lda #osword_read_system_clock
    ldx #lo(current_time):ldy #hi(current_time)
    jsr osword
    ldx #3
.update_loop
    lda current_time,x
    eor seed0,x
    sta seed0,x
    dex
    bpl update_loop
    rts

.current_time
    skip 5
}

}

    align &100
    include "../res/random-tables.asm"
.upper_threshold_table
    equb 0
    for i, 1, 255
        equb (256 div i)*i and &ff
    next
