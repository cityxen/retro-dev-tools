#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — String copy
//
// StrCpyL(from, to, len)  — fixed-length copy (no terminator needed)
// StrCpy(from, to)        — copy until $FF terminator (inclusive)
// string_copy             — runtime version using ZP_PTR / ZP_STR
//
// StrCpy uses ZP_PTR_LO/HI as source and ZP_STR_LO/HI as dest.
//////////////////////////////////////////////////////////////////

.macro StrCpyL(str_from, str_to, len) {
    ldx #0
!:
    lda str_from,x
    sta str_to,x
    inx
    cpx #len
    bne !-
}

.macro StrCpy(str_from, str_to) {
    lda #<str_from
    sta ZP_PTR_LO
    lda #>str_from
    sta ZP_PTR_HI
    lda #<str_to
    sta ZP_STR_LO
    lda #>str_to
    sta ZP_STR_HI
    jsr string_copy
}

// string_copy: copy $FF-terminated string from (ZP_PTR) to (ZP_STR).
//              Copies the $FF terminator too.
string_copy:
    ldy #0
sc_loop:
    lda (ZP_PTR_LO),y
    sta (ZP_STR_LO),y
    cmp #$FF            // $FF = terminator
    beq sc_done
    inc ZP_PTR_LO
    bne !+
    inc ZP_PTR_HI
!:
    inc ZP_STR_LO
    bne !+
    inc ZP_STR_HI
!:
    jmp sc_loop
sc_done:
    rts
