//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — KickAssembler Macros
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Must include Constants.asm before this file.
// These macros expand inline — use sparingly in hot loops;
// prefer JSR routines for repeated calls.
//////////////////////////////////////////////////////////////////

#importonce
#import "Constants.asm"

//////////////////////////////////////////////////////////////////
// Display Initialization

// Install a custom display list and enable DMA.
// dl_lo/dl_hi = address of display list.
.macro SetDisplayList(dl_lo, dl_hi) {
    lda #dl_lo
    sta SDLSTL
    lda #dl_hi
    sta SDLSTH
}

// Enable standard playfield DMA (no player/missile DMA).
.macro EnableDMA() {
    lda #DMA_ENABLE_WIDE
    sta SDMCTL
}

// Disable all DMA (blank screen).
.macro DisableDMA() {
    lda #DMA_OFF
    sta SDMCTL
}

//////////////////////////////////////////////////////////////////
// Color

.macro SetBackground(color) {
    lda #color
    sta COLBK
}

.macro SetForeground(color) {
    lda #color
    sta COLPF2
}

//////////////////////////////////////////////////////////////////
// Sound — POKEY

// Silence all four audio channels.
.macro SilenceAll() {
    lda #$00
    sta AUDC1
    sta AUDC2
    sta AUDC3
    sta AUDC4
}

//////////////////////////////////////////////////////////////////
// String emit helpers

// Emit a null-terminated Atari screen-code string from a
// KickAssembler string literal.  Screen code = char - $20.
.macro ataristr(s) {
    .for (var i = 0; i < s.size(); i++) {
        .byte s.charAt(i) - $20
    }
    .byte $FF   // $FF = null terminator ($00 = space in Atari screen codes)
}

// Load ZP_PTR_LO/HI with the address of str, then JSR print_at.
// row = text row (0-3 in mixed mode), col = column (0-39).
.macro PrintLine(str, row, col) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    ldx #row
    lda #col
    jsr print_at
}

//////////////////////////////////////////////////////////////////
// Upstart — Atari XEX entry point (no BASIC upstart needed).
// Just sets the program origin; the XEX run-address segment
// in the binary handles the entry point.
.macro AtariUpstart(start) {
    * = $2000 "Program"
}

//////////////////////////////////////////////////////////////////
// Joystick direction bit tests (STICK0 shadow)
// STICK bits: 3=right, 2=left, 1=down, 0=up  (0=pressed)
.const STICK_UP    = $01
.const STICK_DOWN  = $02
.const STICK_LEFT  = $04
.const STICK_RIGHT = $08
.const STICK_NONE  = $0F   // all bits set = neutral

//////////////////////////////////////////////////////////////////
