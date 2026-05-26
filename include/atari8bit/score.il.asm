#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Score management (BCD, 10 digits)
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// score[5]: 5 BCD bytes, LSB first (2 decimal digits each = 10 digits).
// score_str: score as Atari screen codes ($10-$19), $FF terminated.
// score_digits: number of digits to display (default 10).
// score_math_o: operand for score_add / score_sub.
//
// API:
//   score_reset         — zero the score
//   score_add           — score += score_math_o  (BCD)
//   score_sub           — score -= score_math_o  (BCD, floor at 0)
//   score_to_str        — refresh score_str from score bytes
//   score_from_str      — reload score bytes from score_str
//   is_score_zero       — A=0 if score is zero, nonzero otherwise
//   DrawScore(base,r,c) — macro: print score (no leading zeros) at row/col
//////////////////////////////////////////////////////////////////

score:          .byte 0,0,0,0,0   // 5 BCD bytes, LSB first
score_str:      .fill 11, SC('0') // 10 screen-code digits + $FF terminator
                .byte $FF
score_digits:   .byte 9           // index of last digit (0-9)
score_math_o:   .byte 0           // operand for add/sub

// DrawScore(base, row, col) ────────────────────────────────────
// Print score_str (no leading zeros) at row r, column c of a text
// screen whose first byte is at compile-time constant `base`.
.macro DrawScore(base, r, c) {
    lda #<score_str
    sta ZP_PTR_LO
    lda #>score_str
    sta ZP_PTR_HI
    lda #<(base + r*40 + c)
    sta ZP_PCUR_LO
    lda #>(base + r*40 + c)
    sta ZP_PCUR_HI
    jsr print_no_leading_zeros
}

// score_to_str ─────────────────────────────────────────────────
// Convert score BCD bytes → score_str (Atari screen codes $10-$19).
score_to_str:
    ldx #0
    ldy score_digits
sts_loop:
    lda score,x
    pha
    and #$0F           // low nibble → ones digit
    clc
    adc #SC('0')       // $10 = SC('0')
    sta score_str,y
    dey
    pla
    lsr
    lsr
    lsr
    lsr
    clc
    adc #SC('0')       // high nibble → tens digit
    sta score_str,y
    dey
    inx
    cpx #5
    bne sts_loop
    rts

// score_from_str ───────────────────────────────────────────────
// Reload score BCD bytes from score_str (inverse of score_to_str).
score_from_str:
    ldx #0
    ldy #4
sfs_loop:
    lda score_str,x
    sec
    sbc #SC('0')       // screen code → BCD digit (0-9)
    asl
    asl
    asl
    asl
    sta score,y
    inx
    lda score_str,x
    sec
    sbc #SC('0')
    ora score,y
    sta score,y
    inx
    dey
    cpy #$FF
    bne sfs_loop
    rts

// score_reset ──────────────────────────────────────────────────
score_reset:
    lda #0
    sta score
    sta score+1
    sta score+2
    sta score+3
    sta score+4
    jsr score_to_str
    rts

// score_add ────────────────────────────────────────────────────
// score += score_math_o  (BCD arithmetic)
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

// score_sub ────────────────────────────────────────────────────
// score -= score_math_o  (BCD arithmetic, floored at 0)
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
    bcs !+              // carry set = no borrow = result >= 0
    jsr score_reset     // underflow → clamp to zero
!:
    jsr score_to_str
    rts

// is_score_zero ────────────────────────────────────────────────
// Returns A = 0 if score is zero, nonzero if score > 0.
score_zero_flag: .byte 0
is_score_zero:
    lda #0
    sta score_zero_flag
    lda score
    beq !+
    inc score_zero_flag
!:
    lda score+1
    beq !+
    inc score_zero_flag
!:
    lda score+2
    beq !+
    inc score_zero_flag
!:
    lda score+3
    beq !+
    inc score_zero_flag
!:
    lda score+4
    beq !+
    inc score_zero_flag
!:
    lda score_zero_flag
    rts

//////////////////////////////////////////////////////////////////
