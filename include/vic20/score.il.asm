//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — BCD Score Management
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// 10-digit BCD score stored in 5 bytes (LSB first).
// score_add / score_sub operate in decimal mode.
// DrawScore uses KERNAL_PLOT + KERNAL_CHROUT (same as C64).
// Column must be in range 0-21 for the VIC-20 22-column screen.
//////////////////////////////////////////////////////////////////

#importonce

score:          // BCD score bytes (LSB first)
// LSB --------------- MSB
.byte $00,$00,$00,$00,$00

score_str: .text "0000000000"  // string representation
           .byte 0
score_digits:   .byte $09  // number of digits to display (default 10)
score_math_o:   .byte $00  // value to add/subtract

.macro DrawScore(x,y) {
    clc
    ldy #x
    ldx #y
    jsr KERNAL_PLOT
    PrintNoLeadingZeros(score_str)
}

//////////////////////////////////////////////////////////////////
// score_to_str: update score_str from BCD score bytes

score_to_str:
    ldx #$00
    ldy score_digits
!:
    lda score,x
    pha
    and #$0f
    clc
    adc #48
    sta score_str,y
    dey
    pla
    lsr
    lsr
    lsr
    lsr
    clc
    adc #48
    sta score_str,y
    dey
    inx
    cpx #5
    bne !-
    rts

//////////////////////////////////////////////////////////////////
// score_from_str: update BCD score bytes from score_str

score_from_str:
    ldx #$00
    ldy #$04
!:
    lda score_str,x
    and #$0f
    clc
    asl
    asl
    asl
    asl
    sta score,y
    inx
    lda score_str,x
    and #$0f
    ora score,y
    sta score,y
    inx
    dey
    cpy #$ff
    bne !-
    rts

//////////////////////////////////////////////////////////////////
// score_reset: zero the score

score_reset:
    lda #$00
    sta score
    sta score+1
    sta score+2
    sta score+3
    sta score+4
    jsr score_to_str
    rts

//////////////////////////////////////////////////////////////////
// score_add: add score_math_o to score (BCD)

score_add:
    sed
    clc
    lda score
    adc score_math_o
    sta score
    lda score+1
    adc #0
    sta score+1
    lda score+2
    adc #0
    sta score+2
    lda score+3
    adc #0
    sta score+3
    lda score+4
    adc #0
    sta score+4
    cld
    jsr score_to_str
    rts

//////////////////////////////////////////////////////////////////
// score_sub: subtract score_math_o from score (BCD, floor at 0)

score_sub:
    sed
    sec
    lda score
    sbc score_math_o
    sta score
    lda score+1
    sbc #0
    sta score+1
    lda score+2
    sbc #0
    sta score+2
    lda score+3
    sbc #0
    sta score+3
    lda score+4
    sbc #0
    sta score+4
    cld
    bcs !+
    jsr score_reset
!:
    jsr score_to_str
    rts

//////////////////////////////////////////////////////////////////
// is_score_zero: A = 0 if score is zero; nonzero otherwise

is_score_zero:
    lda #$00
    sta score_zero
    sed
    clc
    lda score
    beq !+
    inc score_zero
!:
    lda score+1
    beq !+
    inc score_zero
!:
    lda score+2
    beq !+
    inc score_zero
!:
    lda score+3
    beq !+
    inc score_zero
!:
    lda score+4
    beq !+
    inc score_zero
!:
    cld
    lda score_zero
    rts
score_zero: .byte 0
