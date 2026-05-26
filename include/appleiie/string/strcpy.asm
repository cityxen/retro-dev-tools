#importonce
//===========================================================================
// CityXen Apple IIe Library - String Copy
//===========================================================================

//---------------------------------------------------------------------------
// il_strcpy - Copy null-terminated string from ZP_PTR0 to ZP_PTR1
//   Copies including the null terminator.
//   Trashes: A, Y
//---------------------------------------------------------------------------
il_strcpy:
    ldy #0
strcpy_loop:
    lda (ZP_PTR0), y
    sta (ZP_PTR1), y
    beq strcpy_done
    iny
    bne strcpy_loop
    inc ZP_PTR0 + 1
    inc ZP_PTR1 + 1
    bra strcpy_loop
strcpy_done:
    rts

//---------------------------------------------------------------------------
// StrCpy - Convenience macro
// Usage: StrCpy(src_addr, dest_addr)
//---------------------------------------------------------------------------
.macro StrCpy(src_addr, dest_addr) {
    lda #<src_addr
    sta ZP_PTR0
    lda #>src_addr
    sta ZP_PTR0 + 1
    lda #<dest_addr
    sta ZP_PTR1
    lda #>dest_addr
    sta ZP_PTR1 + 1
    jsr il_strcpy
}

//===========================================================================
