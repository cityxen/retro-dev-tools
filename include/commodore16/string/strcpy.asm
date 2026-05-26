//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — String copy
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// string_copy: copy null-terminated string from (zp_string) to (zp_str2).
// StrCpy(from, to) macro: sets ZP pointers and calls string_copy.
// StrCpyL(from, to, len) macro: fixed-length copy (no null check).
//////////////////////////////////////////////////////////////////

#importonce

.macro StrCpyL(str_from,str_to,len) {
    ldx #$00
!:
    lda str_from,x
    sta str_to,x
    inx
    cpx #len
    bne !-
}

.macro StrCpy(str_from,str_to) {
    lda #< str_from
    sta zp_string_lo
    lda #> str_from
    sta zp_string_hi
    lda #< str_to
    sta zp_str2_lo
    lda #> str_to
    sta zp_str2_hi
    jsr string_copy
}

string_copy:
    clc
    ldy #$00
string_copy_1:
    lda (zp_string),y
    sta (zp_str2),y
    beq string_copy_2
    inc zp_string_lo
    bne !+
    inc zp_string_hi
!:
    inc zp_str2_lo
    bne !+
    inc zp_str2_hi
!:
    jmp string_copy_1
string_copy_2:
    rts
