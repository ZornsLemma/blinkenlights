; This is Bruce Clark's code from
; http://6502.org/source/integers/random/random.html, just tweaked to assemble
; with beebasm.

{
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
.*URANDOM8
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
