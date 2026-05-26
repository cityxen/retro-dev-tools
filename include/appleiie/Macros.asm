#importonce
//===========================================================================
// CityXen Apple IIe Library - Macros
// KickAssembler syntax; target CPU: 65C02
//===========================================================================

//---------------------------------------------------------------------------
// CityXenUpstart - Generate an AppleSoft BASIC stub that CALLs the ML entry
//   Place at BASIC program start address (typically $0801 for DOS 3.3 or
//   $0803 for ProDOS binary loaded via BASIC).
//
// Usage: CityXenUpstart(entry_addr)
//---------------------------------------------------------------------------
.macro CityXenUpstart(entry_addr) {
    .byte $00,$08           // next-line pointer (BASIC fills this in)
    .word 10                // line number 10
    .byte $B7               // AppleSoft CALL token
    .word entry_addr        // target address
    .byte $00               // end of line
    .byte $00, $00          // end of program
}

//---------------------------------------------------------------------------
// ClearScreen - Clear text page 1 to spaces, home cursor
//---------------------------------------------------------------------------
.macro ClearScreen() {
    jsr HOME
}

//---------------------------------------------------------------------------
// ClearScreenB - Fill all 1024 bytes of text page 1 with a single character
// Usage: ClearScreenB(fill_char)
//   fill_char should include CHR_NORMAL offset if using ASCII (e.g. ' ' | $80)
//---------------------------------------------------------------------------
.macro ClearScreenB(fill_char) {
    lda #fill_char
    ldx #0
csb_loop:
    sta SCREEN_PAGE1,        x
    sta SCREEN_PAGE1 + $100, x
    sta SCREEN_PAGE1 + $200, x
    sta SCREEN_PAGE1 + $300, x
    inx
    bne csb_loop
}

//---------------------------------------------------------------------------
// SetTextMode - Switch display to 40-column text, page 1
//---------------------------------------------------------------------------
.macro SetTextMode() {
    bit SW_TEXT
    bit SW_PAGE1
}

//---------------------------------------------------------------------------
// SetLoRes - Lo-res graphics, mixed (4 text lines at bottom), page 1
//---------------------------------------------------------------------------
.macro SetLoRes() {
    bit SW_GRAPHICS
    bit SW_LORES
    bit SW_MIXED
    bit SW_PAGE1
}

//---------------------------------------------------------------------------
// SetHiRes - Hi-res graphics, mixed (4 text lines at bottom), page 1
//---------------------------------------------------------------------------
.macro SetHiRes() {
    bit SW_GRAPHICS
    bit SW_HIRES
    bit SW_MIXED
    bit SW_PAGE1
}

//---------------------------------------------------------------------------
// SetHiResFull - Hi-res full screen (no text rows)
//---------------------------------------------------------------------------
.macro SetHiResFull() {
    bit SW_GRAPHICS
    bit SW_HIRES
    bit SW_FULLSCR
    bit SW_PAGE1
}

//---------------------------------------------------------------------------
// PokeString - Write null-terminated string to screen at (col, row)
//   Copies string via il_poke_string subroutine (in CityXenLibCode.asm).
//   Characters are OR'd with CHR_NORMAL ($80) for normal video.
//
// Usage: PokeString(col, row, string_addr)
//---------------------------------------------------------------------------
.macro PokeString(col, row, string_addr) {
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC             // update $28/$29 base for chosen row
    lda #<string_addr
    sta ZP_PTR0
    lda #>string_addr
    sta ZP_PTR0 + 1
    jsr il_poke_string
}

//---------------------------------------------------------------------------
// PokeStringColor - Write string in inverse or flash video
// Usage: PokeStringColor(col, row, string_addr, chr_offset)
//   chr_offset: CHR_NORMAL ($80), CHR_INVERSE ($00), or CHR_FLASH ($40)
//---------------------------------------------------------------------------
.macro PokeStringColor(col, row, string_addr, chr_offset) {
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC
    lda #<string_addr
    sta ZP_PTR0
    lda #>string_addr
    sta ZP_PTR0 + 1
    lda #chr_offset
    sta ZP_TMP0
    jsr il_poke_string_color
}

//---------------------------------------------------------------------------
// ReadKeyJSR - Wait for keypress, return ASCII in A (high bit clear)
//---------------------------------------------------------------------------
.macro ReadKeyJSR() {
    jsr il_get_key
}

//---------------------------------------------------------------------------
// ReadKeyJMP - Wait for keypress, then JMP to label
//---------------------------------------------------------------------------
.macro ReadKeyJMP(target_label) {
    jsr il_get_key
    jmp target_label
}

//---------------------------------------------------------------------------
// ReadJoyJSR - Sample joystick 1, return direction flags in A
//   Flags: JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT | JOY_FIRE | JOY_FIRE2
//---------------------------------------------------------------------------
.macro ReadJoyJSR() {
    jsr il_get_joy
}

//---------------------------------------------------------------------------
// ReadJoyJMP - Sample joystick 1, then JMP to label
//---------------------------------------------------------------------------
.macro ReadJoyJMP(target_label) {
    jsr il_get_joy
    jmp target_label
}

//---------------------------------------------------------------------------
// zp_str - Load a 16-bit address into a zero-page pointer pair
// Usage: zp_str(zp_lo_addr, target_addr)
//---------------------------------------------------------------------------
.macro zp_str(zp_lo_addr, target_addr) {
    lda #<target_addr
    sta zp_lo_addr
    lda #>target_addr
    sta zp_lo_addr + 1
}

//---------------------------------------------------------------------------
// SetCursor - Position cursor at (col, row) without printing anything
//---------------------------------------------------------------------------
.macro SetCursor(col, row) {
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC
}

//---------------------------------------------------------------------------
// PrintAt - Print a string (via Monitor COUT) at screen position (col, row)
//   String must be null-terminated, chars stored with high bit SET ($80+).
//   Uses il_print subroutine.
//---------------------------------------------------------------------------
.macro PrintAt(col, row, string_addr) {
    lda #col
    sta CURSOR_CH
    lda #row
    sta CURSOR_CV
    jsr BASCALC
    lda #<string_addr
    sta ZP_PTR0
    lda #>string_addr
    sta ZP_PTR0 + 1
    jsr il_print
}

//===========================================================================
