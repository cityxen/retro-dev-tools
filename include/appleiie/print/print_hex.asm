#importonce
//===========================================================================
// CityXen Apple IIe Library - Hex Printing
//===========================================================================

hex_chars: .text "0123456789ABCDEF"   // lookup table

//---------------------------------------------------------------------------
// PrintHex - Print accumulator as two hex digits at current cursor
// Usage: PrintHex()  (A = byte to print)
//---------------------------------------------------------------------------
.macro PrintHex() {
    jsr il_print_hex
}

//---------------------------------------------------------------------------
// PrintHexXY - Print hex byte at (col, row)
// Usage: PrintHexXY(col, row)  (A = byte to print)
//---------------------------------------------------------------------------
.macro PrintHexXY(col, row) {
    pha
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC
    pla
    jsr il_print_hex
}

//---------------------------------------------------------------------------
// il_print_hex - Print A as two ASCII hex digits via Monitor COUT
//---------------------------------------------------------------------------
il_print_hex:
    pha
    // High nibble
    lsr
    lsr
    lsr
    lsr
    tax
    lda hex_chars, x
    ora #CHR_NORMAL
    jsr COUT
    // Low nibble
    pla
    and #$0F
    tax
    lda hex_chars, x
    ora #CHR_NORMAL
    jsr COUT
    rts

//---------------------------------------------------------------------------
// PrintHex_Range - Dump a range of memory as hex bytes
// Usage: PrintHex_Range(start_addr, end_addr)
//   Prints each byte separated by a space; CROUT after 8 bytes per line.
//---------------------------------------------------------------------------
.macro PrintHex_Range(start_addr, end_addr) {
    lda #<start_addr
    sta ZP_PTR0
    lda #>start_addr
    sta ZP_PTR0 + 1
    lda #<end_addr
    sta ZP_PTR1
    lda #>end_addr
    sta ZP_PTR1 + 1
    jsr il_print_hex_range
}

il_print_hex_range:
    ldy #0
    ldx #0          // byte-in-line counter
phr_loop:
    // Check if ptr0 >= ptr1
    lda ZP_PTR0 + 1
    cmp ZP_PTR1 + 1
    bcc phr_ok
    bne phr_done
    lda ZP_PTR0
    cmp ZP_PTR1
    bcs phr_done

phr_ok:
    lda (ZP_PTR0), y
    jsr il_print_hex
    // Space separator
    lda #$A0            // space with high bit set
    jsr COUT
    inx
    cpx #8
    bne phr_no_cr
    jsr CROUT
    ldx #0
phr_no_cr:
    // Advance pointer
    inc ZP_PTR0
    bne phr_loop
    inc ZP_PTR0 + 1
    bra phr_loop
phr_done:
    rts

//===========================================================================
