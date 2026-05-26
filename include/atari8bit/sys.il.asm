#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — System Utilities
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Provides:
//   a_reg / x_reg / y_reg / tmp_1 / tmp_2 / tmp_3  — scratch storage
//   SaveRegs() / LoadRegs()   — save/restore A,X,Y to scratch bytes
//   no_subroutine             — empty JSR target (just RTS)
//
// NOTE: wait_vbl is defined in timers.il.asm (RTCLOK+2 polling).
//////////////////////////////////////////////////////////////////

a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
tmp_1:  .byte 0
tmp_2:  .byte 0
tmp_3:  .byte 0

// Save A, X, Y to scratch bytes.
.macro SaveRegs() {
    sta a_reg
    stx x_reg
    sty y_reg
}

// Restore A, X, Y from scratch bytes.
.macro LoadRegs() {
    lda a_reg
    ldx x_reg
    ldy y_reg
}

// No-op subroutine — useful as a JSR target when a hook is unset.
no_subroutine:
    rts

//////////////////////////////////////////////////////////////////
