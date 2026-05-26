//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print ScreenCode-to-PETSCII
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce
#import "string/string_screencode_to_petscii.asm"

.macro PrintScreenCode2Petscii(string) {
    ldx #$00
psc2p_loop:
    lda string, x
    beq psc2p_done
    jsr screencode_to_petscii
    jsr KERNAL_CHROUT
    inx
    jmp psc2p_loop
psc2p_done:
}

.macro PrintScreenCode2PetsciiXY(string, x, y) {
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
    PrintScreenCode2Petscii(string)
}
