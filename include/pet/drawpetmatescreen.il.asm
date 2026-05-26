//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Draw PetMate Screen — Inline Library
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// PET screen RAM is at $8000, 40x25 characters, no color RAM.
// A PetMate screen file is: 2 bytes (border/bg color, ignored on PET) +
// 1000 bytes of screen data (40x25).
//
// DrawPetMateScreen(screen_name) copies screen_name+2 ... +1001 to $8000.
//
// Implementation uses PETMATE_PTR ($fb ZP) as a working pointer advancing
// through 4 pages. PETMATE_PTR is advanced +2 on entry (skip color header)
// then its high byte incremented for each 256-byte pass.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

.const PETMATE_PTR = $fb     // ZP pointer used by draw_petmate_screen (2 bytes: $fb/$fc)

.macro DrawPetMateScreen(screen_name) {
    lda #<screen_name
    sta PETMATE_PTR
    lda #>screen_name
    sta PETMATE_PTR+1
    jsr draw_petmate_screen
}

//////////////////////////////////////////////////////////////////////////////////////
// draw_petmate_screen — copy PetMate screen data to PET screen RAM ($8000)
// PETMATE_PTR must point to screen data start (the macro sets it).
// Destroys PETMATE_PTR, A, X, Y.

draw_petmate_screen:
    // Advance PETMATE_PTR by 2 to skip 2-byte color header
    clc
    lda PETMATE_PTR
    adc #2
    sta PETMATE_PTR
    bcc dps_no_carry
    inc PETMATE_PTR+1
dps_no_carry:

    // Pass 1: source[0..255]   → SCREEN_RAM[0..255]   ($8000-$80FF)
    ldy #0
dps_p1:
    lda (PETMATE_PTR), y
    sta SCREEN_RAM, y
    iny
    bne dps_p1

    inc PETMATE_PTR+1          // source advances to next 256-byte page

    // Pass 2: source[256..511]  → SCREEN_RAM[256..511]  ($8100-$81FF)
    ldy #0
dps_p2:
    lda (PETMATE_PTR), y
    sta SCREEN_RAM+256, y
    iny
    bne dps_p2

    inc PETMATE_PTR+1

    // Pass 3: source[512..767]  → SCREEN_RAM[512..767]  ($8200-$82FF)
    ldy #0
dps_p3:
    lda (PETMATE_PTR), y
    sta SCREEN_RAM+512, y
    iny
    bne dps_p3

    inc PETMATE_PTR+1

    // Pass 4: source[768..999] → SCREEN_RAM[768..999] ($8300-$83E7)
    // Only 232 bytes (1000 - 768); count Y down from 231 to 0 (232 iterations).
    // bpl branches while N=0 (Y >= 0 as signed); exits when dey wraps Y to $FF.
    ldy #231
dps_p4:
    lda (PETMATE_PTR), y
    sta SCREEN_RAM+768, y
    dey
    bpl dps_p4

    rts
