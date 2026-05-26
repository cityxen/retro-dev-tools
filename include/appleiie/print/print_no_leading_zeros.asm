#importonce
//===========================================================================
// CityXen Apple IIe Library - Print Number Without Leading Zeros
//
// Wraps il_print_decimal with the "no leading zeros" behavior already
// built in.  Provided as a named entry point for clarity and symmetry
// with the C64 port.
//===========================================================================

//---------------------------------------------------------------------------
// il_print_no_leading_zeros - Print 16-bit value, suppress leading zeros
//   A = lo byte, X = hi byte
//---------------------------------------------------------------------------
il_print_no_leading_zeros:
    jmp il_print_decimal    // il_print_decimal already suppresses leading zeros

//===========================================================================
