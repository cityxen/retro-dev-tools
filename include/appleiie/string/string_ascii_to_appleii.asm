#importonce
//===========================================================================
// CityXen Apple IIe Library - ASCII to Apple II String Conversion
//
// Converts a null-terminated ASCII string (high bit clear) to Apple II
// Monitor-compatible format (high bit set for normal video).
//===========================================================================

//---------------------------------------------------------------------------
// il_string_to_appleii - Convert string at ZP_PTR0 in-place
//   Sets high bit of every byte until null.
//---------------------------------------------------------------------------
il_string_to_appleii:
    ldy #0
s2a_loop:
    lda (ZP_PTR0), y
    beq s2a_done
    ora #CHR_NORMAL
    sta (ZP_PTR0), y
    iny
    bne s2a_loop
    inc ZP_PTR0 + 1
    bra s2a_loop
s2a_done:
    rts

//---------------------------------------------------------------------------
// il_appleii_to_ascii - Strip high bit from string at ZP_PTR0 in-place
//   Converts Apple II format back to plain ASCII.
//---------------------------------------------------------------------------
il_appleii_to_ascii:
    ldy #0
a2s_loop:
    lda (ZP_PTR0), y
    beq a2s_done
    and #$7F
    sta (ZP_PTR0), y
    iny
    bne a2s_loop
    inc ZP_PTR0 + 1
    bra a2s_loop
a2s_done:
    rts

//===========================================================================
