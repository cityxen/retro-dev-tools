#importonce
//===========================================================================
// CityXen Apple IIe Library - ASCII to Apple II Screen Code Conversion
//
// Apple II Monitor COUT expects characters with the high bit SET.
// Standard ASCII has the high bit clear.
// Normal text:   char | $80  (e.g., 'A' = $41 -> $C1)
// Inverse text:  char & $3F  (e.g., 'A' = $41 -> $01)
// Flash text:    char | $40  then char & $7F (e.g., 'A' -> $41)
//
// This module converts null-terminated ASCII strings to Apple II format.
//===========================================================================

//---------------------------------------------------------------------------
// ascii_to_appleii - Convert ASCII byte to normal-video Apple II screen code
//   On entry: A = ASCII character (high bit clear)
//   On exit:  A = Apple II screen code (high bit set)
//---------------------------------------------------------------------------
ascii_to_appleii:
    ora #CHR_NORMAL     // set high bit for normal video
    rts

//---------------------------------------------------------------------------
// ascii_to_appleii_inverse - Convert ASCII to inverse video screen code
//   On entry: A = ASCII character
//   On exit:  A = inverse screen code (high bits clear, masked to $00-$3F)
//---------------------------------------------------------------------------
ascii_to_appleii_inverse:
    and #$3F            // mask to inverse range
    rts

//---------------------------------------------------------------------------
// il_str_to_appleii - Convert null-terminated ASCII string in-place
//   ZP_PTR0 = pointer to string; each byte gets high bit set.
//   Stops at null ($00).
//---------------------------------------------------------------------------
il_str_to_appleii:
    ldy #0
sta_loop:
    lda (ZP_PTR0), y
    beq sta_done
    ora #CHR_NORMAL
    sta (ZP_PTR0), y
    iny
    bne sta_loop
    inc ZP_PTR0 + 1
    bra sta_loop
sta_done:
    rts

//===========================================================================
