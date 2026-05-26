//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Score (BCD)
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// Hardware-independent; identical logic to the C64 version.
// DrawScore uses KERNAL_PLOT + PrintNoLeadingZeros (from print.il.asm).
//////////////////////////////////////////////////////////////////////////////////////

#importonce

score:          // 5 BCD bytes, LSB first
    .byte $00, $00, $00, $00, $00

score_str:      // 10 ASCII digit characters + null
    .text "0000000000"
    .byte 0

score_digits:   .byte $09       // digits to display (default 10)
score_math_o:   .byte $00       // operand for add/sub

//////////////////////////////////////////////////////////////////////////////////////
// DrawScore(x, y) — print score at column x, row y

.macro DrawScore(x, y) {
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
    PrintNoLeadingZeros(score_str)
}

//////////////////////////////////////////////////////////////////////////////////////
// score_to_str — convert BCD score bytes → ASCII string in score_str

score_to_str:
    ldx #$00
    ldy score_digits
sts_loop:
    lda score, x
    pha
    and #$0f
    clc
    adc #48
    sta score_str, y
    dey
    pla
    lsr
    lsr
    lsr
    lsr
    clc
    adc #48
    sta score_str, y
    dey
    inx
    cpx #5
    bne sts_loop
    rts

//////////////////////////////////////////////////////////////////////////////////////
// score_from_str — convert ASCII string in score_str → BCD score bytes

score_from_str:
    ldx #$00
    ldy #$04
sfs_loop:
    lda score_str, x
    and #$0f
    clc
    asl
    asl
    asl
    asl
    sta score, y
    inx
    lda score_str, x
    and #$0f
    ora score, y
    sta score, y
    inx
    dey
    cpy #$ff
    bne sfs_loop
    rts

//////////////////////////////////////////////////////////////////////////////////////
// score_reset — zero all score bytes

score_reset:
    lda #$00
    sta score
    sta score+1
    sta score+2
    sta score+3
    sta score+4
    jsr score_to_str
    rts

//////////////////////////////////////////////////////////////////////////////////////
// score_add — add score_math_o (BCD) to score

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

//////////////////////////////////////////////////////////////////////////////////////
// score_sub — subtract score_math_o (BCD) from score (floors at zero)

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
    bcs ss_no_underflow
    jsr score_reset
ss_no_underflow:
    jsr score_to_str
    rts

//////////////////////////////////////////////////////////////////////////////////////
// is_score_zero — returns A=0 if score is zero, A>0 otherwise

is_score_zero:
    lda #$00
    sta score_zero
    sed
    clc
    lda score
    beq isz_1
    inc score_zero
isz_1:
    lda score+1
    beq isz_2
    inc score_zero
isz_2:
    lda score+2
    beq isz_3
    inc score_zero
isz_3:
    lda score+3
    beq isz_4
    inc score_zero
isz_4:
    lda score+4
    beq isz_5
    inc score_zero
isz_5:
    cld
    lda score_zero
    rts

score_zero: .byte 0
