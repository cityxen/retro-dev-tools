//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Print with leading zeros as spaces
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// print_leading_zeros_as_spaces: print digit string, replacing leading
// '0' chars with spaces (useful for score/counter display).
// zp_tmp_lo/hi → null-terminated digit string.
//
// PrintLeadingZerosAsSpaces(text) macro sets zp_tmp and JSRs.
//////////////////////////////////////////////////////////////////

#importonce

.macro PrintLeadingZerosAsSpaces(text) {
    lda #< text
    sta zp_tmp_lo
    lda #> text
    sta zp_tmp_hi
    jsr print_leading_zeros_as_spaces
}

print_leading_zeros_as_spaces:
    clc
    lda #$00
    sta zpnzsp_c

nzsp1:
!wl:
    ldy #$00
    lda (zp_tmp),y
    bne !wl+
    lda zpnzsp_c
    bne !+
    lda #$30
    jsr $ffd2
!:
    rts
!wl:
    tax
    cpx #$30
    bne wlsz

    iny
    clc
    lda (zp_tmp),y
    beq wlsz

    lda zpnzsp_c
    bne wlsz
    lda #$20
    jsr $ffd2
    jmp wlysz

wlsz:
    txa
    jsr $ffd2
    inc zpnzsp_c
wlysz:
    inc zp_tmp_lo
    bne !+
    inc zp_tmp_hi
!:
    jmp nzsp1

zpnzsp_c: .byte 0
