#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL — Screen system helpers
//
// SC(c)      compile-time function: ATASCII char → screen code
// PutChar    write one char to (line,y) and advance Y
// PutSpc     write a space  to (line,y) and advance Y
//////////////////////////////////////////////////////////////////

// screen_code = ATASCII_char - $20  (valid for $20-$5F)
// Space=0, '0'=$10, 'A'=$21, ':'=$1A.
// $FF is used as the null terminator in Atari screen-code strings
// because screen code 0 = space and cannot serve as a terminator.
.function SC(c) { .return c - $20; }

// ─── PutChar ─────────────────────────────────────────────────
// Emit:  LDA #SC(c) / STA line,Y / INY
// c    = character literal, e.g. 'A'
// line = absolute address constant, e.g. TXT_LINE0
.macro PutChar(c, line) {
    lda #SC(c)
    sta line,y
    iny
}

// ─── PutSpc ──────────────────────────────────────────────────
// Write space (screen code 0) to (line,Y) and advance Y.
.macro PutSpc(line) {
    lda #0
    sta line,y
    iny
}
