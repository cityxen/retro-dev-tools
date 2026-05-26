#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Print hex byte
//
// print_hex: print A as 2-digit uppercase hex to (ZP_PCUR).
//            Advances cursor by 2.  Trashes A, X.
//
// PrintHex()          — macro JSR wrapper
// PrintHexAt(v, addr) — macro: set cursor, print compile-time value
//////////////////////////////////////////////////////////////////

.macro PrintHex() {
    jsr print_hex
}

.macro PrintHexAt(val, addr) {
    SetPrintCursor(addr)
    lda #val
    jsr print_hex
}

// print_hex ────────────────────────────────────────────────────
print_hex:
    pha
    lsr
    lsr
    lsr
    lsr
    tax
    lda ph_table,x
    jsr print_char
    pla
    and #$0F
    tax
    lda ph_table,x
    jsr print_char
    rts

// Atari screen codes for 0-9 (SC('0')=$10 .. SC('9')=$19)
// and A-F (SC('A')=$21 .. SC('F')=$26).
ph_table:
.byte SC('0'),SC('1'),SC('2'),SC('3'),SC('4')
.byte SC('5'),SC('6'),SC('7'),SC('8'),SC('9')
.byte SC('A'),SC('B'),SC('C'),SC('D'),SC('E'),SC('F')
