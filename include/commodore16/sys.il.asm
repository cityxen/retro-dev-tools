//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — System Utilities
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Provides:
//   a_reg / x_reg / y_reg / tmp_1 / tmp_2 / tmp_3  — scratch storage
//   SaveRegs() / LoadRegs()   — save/restore A,X,Y to scratch bytes
//   no_subroutine             — empty JSR target (just RTS)
//   wait_vbl                  — wait for raster line change
//
// TED raster counter: TED_RASTER_LO ($FF1D, read-only low byte).
// Full 9-bit raster: bit 8 in TED_CONTROL1 ($FF06) bit 7.
//////////////////////////////////////////////////////////////////

#importonce

/////////////////////////////////////////////
// Scratch registers
a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
tmp_1:  .byte 0
tmp_2:  .byte 0
tmp_3:  .byte 0

.macro SaveRegs() {
    sta a_reg
    stx x_reg
    sty y_reg
}

.macro LoadRegs() {
    lda a_reg
    ldx x_reg
    ldy y_reg
}

/////////////////////////////////////////////
// No-op subroutine — useful as an unset hook target
no_subroutine:
    rts

/////////////////////////////////////////////
// wait_vbl: spin until TED raster line counter ($FF1D) changes.
// Provides loose synchronization (~1 scanline resolution).
// For 60Hz frame sync, use the timer system instead.
// Trashes A. Preserves X, Y.
wait_vbl:
    lda TED_RASTER_LO    // sample current raster position
wv_loop:
    cmp TED_RASTER_LO    // wait until it changes
    beq wv_loop
    rts
