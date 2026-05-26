#importonce
//===========================================================================
// CityXen Apple IIe Library - Common String Constants
//
// Strings stored with high bit SET ($80+) for Monitor COUT compatibility.
//===========================================================================

// Common UI strings (Apple II high-bit encoding)
STR_PRESSKEY:
    .byte $D0,$D2,$C5,$D3,$D3,$A0,$C1,$CE,$D9,$A0,$CB,$C5,$D9,$00
    // "PRESS ANY KEY" with high bits set

STR_LOADING:
    .byte $CC,$CF,$C1,$C4,$C9,$CE,$C7,$AE,$AE,$AE,$00
    // "LOADING..."

STR_ERROR:
    .byte $C5,$D2,$D2,$CF,$D2,$00
    // "ERROR"

STR_OK:
    .byte $CF,$CB,$00
    // "OK"

//===========================================================================
