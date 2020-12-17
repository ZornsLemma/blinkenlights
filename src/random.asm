{
; Multiplier taken from "Computationally easy, spectrally good multipliers for
; congruential pseudorandom number generators" by Guy Steele and Sebastiano
; Vigna (https://arxiv.org/abs/2001.05304).
a = &fb85 ; TODO: SINCE I'M MULTIPLYING BY TABLE MAY BE NO DOWNSIDE TO USING A LARGER VALUE, LET'S JUST USE THIS WHILE I WRITE THE CODE
c = 1

;SFTODOSTARTEXPERIMENTAL

; Set seed = seed*a + c (mod 2^32).
.advance_seed
{
tmp = TMP ; SFTODO: DO PROPERLY
seed0 = SEED0 ; SFTODO: DO PROPERLY
seed1 = SEED1 ; SFTODO: DO PROPERLY
seed2 = SEED2 ; SFTODO: DO PROPERLY
seed3 = SEED3 ; SFTODO: DO PROPERLY
; a*seed = a*(seed0 + seed1<<8 + seed2<<16 + seed3<<24)
;        = a*seed0 + a*(seed1<<8) + a*(seed2<<16) + a*(seed3<<24)
;        = a*seed0 + (a*seed1)<<8 + (a*seed2)<<16 + (a*seed3)<<24

    clc
    ldx seed0
    ldy seed1
    lda table0,x:adc #c:sta seed0
    lda table1,x:adc table0,y:sta seed1
    lda table2,x:adc table1,y:sta tmp
    lda table3,x:adc table2,y:tay

    clc
    ldx seed2
    lda table0,x:adc tmp:sta seed2
    tya:adc table1,x

    clc
    ldx seed3
    adc table0,x:sta seed3

    rts
}

; Return a uniformly distributed random number between 0 and A-1 inclusive in A.
.*urandom8
{
; TODO PROPER ZP ALLOC
SFTODOUPTHRESH=TMP
result=TMP+1
SFTODO2=TMP+2
SFTODOINPUTA=TMP+3
SFTODO1=MOD
    sta SFTODOINPUTA

    ; We use the MSB of the seed as the basis for the random number. In order to
    ; avoid bias if the range of a full byte isn't an exact multiple of the
    ; range of our output, we discard values which form part of any final
    ; "partial range". This is a bit wasteful. TODO?
if FALSE ; TODO
    tax:lda upper_threshold,x:sta SFTODOUPTHRESH
.discard_loop
    jsr advance_seed
    lda seed3:cmp SFTODOUPTHRESH:bcs discard_loop ; SFTODO NOT THINKING OFF BY ONE YET AS MAY CHANGE HOW INPUT A IS TREATED WRT UPPER BOUND
endif
    lda #%11:sta SFTODOINPUTA ; SFTODOTEMP
    lda #%10110 ; SFTODO TEMP
    lda #67:sta SFTODOINPUTA
    lda #250

    ; Now divide A=seed3 by SFTODOINPUTA and take the remainer.
    ldx #0:stx result:stx SFTODO2
    sta SFTODO1
    ldx #8
.divide_loop
    asl SFTODO1:rol SFTODO2
    lda SFTODO2:cmp SFTODOINPUTA:bcc too_small
    sec ; SFTODO REDUNDANT BUT CLARITY FOR NOW
    sbc SFTODOINPUTA:sta SFTODO2
    sec ; SFTODO: REDUNDANT?
.too_small
    rol result
    dex:bne divide_loop
    lda SFTODO2
    rts
}



macro make_table_SFTODO n
    for i, 0, 255
        equb ((a * i) >> n) and &ff
    next
endmacro

    ; TODO: RENAME THESE TABLES TO CONVEY "MULT_BY_A"NESS?
    align &100
.table0
    make_table_SFTODO 0
.table1
    make_table_SFTODO 8
.table2
    make_table_SFTODO 16
.table3
    make_table_SFTODO 24


; TODO: OLD BELOW HERE

; This is Bruce Clark's code from
; http://6502.org/source/integers/random/random.html, just tweaked to assemble
; with beebasm.

; Linear congruential pseudo-random number generator
;
; Calculate SEED = 1664525 * SEED + 1
;
; Enter with:
;
;   SEED0 = byte 0 of seed
;   SEED1 = byte 1 of seed
;   SEED2 = byte 2 of seed
;   SEED3 = byte 3 of seed
;
; Returns:
;
;   SEED0 = byte 0 of seed
;   SEED1 = byte 1 of seed
;   SEED2 = byte 2 of seed
;   SEED3 = byte 3 of seed
;
; TMP is overwritten
;
; For maximum speed, locate each table on a page boundary
;
; Assuming that (a) SEED0 to SEED3 and TMP are located on page zero, and (b)
; all four tables start on a page boundary:
;
;   Space: 58 bytes for the routine
;          1024 bytes for the tables
;   Speed: JSR RAND takes 94 cycles
;
.RAND    CLC       ; compute lower 32 bits of:
         LDX SEED0 ; 1664525 * ($100 * SEED1 + SEED0) + 1
         LDY SEED1
         LDA T0,X
         ADC #1
         STA SEED0
         LDA T1,X
         ADC T0,Y
         STA SEED1
         LDA T2,X
         ADC T1,Y
         STA TMP
         LDA T3,X
         ADC T2,Y
         TAY       ; keep byte 3 in Y for now (for speed)
         CLC       ; add lower 32 bits of:
         LDX SEED2 ; 1664525 * ($10000 * SEED2)
         LDA TMP
         ADC T0,X
         STA SEED2
         TYA
         ADC T1,X
         CLC
         LDX SEED3 ; add lower 32 bits of:
         ADC T0,X  ; 1664525 * ($1000000 * SEED3)
         STA SEED3
         RTS
;
; Generate T0, T1, T2 and T3 tables
;
; A different multiplier can be used by simply replacing the four bytes
; that are commented below
;
; To speed this routine up (which will make the routine one byte longer):
; 1. Delete the first INX instruction
; 2. Replace LDA Tn-1,X with LDA Tn,X (n = 0 to 3)
; 3. Replace STA Tn,X with STA Tn+1,X (n = 0 to 3)
; 4. Insert CPX #$FF between the INX and BNE GT1
;
.GENTBLS LDX #0      ; 1664525 * 0 = 0
         STX T0
         STX T1
         STX T2
         STX T3
         INX
         CLC
.GT1     LDA T0-1,X  ; add 1664525 to previous entry to get next entry
         ADC #$0D    ; byte 0 of multiplier
         STA T0,X
         LDA T1-1,X
         ADC #$66    ; byte 1 of multiplier
         STA T1,X
         LDA T2-1,X
         ADC #$19    ; byte 2 of multiplier
         STA T2,X
         LDA T3-1,X
         ADC #$00    ; byte 3 of multiplier
         STA T3,X
         INX         ; note: carry will be clear here
         BNE GT1
         RTS

; Linear congruential pseudo-random number generator
;
; Get the next SEED and obtain an 8-bit uniform random number from it
;
; Requires the RAND subroutine
;
; Enter with:
;
;   accumulator = modulus
;
; Exit with:
;
;   accumulator = random number, 0 <= accumulator < modulus
;
; MOD, REM, TMP, TMP+1, TMP+2, and TMP+3 are overwritten
;
; Note that TMP to TMP+3 are only used after RAND is called.
;
.*urandom8_SFTODOOLD
         STA MOD   ; store modulus in MOD
         LDX #32   ; calculate remainder of 2^32 / MOD
         LDA #1
         BNE UR8B
.UR8A    ASL A     ; shift dividend left
         BCS UR8C  ; branch if a one was shifted out
.UR8B    CMP MOD
         BCC UR8D  ; branch if partial dividend < MOD
.UR8C    SBC MOD   ; subtract MOD from partial dividend
.UR8D    DEX
         BPL UR8A
         STA REM   ; store remainder in REM
.UR8E    JSR RAND
         LDA #0    ; multiply SEED by MOD
         STA TMP+3
         STA TMP+2
         STA TMP+1
         STA TMP
         LDY MOD   ; save MOD in Y
         SEC
         ROR MOD   ; shift out modulus, shifting in a 1 (will loop 8 times)
.UR8F    BCC UR8G  ; branch if a zero was shifted out
         CLC       ; add SEED to TMP
         TAX
         LDA TMP
         ADC SEED0
         STA TMP
         LDA TMP+1
         ADC SEED1
         STA TMP+1
         LDA TMP+2
         ADC SEED2
         STA TMP+2
         LDA TMP+3
         ADC SEED3
         STA TMP+3
         TXA
.UR8G    ROR TMP+3 ; shift product right
         ROR TMP+2
         ROR TMP+1
         ROR TMP
         ROR A
         LSR MOD   ; loop until all 8 bits of MOD have been shifted out
         BNE UR8F
         CLC       ; add remainder to product
         ADC REM
         BCC UR8H  ; branch if no 8-bit carry
         INC TMP   ; carry a one to byte 1 of product
         BNE UR8H  ; branch if no 16-bit carry
         INC TMP+1 ; carry a one to byte 2 of product
         BNE UR8H  ; branch if no 24-bit carry
         INC TMP+2 ; carry a one to byte 3 of product
         STY MOD   ; restore MOD (does not affect Z flag!)
         BEQ UR8E  ; branch if 32-bit carry
.UR8H    LDA TMP+3 ; return upper 8 bits of product in accumulator
         RTS

; The following subroutine is new and not taken from 6502.org.
; Mix the current system clock into the random seed.
.*update_random_seed
{
    ; Rotate the seed by 8 bits; this will spread the highly-variable low bits
    ; of the system clock across more of the seed over multiple calls to this
    ; subroutine.
    ldx #3
    ldy SEED0
.rotate_loop
    lda SEED0,x
    sty SEED0,x
    tay
    dex
    bpl rotate_loop

    lda #osword_read_system_clock
    ldx #lo(current_time):ldy #hi(current_time)
    jsr osword
    ldx #3
.update_loop
    lda current_time,x
    eor SEED0,x
    sta SEED0,x
    dex
    bpl update_loop
    rts

.current_time
    skip 5
}

         ; TODO: MAY WANT TO FACTOR THE TABLES OUT INTO THEIR OWN FILES SO WE CAN ARRANGE THE TABLES INTO THE ALREADY-PAGE-ALIGNED BIT WITH MY OWN TABLES, SO WE DON'T HAVE TWO ALIGNMENT-INDUCED HOLES
macro make_table n
    for x, 0, 255
        equb ((1664525 * x) >> (n * 8)) and &ff
    next
endmacro

    align &100
.T0
    make_table 0
.T1
    make_table 1
.T2
    make_table 2
.T3
    make_table 3

}
