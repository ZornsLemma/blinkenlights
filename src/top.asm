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
    ; zero page users if necessary, but for now we don't need to do this.
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

    panel_width = 40
    panel_height = 32
    led_count = panel_width*panel_height
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

    panel_template_top_left_x = 19
    panel_template_top_left_y = 9

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

include "menu.asm"

\ TODO: Standardise on & vs $ for hex - probably &

include "animate.asm"
include "utilities.asm"
include "random.asm"
     

    \ TODO: Eventually probably want to have a BASIC loader which generates a different
    \ random set of frequencies each time.
    randomize 42

    ; TODO: ALL OF THESE TABLES CAN BE MOVED AFTER ".end" AND THEREFORE WON'T TAKE UP SPACE ON DISC OR TAKE TIME TO LOAD FROM DISC - BUT AM WAITING UNTIL I PROGRAMATICALLY POPULATE period_table BEFORE MAKING THIS CHANGE
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

; TODO DELETE .panel_template ; TODO: THIS LABEL IS PROB TEMP NOW, UNTIL I REWORK THE ANIM CODE
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

.end

    puttext "boot.txt", "!BOOT", 0
    save "BLINKEN", start, end

; TODO: I am currently *maybe* seeing a slight weirdness with some of the LEDs when they first start animating - it's probably fine, but have a look and see if not all are initialised or the fact that some panels don't use *all* the LED slots has some kind of impact - I *think* this was caused by not initialising state_table and count_table every time, so after the first animation the LEDs didn't all start in sync - if so I have now fixed this, will leave this TODO in place for a bit in case there was another cause
