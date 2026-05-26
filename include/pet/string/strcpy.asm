//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// String Copy
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// StrCpyL(str_from, str_to, len) — copy exactly len bytes
.macro StrCpyL(str_from, str_to, len) {
    ldx #$00
scl_loop:
    lda str_from, x
    sta str_to, x
    inx
    cpx #len
    bne scl_loop
}

// StrCpy(str_from, str_to) — copy null-terminated string
.macro StrCpy(str_from, str_to) {
    lda #<str_from
    sta zp_string_lo
    lda #>str_from
    sta zp_string_hi
    lda #<str_to
    sta zp_str2_lo
    lda #>str_to
    sta zp_str2_hi
    jsr string_copy
}

string_copy:
    ldy #$00
sc_loop:
    lda (zp_string), y
    sta (zp_str2), y
    beq sc_done
    inc zp_string_lo
    bne sc_no_carry1
    inc zp_string_hi
sc_no_carry1:
    inc zp_str2_lo
    bne sc_no_carry2
    inc zp_str2_hi
sc_no_carry2:
    jmp sc_loop
sc_done:
    rts
