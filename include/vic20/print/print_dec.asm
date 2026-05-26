//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Decimal print routine
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// print_decimal: print unsigned 16-bit integer (0-65535) via KERNAL_CHROUT.
// numHi:numLo = value to print (uses ZP locations $fb-$ff).
// PrintDecimal() macro: stores A in tmp_1 and calls print_decimal.
//////////////////////////////////////////////////////////////////

#importonce

.const numLo   = $fb
.const numHi   = $fc
.const digit   = $fd
.const started = $fe
.const tempLo  = $ff

.macro PrintDecAtColor(xpos,ypos,var_num_mem,color) {
    lda var_num_mem
    clc
    adc #$30
    sta SCREEN_RAM + xpos + ypos*22
    lda #color
    sta COLOR_RAM + xpos + ypos*22
}

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
nextDivisor:
    lda #0
    sta digit
subtractLoop:
    lda numLo
    sec
    sbc divLo,x
    sta tempLo
    lda numHi
    sbc divHi,x
    bcc printThisDigit
    sta numHi
    lda tempLo
    sta numLo
    inc digit
    jmp subtractLoop
printThisDigit:
    lda digit
    bne printDigit
    lda started
    bne printDigit
    cpx #4
    bne skipDigit
printDigit:
    lda #1
    sta started
    lda digit
    clc
    adc #$30
    jsr KERNAL_CHROUT
skipDigit:
    inx
    cpx #5
    bne nextDivisor
    rts

divLo: .byte <10000, <1000, <100, <10, <1
divHi: .byte >10000, >1000, >100, >10, >1
