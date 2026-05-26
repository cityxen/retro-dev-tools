#importonce
//===========================================================================
// CityXen Apple IIe Library - Print YES / NO
//===========================================================================

// Apple II format: chars with high bit set for Monitor COUT
str_yes_a2:
    .byte $D9,$C5,$D3,$00          // YES (Y=$59|$80, E=$45|$80, S=$53|$80)
str_no_a2:
    .byte $CE,$CF,$00              // NO  (N=$4E|$80, O=$4F|$80)

//---------------------------------------------------------------------------
// il_print_yes - Print "YES" at current cursor
//---------------------------------------------------------------------------
il_print_yes:
    lda #<str_yes_a2
    sta ZP_PTR0
    lda #>str_yes_a2
    sta ZP_PTR0 + 1
    jsr il_print
    rts

//---------------------------------------------------------------------------
// il_print_no - Print "NO" at current cursor
//---------------------------------------------------------------------------
il_print_no:
    lda #<str_no_a2
    sta ZP_PTR0
    lda #>str_no_a2
    sta ZP_PTR0 + 1
    jsr il_print
    rts

//---------------------------------------------------------------------------
// il_print_yesno - Print "YES" if A != 0, "NO" if A == 0
//---------------------------------------------------------------------------
il_print_yesno:
    beq il_print_no
    jmp il_print_yes

//===========================================================================
