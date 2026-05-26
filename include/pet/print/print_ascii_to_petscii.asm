//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print ASCII-to-PETSCII
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce
#import "string/string_ascii_to_petscii.asm"

.macro PrintASCII2Petscii(string) {
    ldx #$00
pa2p_loop:
    lda string, x
    beq pa2p_done
    jsr ascii_to_petscii_kp
    jsr KERNAL_CHROUT
    inx
    jmp pa2p_loop
pa2p_done:
}
