#importonce
//===========================================================================
// CityXen Apple IIe Library - BCD Score Management
//
// Score stored as 5 BCD bytes = up to 9,999,999,999 points.
// BCD arithmetic uses the 65C02 decimal mode (SED/CLD instructions).
// score_str holds a null-terminated 10-digit ASCII string for display.
//===========================================================================

score:      .fill 5, 0          // 5 BCD bytes (10 digits, lo-digit in byte 0)
score_str:  .fill 11, $30       // ASCII digits + null ($30 = '0')
            .byte 0             // null terminator

//---------------------------------------------------------------------------
// score_reset - Zero the score
//---------------------------------------------------------------------------
score_reset:
    ldx #4
sr_loop:
    stz score, x
    dex
    bpl sr_loop
    jsr score_to_str
    rts

//---------------------------------------------------------------------------
// score_to_str - Convert BCD score to 10-digit ASCII string in score_str
//---------------------------------------------------------------------------
score_to_str:
    ldx #0          // output index into score_str (0..9)
    ldy #4          // BCD byte index (high byte first)
sts_byte:
    lda score, y
    // High nibble
    lsr
    lsr
    lsr
    lsr
    ora #$30        // to ASCII
    sta score_str, x
    inx
    // Low nibble
    lda score, y
    and #$0F
    ora #$30
    sta score_str, x
    inx
    dey
    bpl sts_byte
    stz score_str + 10  // null terminate
    rts

//---------------------------------------------------------------------------
// score_from_str - Parse 10 ASCII digit string in score_str into score[]
//---------------------------------------------------------------------------
score_from_str:
    ldx #0
    ldy #4
sfs_byte:
    // High nibble from score_str[x]
    lda score_str, x
    and #$0F
    asl
    asl
    asl
    asl
    sta ZP_TMP0
    inx
    // Low nibble from score_str[x]
    lda score_str, x
    and #$0F
    ora ZP_TMP0
    sta score, y
    inx
    dey
    bpl sfs_byte
    rts

//---------------------------------------------------------------------------
// score_add - Add a BCD value to score
//   On entry: ZP_TMP0 = amount (BCD, 1 byte, e.g. $10 = add 10 points)
//   For larger additions, extend as needed.
//---------------------------------------------------------------------------
score_add:
    sed                 // decimal (BCD) mode
    clc
    lda score
    adc ZP_TMP0
    sta score
    ldx #1
sa_carry:
    lda score, x
    adc #0
    sta score, x
    inx
    cpx #5
    bne sa_carry
    cld
    jsr score_to_str
    rts

//---------------------------------------------------------------------------
// score_sub - Subtract BCD value from score (clamp at zero)
//   On entry: ZP_TMP0 = amount (BCD, 1 byte)
//---------------------------------------------------------------------------
score_sub:
    jsr is_score_zero
    bne ss_ok
    rts             // already zero, don't underflow
ss_ok:
    sed
    sec
    lda score
    sbc ZP_TMP0
    sta score
    ldx #1
ss_borrow:
    lda score, x
    sbc #0
    sta score, x
    inx
    cpx #5
    bne ss_borrow
    cld
    // Clamp at zero if underflowed (check high bit of score[4])
    lda score + 4
    bpl ss_done
    // Underflowed: zero the score
    jsr score_reset
ss_done:
    jsr score_to_str
    rts

//---------------------------------------------------------------------------
// is_score_zero - Return A=0 if score is zero, A=non-zero otherwise
//---------------------------------------------------------------------------
is_score_zero:
    lda score
    ora score + 1
    ora score + 2
    ora score + 3
    ora score + 4
    rts

//---------------------------------------------------------------------------
// DrawScore - Print score string at (col, row) on text screen
//   Usage: DrawScore(col, row)
//   Prints score_str (10 digits) using Monitor COUT via il_print_score
//---------------------------------------------------------------------------
.macro DrawScore(col, row) {
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC
    jsr il_print_score
}

il_print_score:
    ldy #0
ips_loop:
    lda score_str, y
    beq ips_done
    ora #CHR_NORMAL     // set high bit for Monitor COUT
    jsr COUT
    iny
    cpy #10
    bne ips_loop
ips_done:
    rts

//===========================================================================
