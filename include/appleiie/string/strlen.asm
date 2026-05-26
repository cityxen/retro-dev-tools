#importonce
//===========================================================================
// CityXen Apple IIe Library - String Length
//===========================================================================

//---------------------------------------------------------------------------
// il_strlen - Calculate length of null-terminated string at ZP_PTR0
//   On exit: Y = length (does not include null terminator), max 255
//   Trashes: A, Y
//---------------------------------------------------------------------------
il_strlen:
    ldy #0
strlen_loop:
    lda (ZP_PTR0), y
    beq strlen_done
    iny
    bne strlen_loop
strlen_done:
    rts

//---------------------------------------------------------------------------
// StrLen - Convenience macro
// Usage: StrLen(string_addr)  -> result in Y
//---------------------------------------------------------------------------
.macro StrLen(string_addr) {
    lda #<string_addr
    sta ZP_PTR0
    lda #>string_addr
    sta ZP_PTR0 + 1
    jsr il_strlen
}

//===========================================================================
