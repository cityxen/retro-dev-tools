//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print Yes / No
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

// print_yesno — call with A != 0 for "yes", A == 0 for "no"
print_yesno:
    beq pyn_no
    Print(pyn_yes_txt)
    jmp pyn_end
pyn_no:
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
