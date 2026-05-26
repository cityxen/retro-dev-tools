//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Macros
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// Notes:
//  - Must #import "Constants.asm" before this file
//  - Macros expand inline — use subroutines for repeated operations
//////////////////////////////////////////////////////////////////////////////////////

#import "Constants.asm"

//////////////////////////////////////////////////////////////////////////////////////
// CityXenUpstart - BASIC SYS stub at $0401 (PET BASIC start address)
// Emits a minimal BASIC program: <year> SYS <start>
// Then positions the PC at $0430 for code.

.macro CityXenUpstart(start) {
* = $0401 "BASIC Upstart"
    .word pet_usend         // pointer to next BASIC line
    .word 2026              // line number (year)
    .byte $9e               // SYS token
    .text toIntString(start)
    .byte 0                 // end of line
pet_usend:
    .byte 0, 0              // null next-line pointer = end of BASIC
* = $0430 "Code Start"
}

//////////////////////////////////////////////////////////////////////////////////////
// ClearScreen - Clear the screen by sending CLR character via KERNAL

.macro ClearScreen() {
    lda #$93
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PlotCursor - Position the cursor using KERNAL_PLOT
// col: 0-39, row: 0-24

.macro PlotCursor(col, row) {
    ldx #row
    ldy #col
    clc
    jsr KERNAL_PLOT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintAt - Print a zero-terminated string at (col, row)

.macro PrintAt(col, row, string) {
    PlotCursor(col, row)
    lda #<string
    sta zp_tmp_lo
    lda #>string
    sta zp_tmp_hi
    jsr print
}

//////////////////////////////////////////////////////////////////////////////////////
// PokeString - Copy a screencode string directly to screen RAM

.macro PokeString(loc, string_loc) {
    ldx #$00
pks_loop:
    lda string_loc, x
    beq pks_done
    sta loc, x
    inx
    jmp pks_loop
pks_done:
}

//////////////////////////////////////////////////////////////////////////////////////
// ReadKeyJSR - If A == key, JSR to subroutine

.macro ReadKeyJSR(key, sbr) {
    cmp #key
    bne rks_skip
    jsr sbr
rks_skip:
}

//////////////////////////////////////////////////////////////////////////////////////
// ReadKeyJMP - If A == key, JMP to label

.macro ReadKeyJMP(key, lbl) {
    cmp #key
    bne rkj_skip
    jmp lbl
rkj_skip:
}

//////////////////////////////////////////////////////////////////////////////////////
// zp_str - Load string address into zp_tmp_lo/hi

.macro zp_str(x) {
    lda #<x
    sta zp_tmp_lo
    lda #>x
    sta zp_tmp_hi
}
