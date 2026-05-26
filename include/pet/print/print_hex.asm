//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print Hex
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

//////////////////////////////////////////////////////////////////////////////////////
// PrintHex() — print the value in A as 2 hex digits at current cursor

.macro PrintHex() {
    jsr print_hex_inline
}

.macro PrintHexXY(x, y) {
    sta a_reg
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
    lda a_reg
    jsr print_hex_inline
}

//////////////////////////////////////////////////////////////////////////////////////
// print_hex_inline — print A as two uppercase hex digits via KERNAL_CHROUT

print_hex_inline:
    sta zp_tmp

    lsr
    lsr
    lsr
    lsr
    tax
    lda phx_table, x
    jsr KERNAL_CHROUT

    lda zp_tmp
    and #$0f
    tax
    lda phx_table, x
    jsr KERNAL_CHROUT
    rts

phx_table:
    .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46

//////////////////////////////////////////////////////////////////////////////////////
// print_hex — alternate 2-nibble routine

print_hex:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr phx_digit
    pla
    and #$0f
    jsr phx_digit
    rts

phx_digit:
    cmp #10
    bcc phx_ascii
    adc #6
phx_ascii:
    adc #48
    jsr KERNAL_CHROUT
    rts
