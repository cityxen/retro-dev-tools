//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

.macro InitializeMusic(music_option) {
    lda #$01
    sta music_option
    ldx #0
    ldy #0
    lda #00
    jsr music.init
    lda #$7F
    sta $DC0D
    lda $DC0D
    sei
    lda #$01
    sta VIC_INTERRUPT_ENABLE
    lda #$44
    sta VIC_RASTER_COUNTER
    lda $D011
    and #$7F
    sta $D011
    lda #<irq1
    sta $0314
    lda #>irq1
    sta $0315
    cli
}
