//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Print true/false
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////

#importonce

// PrintTrueFalse(): print "TRUE" if A != 0, "FALSE" if A == 0.
.macro PrintTrueFalse() {
    jsr print_truefalse
}

print_truefalse:
    cmp #$00
    beq ptf_false
    lda #<ptf_true_str
    sta zp_tmp_lo
    lda #>ptf_true_str
    sta zp_tmp_hi
    jsr print
    rts
ptf_false:
    lda #<ptf_false_str
    sta zp_tmp_lo
    lda #>ptf_false_str
    sta zp_tmp_hi
    jsr print
    rts
ptf_true_str:  .text "TRUE"  : .byte 0
ptf_false_str: .text "FALSE" : .byte 0
