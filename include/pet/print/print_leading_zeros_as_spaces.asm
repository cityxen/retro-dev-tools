//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print Leading Zeros as Spaces
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

.macro PrintLeadingZerosAsSpaces(text) {
    lda #<text
    sta zp_tmp_lo
    lda #>text
    sta zp_tmp_hi
    jsr print_leading_zeros_as_spaces
}

print_leading_zeros_as_spaces:
    clc
    lda #$00
    sta zpnzp_c

plzs_next:
    ldy #$00
    lda (zp_tmp), y
    bne plzs_char
    lda zpnzp_c
    bne plzs_out
    lda #$30
    jsr KERNAL_CHROUT
plzs_out:
    rts

plzs_char:
    tax
    cpx #$30
    bne plzs_nonzero
    iny
    clc
    lda (zp_tmp), y
    beq plzs_nonzero    // last char, print even if zero
    lda zpnzp_c
    bne plzs_nonzero
    lda #$20            // space instead of leading zero
    jsr KERNAL_CHROUT
    jmp plzs_advance

plzs_nonzero:
    txa
    jsr KERNAL_CHROUT
    inc zpnzp_c

plzs_advance:
    inc zp_tmp_lo
    bne plzs_next
    inc zp_tmp_hi
    jmp plzs_next

zpnzp_c: .byte 0
