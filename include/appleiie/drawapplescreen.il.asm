#importonce
//===========================================================================
// CityXen Apple IIe Library - Draw Apple Screen (Inline Subroutines)
//
// Restores a 40x24 text screen from a compact data block.
// Screen data format:
//   Bytes $000-$3BF : 960 bytes of screen character data (text page layout)
//   Bytes $3C0-$3C0 : border color (lo-res color nibble, stored for ref)
//   Bytes $3C1-$3C1 : background color (unused on Apple IIe text mode)
//
// Data can be produced by a screen-capture utility that reads text page 1
// ($0400-$07BF, non-linear rows) and serializes it in row-major order.
//===========================================================================

.const APPLESCREEN_PTR = ZP_PTR2   // zero-page pointer used by draw routine ($1A/$1B)

// Row base address table (24 rows, each a 16-bit address, lo/hi pairs)
// Used by draw_apple_screen to write rows in correct order
applescreen_row_lo:
    .byte <$0400, <$0480, <$0500, <$0580, <$0600, <$0680, <$0700, <$0780
    .byte <$0428, <$04A8, <$0528, <$05A8, <$0628, <$06A8, <$0728, <$07A8
    .byte <$0450, <$04D0, <$0550, <$05D0, <$0650, <$06D0, <$0750, <$07D0

applescreen_row_hi:
    .byte >$0400, >$0480, >$0500, >$0580, >$0600, >$0680, >$0700, >$0780
    .byte >$0428, >$04A8, >$0528, >$05A8, >$0628, >$06A8, >$0728, >$07A8
    .byte >$0450, >$04D0, >$0550, >$05D0, >$0650, >$06D0, >$0750, >$07D0

//---------------------------------------------------------------------------
// DrawAppleScreen - Macro wrapper
// Usage: DrawAppleScreen(data_addr)
//   data_addr: address of 960-byte screen data block (row-major order)
//---------------------------------------------------------------------------
.macro DrawAppleScreen(data_addr) {
    lda #<data_addr
    sta APPLESCREEN_PTR
    lda #>data_addr
    sta APPLESCREEN_PTR + 1
    jsr draw_apple_screen
}

//---------------------------------------------------------------------------
// draw_apple_screen - Subroutine: copy row-major screen data to text page 1
//   On entry: APPLESCREEN_PTR (ZP) -> source data (960 bytes, row-major)
//   Trashes: A, X, Y, ZP_PTR3
//---------------------------------------------------------------------------
draw_apple_screen:
    ldy #0                  // row index
das_row:
    // Set destination = applescreen_row_lo[y] / hi[y]
    lda applescreen_row_lo, y
    sta ZP_PTR3
    lda applescreen_row_hi, y
    sta ZP_PTR3 + 1

    // Copy 40 bytes from source to this row
    ldx #0
das_col:
    lda (APPLESCREEN_PTR), x
    sta (ZP_PTR3), x
    inx
    cpx #SCREEN_COLS
    bne das_col

    // Advance source pointer by 40
    clc
    lda APPLESCREEN_PTR
    adc #SCREEN_COLS
    sta APPLESCREEN_PTR
    bcc das_no_carry
    inc APPLESCREEN_PTR + 1
das_no_carry:

    iny
    cpy #SCREEN_ROWS
    bne das_row
    rts

//===========================================================================
