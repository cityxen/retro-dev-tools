#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Print without leading zeros
//
// print_no_leading_zeros:
//   Write $FF-terminated Atari screen-code string from (ZP_PTR_LO)
//   to (ZP_PCUR_LO).  Skips leading SC('0')=$10 bytes; always
//   prints at least one digit.
//
// PrintNoLeadingZeros(str)  — macro: set ZP_PTR, JSR
//////////////////////////////////////////////////////////////////

.macro PrintNoLeadingZeros(str) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    jsr print_no_leading_zeros
}

pnlz_c: .byte 0   // 0 = still in leading zeros; nonzero = printing

print_no_leading_zeros:
    lda #0
    sta pnlz_c

pnlz_top:
    ldy #0
    lda (ZP_PTR_LO),y
    cmp #$FF                // end of string?
    bne pnlz_not_end
    lda pnlz_c
    bne pnlz_done
    lda #SC('0')            // string was all zeros — print one '0'
    jsr print_char
pnlz_done:
    rts

pnlz_not_end:
    tax                     // save char in X
    cpx #SC('0')            // is it SC('0') = $10?
    bne pnlz_write          // no → always print

    // It's a leading-zero candidate.  Check if next char is the terminator.
    iny
    lda (ZP_PTR_LO),y
    cmp #$FF
    beq pnlz_write_x        // last digit — must print even if '0'

    lda pnlz_c
    bne pnlz_write_x        // already printing → print this '0' too

    // Leading zero before more digits → skip, advance, loop.
    jmp pnlz_adv

pnlz_write_x:
    txa                     // restore char from X
pnlz_write:
    jsr print_char
    inc pnlz_c

pnlz_adv:
    inc ZP_PTR_LO
    bne pnlz_top
    inc ZP_PTR_HI
    jmp pnlz_top
