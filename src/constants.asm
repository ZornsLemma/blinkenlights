vdu_set_palette = 19
vdu_set_mode = 22

colour_red = 1
colour_white = 7

mode_4_screen = &5800
mode_4_width = 40
mode_4_height = 32
mode_4_char_lines = 8

mode_7_screen = &7c00
mode_7_width = 40
mode_7_graphics_colour_base = 144

panel_width = 40
panel_height = 32
led_count = panel_width*panel_height

osbyte_wait_for_vsync = &13
osbyte_flush_buffer = &15
osbyte_read_key = &81
osbyte_read_high_order_address = &82

osword_read_system_clock = &01

buffer_keyboard = 0

keyboard_1 = -49
keyboard_2 = -50
keyboard_3 = -18
keyboard_4 = -19
keyboard_5 = -20
keyboard_6 = -53
keyboard_7 = -37
keyboard_8 = -22
keyboard_9 = -39
keyboard_0 = -40
keyboard_shift = -1
keyboard_space = -99

osrdch = &ffe0
oswrch = &ffee
osword = &fff1
osbyte = &fff4
oscli  = &fff7

opcode_rts = &60
opcode_jmp_indirect = &6c
opcode_dey = &88
opcode_ldy_imm = &a0
opcode_tay = &a8
opcode_lda_imm = &a9
opcode_sta_zp_ind_y = &91
opcode_sta_zp_ind = &92
opcode_iny = &c8
opcode_bne = &d0
opcode_inx = &e8
opcode_beq = &f0
