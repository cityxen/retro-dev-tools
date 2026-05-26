#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Reusable string buffer
//
// strbuf[256]  — general-purpose byte buffer
// buf_crsr     — cursor index into strbuf
// zero_strbuf  — clear buffer and reset cursor
//////////////////////////////////////////////////////////////////

strbuf:
    .fill 256, 0
buf_crsr:
    .byte 0

// zero_strbuf: fill strbuf with $00 and reset buf_crsr.
zero_strbuf:
    lda #0
    ldx #0
!:
    sta strbuf,x
    inx
    bne !-
    stx buf_crsr
    rts
