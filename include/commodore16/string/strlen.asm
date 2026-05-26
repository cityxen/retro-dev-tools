//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — String length
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// StrLen(instring) macro: count characters until null byte; result in str_len and X.
//////////////////////////////////////////////////////////////////

#importonce

str_len: .byte 0

.macro StrLen(instring) {
    ldx #$ff
    stx str_len
!:
    inx
    lda instring,x
    bne !-
    stx str_len
}
