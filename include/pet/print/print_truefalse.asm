//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print True / False
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

// print_truefalse — call with A != 0 for "true", A == 0 for "false"
print_truefalse:
    beq ptf_false
    Print(ptf_true_txt)
    jmp ptf_end
ptf_false:
    Print(ptf_false_txt)
ptf_end:
    rts

ptf_true_txt:
    .encoding "petscii_mixed"
    .text "true "
    .byte 0

ptf_false_txt:
    .encoding "petscii_mixed"
    .text "false"
    .byte 0
