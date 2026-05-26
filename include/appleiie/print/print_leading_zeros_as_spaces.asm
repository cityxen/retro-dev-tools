#importonce
//===========================================================================
// CityXen Apple IIe Library - Print Number With Leading Zeros as Spaces
//
// Like il_print_decimal but replaces leading zeros with spaces,
// producing a right-aligned number in a fixed-width field.
//===========================================================================

// Divisor table reference (defined in print_dec.asm)
// dec_divisors_hi / dec_divisors_lo

//---------------------------------------------------------------------------
// il_print_lz_spaces - Print 16-bit value; leading zeros shown as spaces
//   A = lo byte, X = hi byte
//---------------------------------------------------------------------------
il_print_lz_spaces:
    sta ZP_A
    stx ZP_A + 1
    stz ZP_TMP0         // "started" flag

    ldy #0
plzs_digit:
    lda dec_divisors_lo, y
    sta ZP_B
    lda dec_divisors_hi, y
    sta ZP_B + 1

    lda #0
    sta ZP_C

plzs_sub:
    lda ZP_A + 1
    cmp ZP_B + 1
    bcc plzs_emit
    bne plzs_do_sub
    lda ZP_A
    cmp ZP_B
    bcc plzs_emit
plzs_do_sub:
    sec
    lda ZP_A
    sbc ZP_B
    sta ZP_A
    lda ZP_A + 1
    sbc ZP_B + 1
    sta ZP_A + 1
    inc ZP_C
    bra plzs_sub

plzs_emit:
    lda ZP_C
    bne plzs_print
    lda ZP_TMP0
    bne plzs_print
    // Print space for leading zero
    lda #$A0            // space | $80
    jsr COUT
    bra plzs_next

plzs_print:
    lda ZP_C
    ora #$B0            // ASCII digit | $80
    jsr COUT
    lda #$FF
    sta ZP_TMP0

plzs_next:
    iny
    cpy #5
    bne plzs_digit

    lda ZP_TMP0
    bne plzs_done
    lda #$B0            // lone "0"
    jsr COUT
plzs_done:
    rts

//===========================================================================
