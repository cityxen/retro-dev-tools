#importonce
//===========================================================================
// CityXen Apple IIe Library - Calculate Text Screen Address
//
// The Apple IIe text screen uses a non-linear, interleaved row layout.
// This is very different from the C64's simple linear $0400 + y*40 + x.
//
// Apple IIe text page 1 row base addresses are computed as:
//   base = $0400 + (row & 7)*$80 + ((row >> 3)*$28)
//
// Equivalently, the row address table applescreen_row_lo/hi in
// drawapplescreen.il.asm can be used as a lookup.
//
// This module provides a runtime calculation subroutine.
//===========================================================================

//---------------------------------------------------------------------------
// il_calc_screen_pos - Calculate text screen address for (col, row)
//   On entry: A = column (0-39), X = row (0-23)
//   On exit:  ZP_PTR0 = screen address (lo/hi)
//             Y = column (0-39, for indexed store)
//   Trashes: A, X, ZP_TMP0
//
// Formula:
//   row_group   = row >> 3          (0-2, which group of 8 rows)
//   row_in_grp  = row & 7           (0-7, row within group)
//   base_hi     = $04 + row_in_grp  (page $04 + offset for this sub-row)
//   base_lo     = row_group * $28 + col
//   actual_addr = (base_hi << 8) | base_lo
//---------------------------------------------------------------------------
il_calc_screen_pos:
    sta ZP_TMP0         // save column
    tay                 // Y = column

    txa                 // A = row
    and #$07            // row_in_grp (bits 0-2)
    clc
    adc #$04            // page $04-$0B
    sta ZP_PTR0 + 1     // high byte of address

    txa                 // A = row again
    lsr
    lsr
    lsr                 // A = row >> 3  (0, 1, or 2)
    // Multiply by $28 (40):
    // A * 40 = A * 32 + A * 8
    sta ZP_TMP1
    asl
    asl
    asl                 // * 8
    sta ZP_PTR0
    lda ZP_TMP1
    asl
    asl
    asl
    asl
    asl                 // * 32
    clc
    adc ZP_PTR0
    clc
    adc ZP_TMP0         // + column
    sta ZP_PTR0         // low byte of address
    rts

//---------------------------------------------------------------------------
// CalcScreenPos - Convenience macro
// Usage: CalcScreenPos(col, row)  -> ZP_PTR0 = screen address
//---------------------------------------------------------------------------
.macro CalcScreenPos(col, row) {
    lda #col
    ldx #row
    jsr il_calc_screen_pos
}

//===========================================================================
