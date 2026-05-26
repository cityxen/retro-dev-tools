#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Print decimal (16-bit unsigned)
//
// print_decimal: print print_dec_lo/hi (16-bit) to (ZP_PCUR).
//                Range 0-65535.  Leading zeros suppressed.
//                Advances cursor by 1-5 characters.
//
// PrintDecimal(lo, hi)  — macro: set lo/hi, JSR
// PrintDecByte()        — macro: print A as decimal (0-255)
//////////////////////////////////////////////////////////////////

print_dec_lo:      .byte 0
print_dec_hi:      .byte 0
print_dec_started: .byte 0
print_dec_digit:   .byte 0
print_dec_tmp:     .byte 0

.macro PrintDecimal(lo, hi) {
    lda #lo
    sta print_dec_lo
    lda #hi
    sta print_dec_hi
    jsr print_decimal
}

.macro PrintDecByte() {
    sta print_dec_lo
    lda #0
    sta print_dec_hi
    jsr print_decimal
}

// print_decimal ────────────────────────────────────────────────
print_decimal:
    lda #0
    sta print_dec_started
    ldx #0

pd_next:
    lda #0
    sta print_dec_digit

pd_sub:
    lda print_dec_lo
    sec
    sbc pd_div_lo,x
    sta print_dec_tmp
    lda print_dec_hi
    sbc pd_div_hi,x
    bcc pd_emit
    sta print_dec_hi
    lda print_dec_tmp
    sta print_dec_lo
    inc print_dec_digit
    jmp pd_sub

pd_emit:
    lda print_dec_digit
    bne pd_write
    lda print_dec_started
    bne pd_write
    cpx #4              // always print the units digit
    bne pd_skip

pd_write:
    lda #1
    sta print_dec_started
    lda print_dec_digit
    clc
    adc #SC('0')
    jsr print_char

pd_skip:
    inx
    cpx #5
    bne pd_next
    rts

pd_div_lo: .byte <10000, <1000, <100, <10, <1
pd_div_hi: .byte >10000, >1000, >100, >10, >1
