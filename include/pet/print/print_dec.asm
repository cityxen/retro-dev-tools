//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print Decimal
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// Prints unsigned 16-bit integer (0-65535) held in numHi:numLo.
//////////////////////////////////////////////////////////////////////////////////////

.const numLo   = $fb
.const numHi   = $fc
.const digit   = $fd
.const started = $fe
.const tempLo  = $ff

.macro PrintDecimal() {
    sta tmp_1
    lda #<tmp_1
    sta numLo
    lda #>tmp_1
    sta numHi
    jsr print_decimal
}

print_decimal:
    lda #0
    sta started
    ldx #0

pd_next_divisor:
    lda #0
    sta digit

pd_subtract:
    lda numLo
    sec
    sbc pd_divLo, x
    sta tempLo
    lda numHi
    sbc pd_divHi, x
    bcc pd_print_digit
    sta numHi
    lda tempLo
    sta numLo
    inc digit
    jmp pd_subtract

pd_print_digit:
    lda digit
    bne pd_do_print
    lda started
    bne pd_do_print
    cpx #4
    bne pd_skip

pd_do_print:
    lda #1
    sta started
    lda digit
    clc
    adc #$30
    jsr KERNAL_CHROUT

pd_skip:
    inx
    cpx #5
    bne pd_next_divisor
    rts

pd_divLo: .byte <10000, <1000, <100, <10, <1
pd_divHi: .byte >10000, >1000, >100, >10, >1
