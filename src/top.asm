include "macros.asm"
include "constants.asm"

    org &70
    shared_zp_end = &90
    guard shared_zp_end

    ; RNG seed
.seed0
    skip 1
.seed1
    skip 1
.seed2
    skip 1
.seed3
    skip 1
    ; RNG temporary workspace. We're not short of space in zero page and by
    ; assigning permanent workspace to the RNG we don't have to worry about
    ; corrupting other values when we call it.
.rng_tmp
    skip 4

    ; Common zero page workspace
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

    ; Refuse to run on an Electron; a port would probably be possible (ideally
    ; using sideways RAM so the code can execute while the screen is being
    ; output to the CRT), but this version won't work as it uses the VIAs.
    lda #osbyte_read_host:ldx #1:jsr osbyte
    txa:bne not_electron
    brk
    equs 0, "Sorry, not Electron compatible.", 0
.not_electron

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
    ; changes causing performance-critical branches to cross page boundaries.
    include "animate.asm"
    include "menu.asm"
    include "utilities.asm"
    ; TODO: Probably want to create some more templates - in particular, a smaller rectangle which doesn't struggle so much to hit 50Hz most of the time.
    include "../tmp/panel-templates.asm"
    include "../tmp/led-shapes.asm"

.jmp_indirect_for_cmos_test
    ; jmp (mode_4_screen+&ff); we assemble this via directives to stop beebasm
    ; generating an error.
    assert lo(mode_4_screen) == 0
    equb opcode_jmp_indirect:equw mode_4_screen+&ff

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
    skip max_led_count

    align &100
.period_table
    skip max_led_count

    align &100
.state_table
    skip max_led_count

    align &100
.inverse_row_table
    skip max_led_count

    align &100
.address_low_table
    skip max_led_count

    align &100
.address_high_table
    skip max_led_count

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

; TODO: Do some basic statistical analysis on the LED periods to check they look sane for a few combinations of parameters
