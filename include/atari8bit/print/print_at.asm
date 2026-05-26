#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Core print routines
//
// print_at:   write $FF-terminated screen-code string to screen RAM.
//             In:  ZP_PTR_LO/HI  = string pointer
//                  ZP_PCUR_LO/HI = destination address in screen RAM
//             Trashes A, Y.
//
// print_char: write one screen-code byte to (ZP_PCUR), advance cursor.
//             In:  A = screen code to write
//             Trashes nothing else.
//
// SetPrintCursor(addr)      — macro: set ZP_PCUR to compile-time address
// SetPrintCursorXY(base,r,c) — macro: set ZP_PCUR to base + r*40 + c
// PrintAt(str, addr)        — macro: set ZP_PTR + ZP_PCUR, JSR print_at
//////////////////////////////////////////////////////////////////

// SetPrintCursor: point the print cursor at a compile-time address.
.macro SetPrintCursor(addr) {
    lda #<addr
    sta ZP_PCUR_LO
    lda #>addr
    sta ZP_PCUR_HI
}

// SetPrintCursorXY: point cursor at row r, column c of a text screen
// whose first byte is at compile-time constant `base`.
.macro SetPrintCursorXY(base, r, c) {
    lda #<(base + r*40 + c)
    sta ZP_PCUR_LO
    lda #>(base + r*40 + c)
    sta ZP_PCUR_HI
}

// PrintAt: print string at address — both resolved at assemble time.
.macro PrintAt(str, addr) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    lda #<addr
    sta ZP_PCUR_LO
    lda #>addr
    sta ZP_PCUR_HI
    jsr print_at
}

// PrintAtXY: print string at row/col of a text screen base address.
.macro PrintAtXY(str, base, r, c) {
    lda #<str
    sta ZP_PTR_LO
    lda #>str
    sta ZP_PTR_HI
    lda #<(base + r*40 + c)
    sta ZP_PCUR_LO
    lda #>(base + r*40 + c)
    sta ZP_PCUR_HI
    jsr print_at
}

// print_at ─────────────────────────────────────────────────────
// Write $FF-terminated Atari screen-code string to (ZP_PCUR).
// ZP_PTR_LO/HI → string.  ZP_PCUR_LO/HI → destination.
// Y is used as offset (starts at 0); stops before 256 chars.
print_at:
    ldy #0
pat_loop:
    lda (ZP_PTR_LO),y
    cmp #$FF
    beq pat_done
    sta (ZP_PCUR_LO),y
    iny
    bne pat_loop
pat_done:
    rts

// print_char ───────────────────────────────────────────────────
// Write screen code in A to (ZP_PCUR) and advance cursor by 1.
print_char:
    ldy #0
    sta (ZP_PCUR_LO),y
    inc ZP_PCUR_LO
    bne !+
    inc ZP_PCUR_HI
!:
    rts
