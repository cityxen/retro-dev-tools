//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
// C128-Specific Utilities: 2MHz mode, VDC 80-column, MMU banking
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

//////////////////////////////////////////////////////////////////
// 2MHz MODE
//
// Usage:
//   Enable2MHz()   — switch CPU to 2MHz (FAST mode)
//   Disable2MHz()  — switch CPU back to 1MHz (SLOW mode)
//
// Note: 2MHz mode disables the VIC-IIe's ability to fetch sprite/char
// data during the CPU's bus cycles. This causes display glitches unless
// you also stop the VIC (e.g., blank screen) or carefully manage timing.
// Safe to use during disk I/O or non-display processing.
//

.macro Enable2MHz() {
    lda C128_2MHZ_REG
    ora #$01
    sta C128_2MHZ_REG
}

.macro Disable2MHz() {
    lda C128_2MHZ_REG
    and #$FE
    sta C128_2MHZ_REG
}

//////////////////////////////////////////////////////////////////
// VDC (80-Column Chip) ACCESS
//
// The VDC is accessed via two registers:
//   VDC_ADDRESS ($D600): write internal register index, read status (bit7=ready)
//   VDC_DATA    ($D601): read/write data for the selected internal register
//
// Always wait for the VDC to be ready (bit 7 of VDC_ADDRESS = 1) before
// reading or writing VDC_DATA.
//
// Usage examples:
//
//   // Write a value to VDC register 26 (foreground/background color):
//   VDC_Write(VDC_FORE_BACK_COLOR, %00000000)   // black fg, black bg
//
//   // Read a value from VDC register 28 (character base address):
//   VDC_Read(VDC_CHAR_BASE_ADDR)   // result in A
//
//   // Low-level subroutine interface (when A=value, X=register index):
//   ldx #VDC_FORE_BACK_COLOR
//   lda #%00010000
//   jsr vdc_write
//
//   // Block-fill 80-col screen RAM with a character (e.g., space = $20):
//   VDC_FillScreen($20, $0000, 2000)
//
//////////////////////////////////////////////////////////////////

.macro VDC_WaitReady() {
!:
    bit VDC_ADDRESS
    bpl !-
}

// Write value to a VDC internal register.
// X = register index, A = value to write.
.macro VDC_Write(reg, value) {
    ldx #reg
    lda #value
    jsr vdc_write
}

// Read a VDC internal register into A.
// X = register index, result in A.
.macro VDC_Read(reg) {
    ldx #reg
    jsr vdc_read
}

// Low-level VDC write subroutine.
// In: X = register index, A = value
// Clobbers: none (preserves A, X)
vdc_write:
    stx VDC_ADDRESS
!:
    bit VDC_ADDRESS
    bpl !-
    sta VDC_DATA
    rts

// Low-level VDC read subroutine.
// In: X = register index
// Out: A = value
vdc_read:
    stx VDC_ADDRESS
!:
    bit VDC_ADDRESS
    bpl !-
    lda VDC_DATA
    rts

//////////////////////////////////////////////////////////////////
// VDC_SetCursorPos
// Set the VDC cursor to (col, row) in 80-column mode.
// col: 0-79, row: 0-24
// Uses vdc_write internally.
.macro VDC_SetCursorPos(col, row) {
    lda #<(row * 80 + col)
    ldx #VDC_CURSOR_ADDR_LO
    jsr vdc_write
    lda #>(row * 80 + col)
    ldx #VDC_CURSOR_ADDR_HI
    jsr vdc_write
}

//////////////////////////////////////////////////////////////////
// VDC_SetUpdateAddr
// Point the VDC update address (used by block fill/copy) to a position.
// addr: 16-bit VDC RAM address (0 = top of 80-col screen RAM)
.macro VDC_SetUpdateAddr(addr) {
    lda #<addr
    ldx #VDC_UPD_ADDR_LO
    jsr vdc_write
    lda #>addr
    ldx #VDC_UPD_ADDR_HI
    jsr vdc_write
}

//////////////////////////////////////////////////////////////////
// VDC_WriteChar
// Write a single character at the current VDC update address,
// then advance the update pointer automatically.
// In: A = character to write
.macro VDC_WriteChar(ch) {
    lda #ch
    jsr vdc_write_char
}

vdc_write_char:
    pha
    ldx #VDC_DATA_REGISTER
    stx VDC_ADDRESS
!:
    bit VDC_ADDRESS
    bpl !-
    pla
    sta VDC_DATA
    rts

//////////////////////////////////////////////////////////////////
// VDC_FillBlock
// Fill a region of VDC RAM with a value (hardware block fill).
// dest_addr: starting VDC RAM address (16-bit)
// fill_byte: byte value to fill with
// count: number of bytes (16-bit, 1-65535; 0 = 256 due to 8-bit hardware counter)
//
// Note: count is loaded as a byte. For fills > 255 bytes, call multiple times.
// The VDC's block fill uses register 31 (VDC_DATA_REGISTER) as the fill value
// and register 30 (VDC_WORD_COUNT) as the count (in characters, minus 1).
//
.macro VDC_FillBlock(dest_addr, fill_byte, count) {
    // Set update address
    lda #>dest_addr
    ldx #VDC_UPD_ADDR_HI
    jsr vdc_write
    lda #<dest_addr
    ldx #VDC_UPD_ADDR_LO
    jsr vdc_write
    // Set fill value in register 31
    lda #fill_byte
    ldx #VDC_DATA_REGISTER
    jsr vdc_write
    // Set count (count - 1 for hardware) in register 30
    lda #(count - 1)
    ldx #VDC_WORD_COUNT
    jsr vdc_write
}

//////////////////////////////////////////////////////////////////
// MMU BANKING HELPERS
//
// The C128 MMU allows switching between 16 memory banks.
// Bank 0:  RAM 0 ($0000-$FFFF) — game data / code
// Bank 1:  RAM 1 ($0000-$FFFF) — second 64K of RAM
// Bank 14: I/O ($D000-$DFFF mapped to I/O), KERNAL ROM in upper half
// Bank 15: Default bank (BASIC ROM / KERNAL ROM visible)
//
// The MMU Configuration Register (CR) at $FF00 controls the current bank.
// Common CR values:
//   $3F = Bank 0: all RAM (ROM off, I/O off)
//   $7F = Bank 1: all RAM (ROM off, I/O off)
//   $0E = Bank 14: RAM 0 low + I/O + KERNAL high (typical for ML games)
//   $00 = Bank 15: BASIC + I/O + KERNAL (power-on default)
//
// Saving and restoring the bank is done by pushing/popping to the
// pre-configuration registers (LCRA-LCRD at $FF01-$FF04).
//

// Switch to a bank by writing its CR value.
// Typical: SwitchToBank($3F) for all-RAM bank 0.
.macro SwitchToBank(cr_value) {
    lda #cr_value
    sta MMU_CR
}

// Save current MMU config to LCRA, execute code, restore.
// Useful pattern: save config, switch bank, do work, restore.
// LCRA ($FF01) is one of four pre-configuration save slots.
.macro MMU_SaveConfig() {
    lda MMU_CR
    sta MMU_LCRA
}

.macro MMU_RestoreConfig() {
    lda MMU_LCRA
    sta MMU_CR
}

//////////////////////////////////////////////////////////////////
// SWAPPER helper
// Switch between 40-col (VIC) and 80-col (VDC) display.
// The KERNAL_SWAPPER routine toggles which screen is active.
.macro SwitchDisplayMode() {
    jsr KERNAL_SWAPPER
}
