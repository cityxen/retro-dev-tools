//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — String buffer
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// strbuf: 256-byte general-purpose string workspace.
// zero_strbuf: fill with zeroes.
//////////////////////////////////////////////////////////////////

#importonce

strbuf: .fill 256, 0

zero_strbuf:
    ldx #$ff
    lda #$00
!:
    sta strbuf,x
    dex
    bne !-
    sta strbuf      // index 0
    rts
