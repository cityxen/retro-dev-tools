#importonce
//===========================================================================
// CityXen Apple IIe Library - Decimal Printing
//
// Prints 16-bit unsigned integer (0-65535) without leading zeros.
//===========================================================================

// Divisor table: 10000, 1000, 100, 10, 1
dec_divisors_hi: .byte >10000, >1000, >100, >10, >1
dec_divisors_lo: .byte <10000, <1000, <100, <10, <1

//---------------------------------------------------------------------------
// PrintDecimal - Print 16-bit value in A (lo) / X (hi) as decimal
//   No leading zeros (blank-suppressed).
// Usage: load lo byte into A, hi byte into X, then PrintDecimal()
//---------------------------------------------------------------------------
.macro PrintDecimal() {
    jsr il_print_decimal
}

il_print_decimal:
    sta ZP_A            // lo byte of value
    stx ZP_A + 1        // hi byte of value
    stz ZP_TMP0         // "started" flag (suppress leading zeros)

    ldy #0              // divisor index
ipd_digit:
    lda dec_divisors_lo, y
    sta ZP_B
    lda dec_divisors_hi, y
    sta ZP_B + 1

    // Count how many times divisor fits into ZP_A
    lda #0
    sta ZP_C            // digit count
ipd_sub:
    // if ZP_A < ZP_B, done
    lda ZP_A + 1
    cmp ZP_B + 1
    bcc ipd_emit
    bne ipd_do_sub
    lda ZP_A
    cmp ZP_B
    bcc ipd_emit
ipd_do_sub:
    sec
    lda ZP_A
    sbc ZP_B
    sta ZP_A
    lda ZP_A + 1
    sbc ZP_B + 1
    sta ZP_A + 1
    inc ZP_C
    bra ipd_sub

ipd_emit:
    lda ZP_C
    bne ipd_print      // always print non-zero digit
    lda ZP_TMP0
    beq ipd_next       // suppress leading zero

ipd_print:
    lda ZP_C
    ora #$30 | CHR_NORMAL  // ASCII digit with high bit
    jsr COUT
    lda #$FF
    sta ZP_TMP0         // "started" = true after first non-zero

ipd_next:
    iny
    cpy #5
    bne ipd_digit

    // If value was 0, print single "0"
    lda ZP_TMP0
    bne ipd_done
    lda #$B0            // '0' | $80
    jsr COUT
ipd_done:
    rts

//===========================================================================
