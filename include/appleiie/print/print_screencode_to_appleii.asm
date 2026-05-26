#importonce
//===========================================================================
// CityXen Apple IIe Library - Screen Code to Apple II Character Conversion
//
// When data originates from a tool that uses raw 7-bit screen codes
// (as opposed to ASCII), use these routines to apply the correct
// Apple II encoding (high bit for normal video, mask for inverse).
//
// 7-bit screen codes match ASCII for $20-$7E (printable range);
// control codes ($00-$1F) and $7F (DEL) map to inverse/special chars.
//===========================================================================

//---------------------------------------------------------------------------
// screencode_to_appleii - Convert a 7-bit screen code to Apple II format
//   $20-$7E: or with $80 for normal video
//   $00-$1F: these are inverse uppercase letters on Apple II
//   On entry: A = screen code
//   On exit:  A = Apple II character byte
//---------------------------------------------------------------------------
screencode_to_appleii:
    cmp #$20
    bcc sc_inverse
    ora #CHR_NORMAL     // printable: set high bit
    rts
sc_inverse:
    // Control codes become inverse characters ($00-$1F = inverse @,A-Z,etc)
    and #$3F
    rts

//===========================================================================
