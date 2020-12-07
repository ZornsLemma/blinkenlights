{
    lda #7:jsr set_mode
    ; TODO: Wait for vsync?
    {
        ldx #0
    .loop
        lda menu_template     ,x:sta mode_7_screen     ,x
        lda menu_template+&100,x:sta mode_7_screen+&100,x
        lda menu_template+&200,x:sta mode_7_screen+&200,x
        lda menu_template+&300,x:sta mode_7_screen+&300,x
        inx
        bne loop
    }

.TODO
    jmp TODO

.menu_template
    incbin "../res/menu-template.bin"
}
