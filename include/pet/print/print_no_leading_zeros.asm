//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print No Leading Zeros
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

.macro PrintNoLeadingZeros(text) {
    lda #<text
    sta zp_tmp_lo
    lda #>text
    sta zp_tmp_hi
    jsr print_no_leading_zeros
}

print_no_leading_zeros:
    clc
    lda #$00
    sta zpnzp_c

pnlz_next:
    ldy #$00
    lda (zp_tmp), y
    bne pnlz_char
    lda zpnzp_c
    bne pnlz_out
    lda #$30
    jsr KERNAL_CHROUT
pnlz_out:
    rts

pnlz_char:
    tax
    cpx #$30
    bne pnlz_nonzero
    iny
    clc
    lda (zp_tmp), y
    beq pnlz_nonzero    // last char, print even if zero
    lda zpnzp_c
    bne pnlz_nonzero
    jmp pnlz_advance    // skip leading zero

pnlz_nonzero:
    txa
    jsr KERNAL_CHROUT
    inc zpnzp_c

pnlz_advance:
    inc zp_tmp_lo
    bne pnlz_next
    inc zp_tmp_hi
    jmp pnlz_next
