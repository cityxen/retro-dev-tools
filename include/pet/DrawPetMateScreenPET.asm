//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// DrawPetMateScreen Macro (legacy inline version)
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// This file provides the legacy inline DrawPetMateScreen macro.
// Prefer DrawPetMateScreen.asm (which calls a subroutine) for smaller output
// when drawing multiple screens.
//////////////////////////////////////////////////////////////////////////////////////

// DrawPetMateScreen(screen_name) — inline copy, no subroutine call
// Skips the 2-byte color header (PET is monochrome).
.macro DrawPetMateScreenInline(screen_name) {
    ldx #$00
dpms_inline_loop:
    lda screen_name+2, x        // +2 to skip border/background color bytes
    sta SCREEN_RAM, x
    lda screen_name+2+256, x
    sta SCREEN_RAM+256, x
    lda screen_name+2+512, x
    sta SCREEN_RAM+512, x
    inx
    bne dpms_inline_loop
    ldx #232
dpms_inline_loop2:
    dex
    lda screen_name+2+512+256, x
    sta SCREEN_RAM+512+256, x
    cpx #$00
    bne dpms_inline_loop2
}
