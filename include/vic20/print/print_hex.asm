//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Hex print routines
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// print_hex: print A as two hex digits via KERNAL_CHROUT.
// PrintHexXY(x,y): plot cursor then print_hex (A holds value).
// PrintHex(): inline call to print_hex_inline.
//////////////////////////////////////////////////////////////////

#importonce

.macro PrintHexXY(x,y) {
    sta a_reg
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
    lda a_reg
    jsr print_hex_inline
}

.macro PrintHex() {
    jsr print_hex_inline
}

//////////////////////////////////////////////////////////////////
// print_hex_inline: print A as two uppercase hex digits.

print_hex_inline_d: .byte 1
print_hex_inline:
    sta zp_tmp
    lda zp_tmp
    lsr
    lsr
    lsr
    lsr
    tax
    lda print_hex_conv_table,x
    jsr KERNAL_CHROUT
    lda zp_tmp
    and #$0f
    tax
    lda print_hex_conv_table,x
    jsr KERNAL_CHROUT
    rts
print_hex_conv_table:
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46

//////////////////////////////////////////////////////////////////
// print_hex: alternate entry (preserves A via stack).

print_hex:
  pha
  lsr
  lsr
  lsr
  lsr
  jsr print_h_digit
  pla
  and #$0f
  jsr print_h_digit
  rts

print_h_digit:
  cmp #10
  bcc !+
  adc #6
!:
  adc #48
  jsr KERNAL_CHROUT
  rts
