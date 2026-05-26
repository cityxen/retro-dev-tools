#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Print with leading zeros as spaces
//
// print_leading_zeros_as_spaces:
//   Write $FF-terminated Atari screen-code string from (ZP_PTR_LO)
//   to (ZP_PCUR_LO).  Replaces leading SC('0')=$10 bytes with
//   spaces (screen code 0); always prints the final digit.
//
// PrintLeadingZerosAsSpaces(str)  — macro: set ZP_PTR, JSR
//////////////////////////////////////////////////////////////////

.macro PrintLeadingZerosAsSpaces(str) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    jsr print_leading_zeros_as_spaces
}

plzs_c: .byte 0

print_leading_zeros_as_spaces:
    lda #0
    sta plzs_c

plzs_top:
    ldy #0
    lda (ZP_PTR_LO),y
    cmp #$FF
    bne plzs_not_end
    lda plzs_c
    bne plzs_done
    lda #SC('0')            // all-zero string → print one '0'
    jsr print_char
plzs_done:
    rts

plzs_not_end:
    tax
    cpx #SC('0')
    bne plzs_write

    iny
    lda (ZP_PTR_LO),y
    cmp #$FF
    beq plzs_write_x        // last digit → print '0' literally

    lda plzs_c
    bne plzs_write_x        // past leading zeros → print '0' literally

    // Leading zero → print a space and advance
    lda #0                  // screen code 0 = space
    jsr print_char
    jmp plzs_adv

plzs_write_x:
    txa
plzs_write:
    jsr print_char
    inc plzs_c

plzs_adv:
    inc ZP_PTR_LO
    bne plzs_top
    inc ZP_PTR_HI
    jmp plzs_top
