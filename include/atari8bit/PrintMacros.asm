#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — High-level print macros
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// These macros provide a convenient interface for printing to the
// Atari text screen in ANTIC mode 2 (40 columns per row).
//
// Unlike the C64 library these do NOT use KERNAL routines — all
// output is direct screen RAM writes via print_char / print_at.
//
// Requires: system.asm, Constants.asm, print.il.asm
//////////////////////////////////////////////////////////////////

// ─── Cursor positioning ──────────────────────────────────────

// PrintPlot(base, row, col): set print cursor to row/col.
.macro PrintPlot(base, row, col) {
    SetPrintCursorXY(base, row, col)
}

// ─── String print ────────────────────────────────────────────

// PrintXY(str, base, row, col): print $FF-terminated string at position.
.macro PrintXY(str, base, row, col) {
    PrintAtXY(str, base, row, col)
}

// PrintLine(str, row, col): legacy alias using ZP_PTR + print_at.
// Requires txt_row_lo/hi tables to be defined by the game's gfx.asm.
.macro PrintLine(str, row, col) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    ldx #row
    lda #col
    jsr print_at
}

// ─── Single character ────────────────────────────────────────

// PrintChar(sc): write one screen code to current cursor position.
.macro PrintChar(sc) {
    lda #sc
    jsr print_char
}

// ─── Numeric ─────────────────────────────────────────────────

// PrintHexAt(val, base, row, col): print A as 2-digit hex at position.
.macro PrintHexAtXY(base, row, col) {
    SetPrintCursorXY(base, row, col)
    jsr print_hex
}

// PrintDecAt(lo, hi, base, row, col): print 16-bit value at position.
.macro PrintDecAtXY(lo, hi, base, row, col) {
    SetPrintCursorXY(base, row, col)
    PrintDecimal(lo, hi)
}

// PrintDecByteAtXY: print A (0-255) as decimal at row/col.
.macro PrintDecByteAtXY(base, row, col) {
    sta print_dec_lo
    lda #0
    sta print_dec_hi
    SetPrintCursorXY(base, row, col)
    jsr print_decimal
}

// ─── Score display ───────────────────────────────────────────

// PrintScoreAt(base, row, col): print score_str without leading zeros.
.macro PrintScoreAt(base, row, col) {
    DrawScore(base, row, col)
}

// ─── Clear helpers ───────────────────────────────────────────

// ClearLine(base, row): fill row with spaces (screen code 0).
.macro ClearLine(base, row) {
    ldy #39
    lda #0
!:
    sta base + row*40,y
    dey
    bpl !-
}

// ClearText(base, rows): fill 'rows' text rows with spaces.
.macro ClearText(base, rows) {
    ldy #(rows*40 - 1)
    lda #0
!:
    sta base,y
    dey
    bpl !-
}

//////////////////////////////////////////////////////////////////
