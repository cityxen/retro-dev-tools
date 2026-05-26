//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Print — Core Print Routines
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// PET has no color RAM — PrintColor and color-related macros are stubs.
// All character output goes via KERNAL_CHROUT.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

//////////////////////////////////////////////////////////////////////////////////////
// Print(string) — print null-terminated string at current cursor position

.macro Print(string) {
    lda #<string
    sta zp_tmp_lo
    lda #>string
    sta zp_tmp_hi
    jsr print
}

.macro PrintP(lo, hi) {
    lda #lo
    sta zp_tmp_lo
    lda #hi
    sta zp_tmp_hi
    jsr print
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintXY(text, x, y) — position cursor then print

.macro PrintXY(text, x, y) {
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
    Print(text)
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintXYColor — stub (PET has no color RAM)

.macro PrintXYColor(string, x, y, color) {
    PrintXY(string, x, y)
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintColor — stub (PET: monochrome)

.macro PrintColor(color) {
    // no-op on PET (no color RAM)
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintPlot(x, y) — position cursor

.macro PrintPlot(x, y) {
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintChr(char) — output single character

.macro PrintChr(char) {
    lda #char
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintLF — output carriage return

.macro PrintLF() {
    lda #$0d
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintClear — clear screen

.macro PrintClear() {
    lda #$93
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintHome — move cursor to home

.macro PrintHome() {
    lda #$13
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintDown / PrintUp / PrintRight / PrintLeft — cursor movement

.macro PrintDown(num) {
    ldx #num
    lda #$11
pd_loop:
    jsr KERNAL_CHROUT
    dex
    bne pd_loop
}

.macro PrintUp(num) {
    ldx #num
    lda #$91
pu_loop:
    jsr KERNAL_CHROUT
    dex
    bne pu_loop
}

.macro PrintRight(num) {
    ldx #num
    lda #$1d
pr_loop:
    jsr KERNAL_CHROUT
    dex
    bne pr_loop
}

.macro PrintLeft(num) {
    ldx #num
    lda #$9d
pl_loop:
    jsr KERNAL_CHROUT
    dex
    bne pl_loop
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintReverseOn / PrintReverseOff

.macro PrintReverseOn() {
    lda #$12
    jsr KERNAL_CHROUT
}

.macro PrintReverseOff() {
    lda #$92
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintUpperCase / PrintLowerCase

.macro PrintUpperCase() {
    lda #$8e
    jsr KERNAL_CHROUT
}

.macro PrintLowerCase() {
    lda #$0e
    jsr KERNAL_CHROUT
}

//////////////////////////////////////////////////////////////////////////////////////
// PrintStrLF — print string then carriage return

.macro PrintStrLF(string) {
    Print(string)
    PrintChr($0d)
}

//////////////////////////////////////////////////////////////////////////////////////
// print — core null-terminated string output subroutine
// zp_tmp_lo/hi must be loaded with string address before calling.

print:
    ldy #$00
print_loop:
    lda (zp_tmp), y
    beq print_out
    jsr KERNAL_CHROUT
    inc zp_tmp_lo
    bne print_next
    inc zp_tmp_hi
print_next:
    jmp print_loop
print_out:
    rts
