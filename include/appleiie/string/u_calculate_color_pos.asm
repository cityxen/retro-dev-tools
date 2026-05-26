#importonce
//===========================================================================
// CityXen Apple IIe Library - Calculate Lo-Res Color Address
//
// The Apple IIe has no separate color RAM (unlike the C64's $D800).
// In lo-res graphics mode, color is embedded directly in the character/
// graphics byte written to the text page ($0400-$07FF).
//
// Lo-res "blocks" are 2 rows of color per byte:
//   - Low nibble = top block color (even pixel row)
//   - High nibble = bottom block color (odd pixel row)
// Each byte covers one column in one pair of lo-res rows.
// Lo-res grid: 40 columns x 48 rows (24 text-row bytes * 2 blocks each)
//
// The lo-res address is the same as the text screen address for that row.
// Use il_calc_screen_pos with row = lores_row >> 1.
//===========================================================================

//---------------------------------------------------------------------------
// il_calc_lores_pos - Calculate lo-res block address for (col, lores_row)
//   On entry: A = column (0-39), X = lo-res row (0-47)
//   On exit:  ZP_PTR0 = byte address, ZP_TMP1 = nibble flag
//             (ZP_TMP1 = 0: write to low nibble; $FF: write to high nibble)
//   Trashes: A, X, ZP_TMP0, ZP_TMP1
//---------------------------------------------------------------------------
il_calc_lores_pos:
    sta ZP_TMP0         // save column
    // Determine which nibble (even lo-res row = low nibble, odd = high)
    txa
    lsr                 // X >> 1 = text row; carry = nibble flag
    tax                 // X = text row (0-23)
    lda #0
    bcc clp_low
    lda #$FF
clp_low:
    sta ZP_TMP1         // nibble selector

    lda ZP_TMP0         // restore column to A
    // Now call il_calc_screen_pos(col=A, row=X)
    jsr il_calc_screen_pos
    rts

//---------------------------------------------------------------------------
// SetLoResColor - Write a color to a lo-res block at (col, lores_row)
//   Usage: SetLoResColor(col, lores_row, color_nibble)
//   color_nibble: $0-$F (one of the 16 lo-res colors)
//---------------------------------------------------------------------------
.macro SetLoResColor(col, lores_row, color_nibble) {
    lda #col
    ldx #lores_row
    jsr il_calc_lores_pos
    ldy #0
    // Determine nibble position
    lda ZP_TMP1
    beq slrc_low
    // High nibble: color in bits 4-7
    lda (ZP_PTR0), y
    and #$0F
    ora #(color_nibble << 4)
    sta (ZP_PTR0), y
    bra slrc_done
slrc_low:
    // Low nibble: color in bits 0-3
    lda (ZP_PTR0), y
    and #$F0
    ora #color_nibble
    sta (ZP_PTR0), y
slrc_done:
}

//===========================================================================
