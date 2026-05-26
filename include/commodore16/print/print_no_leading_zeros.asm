//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Print without leading zeros
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// print_no_leading_zeros: print a digit string, suppressing leading '0' chars.
// If all digits are '0', prints a single '0'.
// zp_tmp_lo/hi → null-terminated digit string.
//
// PrintNoLeadingZeros(text) macro sets zp_tmp and JSRs.
//////////////////////////////////////////////////////////////////

#importonce

.macro PrintNoLeadingZeros(text) {
    lda #< text
    sta zp_tmp_lo
    lda #> text
    sta zp_tmp_hi
    jsr print_no_leading_zeros
}

print_no_leading_zeros:
    clc
    lda #$00
    sta zpnzp_c

nzp1:
!wl:
    ldy #$00
    lda (zp_tmp),y
    bne !wl+
    lda zpnzp_c
    bne !+
    lda #$30
    jsr $ffd2
!:
    rts
!wl:
    tax
    cpx #$30
    bne wlz

    iny
    clc
    lda (zp_tmp),y
    beq wlz

    lda zpnzp_c
    bne wlz
    jmp wlyz

wlz:
    txa
    jsr $ffd2
    inc zpnzp_c
wlyz:
    inc zp_tmp_lo
    bne !+
    inc zp_tmp_hi
!:
    jmp nzp1

zpnzp_c: .byte 0
