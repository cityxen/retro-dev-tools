//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

.const PETMATE_PTR = $FB

.const SRC0 = $02
.const SRC1 = $04
.const SRC2 = $06
.const SRC3 = $08
.const SRC4 = $0A
.const SRC5 = $0C
.const SRC6 = $0E
.const SRC7 = $10

.macro DrawPetMateScreen(screen_name) {
    lda #<screen_name
    sta PETMATE_PTR
    lda #>screen_name
    sta PETMATE_PTR+1
    jsr draw_petmate_screen
}

draw_petmate_screen:
    ldy #$00

    lda (PETMATE_PTR),y
    sta BORDER_COLOR

    iny
    lda (PETMATE_PTR),y
    sta BACKGROUND_COLOR

    // screen_name + 2
    lda PETMATE_PTR
    clc
    adc #<2
    sta SRC0
    lda PETMATE_PTR+1
    adc #>2
    sta SRC0+1

    // screen_name + 258
    lda PETMATE_PTR
    clc
    adc #<258
    sta SRC1
    lda PETMATE_PTR+1
    adc #>258
    sta SRC1+1

    // screen_name + 514
    lda PETMATE_PTR
    clc
    adc #<514
    sta SRC2
    lda PETMATE_PTR+1
    adc #>514
    sta SRC2+1

    // screen_name + 1002
    lda PETMATE_PTR
    clc
    adc #<1002
    sta SRC3
    lda PETMATE_PTR+1
    adc #>1002
    sta SRC3+1

    // screen_name + 1258
    lda PETMATE_PTR
    clc
    adc #<1258
    sta SRC4
    lda PETMATE_PTR+1
    adc #>1258
    sta SRC4+1

    // screen_name + 1514
    lda PETMATE_PTR
    clc
    adc #<1514
    sta SRC5
    lda PETMATE_PTR+1
    adc #>1514
    sta SRC5+1

    // screen_name + 770
    lda PETMATE_PTR
    clc
    adc #<770
    sta SRC6
    lda PETMATE_PTR+1
    adc #>770
    sta SRC6+1

    // screen_name + 1770
    lda PETMATE_PTR
    clc
    adc #<1770
    sta SRC7
    lda PETMATE_PTR+1
    adc #>1770
    sta SRC7+1

    ldy #$00

dpms_loop:
    lda (SRC0),y
    sta 1024,y

    lda (SRC1),y
    sta 1024+256,y

    lda (SRC2),y
    sta 1024+512,y

    lda (SRC3),y
    sta COLOR_RAM,y

    lda (SRC4),y
    sta COLOR_RAM+256,y

    lda (SRC5),y
    sta COLOR_RAM+512,y

    iny
    bne dpms_loop

    ldy #232

dpms_loop2:
    dey

    lda (SRC6),y
    sta 1024+512+256,y

    lda (SRC7),y
    sta COLOR_RAM+512+256,y

    cpy #$00
    bne dpms_loop2

    rts
