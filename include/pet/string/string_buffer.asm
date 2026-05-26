//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// String Buffer
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// Reusable general-purpose string buffer
string_buffer:
    .fill 256, 0
buf_crsr:
    .byte 0

// zero_strbuf — clear string_buffer to all zeros
zero_strbuf:
    lda #$00
    ldx #$00
zsb_loop:
    sta string_buffer, x
    inx
    bne zsb_loop
    stx buf_crsr
    rts
