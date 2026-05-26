#importonce
//===========================================================================
// CityXen Apple IIe Library - Hex String to Value
//
// Parse a 1-4 character hex string into a 16-bit value.
//===========================================================================

//---------------------------------------------------------------------------
// il_hex_to_val - Parse hex string at ZP_PTR0, return value in A (lo) / X (hi)
//   String: ASCII hex digits ('0'-'9', 'A'-'F', 'a'-'f'), null-terminated
//   Stops at first non-hex character.
//   Result in ZP_A (lo) and ZP_A+1 (hi); also returned in A/X.
//---------------------------------------------------------------------------
il_hex_to_val:
    stz ZP_A
    stz ZP_A + 1
    ldy #0
htv_loop:
    lda (ZP_PTR0), y
    beq htv_done
    // Shift result left 4 bits (multiply by 16)
    asl ZP_A
    rol ZP_A + 1
    asl ZP_A
    rol ZP_A + 1
    asl ZP_A
    rol ZP_A + 1
    asl ZP_A
    rol ZP_A + 1
    // Convert ASCII char to nibble
    lda (ZP_PTR0), y
    // Strip high bit (in case Apple II format)
    and #$7F
    cmp #'a'
    bcc htv_upper
    sbc #$27        // 'a'-'A' offset adjustment for lower-case
htv_upper:
    cmp #'A'
    bcc htv_digit
    sbc #7          // 'A'-'9'-1 gap in ASCII
htv_digit:
    sec
    sbc #'0'
    and #$0F
    ora ZP_A
    sta ZP_A
    iny
    bra htv_loop
htv_done:
    lda ZP_A
    ldx ZP_A + 1
    rts

//===========================================================================
