include "macros.asm"
include "constants.asm"

    org &70
    guard &90
.led_group_count
    equb 0
.frame_count
    equb 0
.inverse_raster_row
    equb 0
.ptr
    equw 0
.screen_ptr
    equw 0
.working_index
    equb 0
.led_x
    equb 0
.led_y
    equb 0

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

    org &2000
    guard &5800


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

    ; Execution falls through into the code in menu.asm.
    include "menu.asm"
    include "animate.asm"
    include "utilities.asm"

    ; TODO: Might want to tweak how the auto-generation works, have some Python code generate panel_template_list and a count of number of entries and we just do a single "include" which does everything
.panel_template_circle_32
    incbin "../res/circle-32.bin"
.panel_template_rectangle_32
    incbin "../res/rectangle-32.bin"
.panel_template_triangle_32
    incbin "../res/triangle-32.bin"

.panel_template_list
    equw panel_template_circle_32
    equw panel_template_rectangle_32
    equw panel_template_triangle_32

    include "../res/led-shapes.asm"
.led_shape_list ; TODO: Generate this list in led-shapes.asm?
    equw led_shape_0_large, led_shape_0_small
    equw led_shape_1_large, led_shape_1_small
    equw led_shape_2_large, led_shape_2_small
    equw led_shape_3_large, led_shape_3_small
    equw led_shape_4_large, led_shape_4_small

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

\ TODO: Standardise on & vs $ for hex - probably &

; TODO: Do some basic statistical analysis on the LED periods to check they look sane for a few combinations of parameters
