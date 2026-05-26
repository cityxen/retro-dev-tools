//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — String buffer
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// 256-byte reusable string buffer with zero routine.
//////////////////////////////////////////////////////////////////

#importonce

strbuf:
    .fill 256,0
buf_crsr:
    .byte 0

zero_strbuf:
    lda #$00
    ldx #$00
!:
    sta strbuf,x
    inx
    bne !-
    stx buf_crsr
    rts
