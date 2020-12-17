include "macros.asm"
include "constants.asm"

    org &70
    guard &90
    ; random.asm workspace; some of this could potentially overlap with other
    ; zero page uses if necessary, but for now we're not short on space.
.SEED0
    equb 0
.SEED1
    equb 0
.SEED2
    equb 0
.SEED3
    equb 0
.TMP
    equd 0
.MOD
    equb 0
.REM
    equb 0

    ; Common zero page workspace for other code.
.src
    skip 2
.dest ; TODO: RENAME TO "dst"?
    skip 2
.zp_tmp
    skip 4

    ; The remaining zero page space is carved up into separate overlapping
    ; allocations for the menu and animation code, which communicate via
    ; variables held outside zero page.
.shared_zp_start
shared_zp_end = &90

    org &2000
    guard mode_4_screen

.start
    ; Refuse to run on a second processor. (Because we want to re-enter this
    ; code using CALL on BREAK via *KEY10, we can't just set our load/exec
    ; addresses to force execution in the host.)
    lda #osbyte_read_high_order_address:jsr osbyte
    inx:bne tube
    iny:beq not_tube
.tube
    brk
    equs 0, "Please turn off your second processor!", 0
.not_tube

    ; Set up the BREAK key to re-enter this code. (We don't do this in !BOOT
    ; because that would cause a crash if the user pressed BREAK before this
    ; code has loaded.) We could use *FX247 but that would also trap CTRL-BREAK;
    ; we're not trying to make ourselves unkillable, just taking advantage of
    ; BREAK's hardware reset ability to interrupt the running animation without
    ; us needing to spend CPU cycles checking the keyboard.
    ldx #lo(key10_command)
    ldy #hi(key10_command)
    jsr oscli

    ; See if we're running on a 65C02 or not. By selecting mode 7 now we know we
    ; can use the memory between mode_4_screen and mode_7_screen for our test
    ; code.
    {
        is_cmos = mode_4_screen+&200
        is_nmos = mode_4_screen+&300
        lda #7:jsr set_mode
        lda #opcode_lda_imm:sta is_cmos:lda #1:sta is_cmos+1
        lda #opcode_rts:sta is_nmos:sta is_cmos+2
        assert lo(is_cmos) == lo(is_nmos)
        lda #lo(is_cmos):sta mode_4_screen+&ff
        lda #hi(is_cmos):sta mode_4_screen+&100
        lda #hi(is_nmos):sta mode_4_screen
        lda #0
        jsr jmp_indirect_for_cmos_test
        sta cpu_type
    }

    jmp show_menu

    ; We include animate.asm first so as to minimise the nuisance of code
    ; changes causing branches to cross page boundaries.
    include "animate.asm"
    include "menu.asm"
    include "utilities.asm"
    ; TODO: Probably want to create some more templates - in particular, a smaller rectangle which doesn't struggle so much to hit 50Hz most of the time.
    include "../res/panel-templates.asm"
    include "../res/led-shapes.asm"

.jmp_indirect_for_cmos_test
    ; jmp (mode_4_screen+&ff); we assemble this via directives to stop beebasm
    ; generating an error.
    equb opcode_jmp_indirect
    equw mode_4_screen+&ff

.cpu_type
    equb 0 ; set at runtime to 0 for NMOS, 1 for CMOS

.key10_command
    equs "KEY10 CALL &"
    equ_hex16 start
    equs "|M", 13

    ; random.asm finishes with some page-aligned tables, so we include it last in
    ; order to avoid multiple alignment-induced holes.
    include "random.asm"

.end

    ; Uninitialised data tables which we allocate at assembly time but which don't
    ; need to be saved as part of the binary.
    align &100
.count_table
    skip led_count ; TODO: rename this max_led_count?

    align &100
.period_table
    skip led_count

    align &100
.state_table
    skip led_count

    align &100
.inverse_row_table
    skip led_count

    align &100
.address_low_table
    skip led_count

    align &100
.address_high_table
    skip led_count

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

; TODO: I am currently *maybe* seeing a slight weirdness with some of the LEDs when they first start animating - it's probably fine, but have a look and see if not all are initialised or the fact that some panels don't use *all* the LED slots has some kind of impact - I *think* this was caused by not initialising state_table and count_table every time, so after the first animation the LEDs didn't all start in sync - if so I have now fixed this, will leave this TODO in place for a bit in case there was another cause

\ TODO: Standardise on & vs $ for hex - probably & - done, but keep this TODO around as I'll probably slip up

; TODO: Do some basic statistical analysis on the LED periods to check they look sane for a few combinations of parameters
