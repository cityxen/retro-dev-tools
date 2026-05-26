//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//
#importonce

print_yesno:
    beq !+
    Print(pyn_yes_txt)
    jmp pyn_end
!:
    Print(pyn_no_txt)
pyn_end:
    rts
pyn_yes_txt:
.encoding "petscii_mixed"
.text "yes"
.byte 0
pyn_no_txt:
.encoding "petscii_mixed"
.text "no "
.byte 0
