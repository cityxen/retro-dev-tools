//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — String length
//
// StrLen(str): count bytes until $FF terminator.
//              Result stored in str_len.
//
// Note: Atari screen-code strings use $FF as the null terminator
//       because screen code 0 = space.
//////////////////////////////////////////////////////////////////

str_len: .byte 0

.macro StrLen(str) {
    ldx #$FF
    stx str_len
!:
    inx
    lda str,x
    cmp #$FF
    bne !-
    stx str_len
}
