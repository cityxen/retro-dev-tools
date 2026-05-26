//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Print yes/no
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////

#importonce

// PrintYesNo(): print "YES" if A != 0, "NO" if A == 0.
.macro PrintYesNo() {
    jsr print_yesno
}

print_yesno:
    cmp #$00
    beq pyn_no
    lda #<pyn_yes_str
    sta zp_tmp_lo
    lda #>pyn_yes_str
    sta zp_tmp_hi
    jsr print
    rts
pyn_no:
    lda #<pyn_no_str
    sta zp_tmp_lo
    lda #>pyn_no_str
    sta zp_tmp_hi
    jsr print
    rts
pyn_yes_str: .text "YES" : .byte 0
pyn_no_str:  .text "NO"  : .byte 0
