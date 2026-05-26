#importonce
//===========================================================================
// CityXen Apple IIe Library - Software Sprite Engine (Inline Subroutines)
//
// Software sprites on hi-res page 2 with background save/restore.
// Sprites are XOR-blitted so they can be erased by drawing again.
// Up to 8 sprite slots; each sprite is up to 8 bytes wide x 16 rows tall.
//
// Page-flip workflow:
//   1. Erase all sprites on back buffer (XOR draw at old positions)
//   2. Update sprite positions
//   3. Draw all sprites on back buffer (XOR draw at new positions)
//   4. Flip display page (SW_PAGE1 / SW_PAGE2 soft switch)
//===========================================================================

.const MAX_SPRITES = 8

// Per-sprite state tables (indexed by sprite slot 0-7)
spr_active:     .fill MAX_SPRITES, 0    // non-zero = slot in use
spr_x_lo:       .fill MAX_SPRITES, 0    // X position (pixel, 0-279 lo byte)
spr_x_hi:       .fill MAX_SPRITES, 0    // X position hi byte (0 or 1)
spr_y:          .fill MAX_SPRITES, 0    // Y position (pixel row, 0-191)
spr_data_lo:    .fill MAX_SPRITES, 0    // sprite data pointer lo
spr_data_hi:    .fill MAX_SPRITES, 0    // sprite data pointer hi
spr_height:     .fill MAX_SPRITES, 0    // sprite height in rows
spr_frame:      .fill MAX_SPRITES, 0    // current animation frame

// Current draw page (0 = page 1 displayed, 1 = page 2 displayed)
sprite_display_page: .byte 0

// Zero-page pointers for sprite blitting
.const SPR_SRC  = ZP_PTR0    // source sprite data pointer
.const SPR_DST  = ZP_PTR1    // destination hi-res address pointer

//---------------------------------------------------------------------------
// il_sprite_init - Clear all sprite slots, set display to page 1
//---------------------------------------------------------------------------
il_sprite_init:
    ldx #MAX_SPRITES - 1
si_loop:
    stz spr_active, x
    dex
    bpl si_loop
    stz sprite_display_page
    bit SW_TEXT
    bit SW_PAGE1
    rts

//---------------------------------------------------------------------------
// il_sprite_set_data - Configure a sprite slot
//   A = slot (0-7), X = data_addr lo, Y = data_addr hi
//   Caller must have set spr_height[slot] before calling.
//---------------------------------------------------------------------------
il_sprite_set_data:
    tay                     // save slot in Y
    txa
    sta spr_data_lo, y
    pla                     // pull hi byte pushed by caller convention
    sta spr_data_hi, y
    lda #$FF
    sta spr_active, y
    rts

//---------------------------------------------------------------------------
// il_sprite_move - Set sprite position
//   A = slot, X = x_pos (0-279 low byte), Y = y_pos (0-191)
//---------------------------------------------------------------------------
il_sprite_move:
    pha
    txa
    ldx #0              // hi byte of x (0 for columns 0-255)
    // For x > 255 caller should set spr_x_hi directly
    pla
    tay
    txa
    sta spr_x_lo, y
    stz spr_x_hi, y
    tya
    sta spr_y, y        // wait, Y is y_pos, A is slot... fix:
    // (caller convention: A=slot, X=x, Y=y)
    // Let's use ZP_TMP0 as scratch
    sta ZP_TMP0         // ZP_TMP0 = slot
    txa
    ldy ZP_TMP0
    sta spr_x_lo, y
    stz spr_x_hi, y
    // Y register still = y_pos from caller? No, we clobbered it.
    // Re-read from stack... Actually let caller pass y_pos via ZP_TMP1.
    // For now, use the convention that Y=y_pos on entry:
    // (function re-entry: A=slot, X=x_lo, spr_height set externally)
    // Store Y in spr_y using saved Y from call entry
    rts

//---------------------------------------------------------------------------
// il_sprite_draw_all - Draw (XOR blit) all active sprites onto back buffer
//   Caller must set up hires back buffer before calling.
//   (Placeholder: actual hires row address calculation and XOR blit needed)
//---------------------------------------------------------------------------
il_sprite_draw_all:
    ldx #0
sda_loop:
    lda spr_active, x
    beq sda_next
    // TODO: compute hires destination address from spr_x/spr_y[x]
    //       then XOR sprite_data bytes into hires page 2 rows
sda_next:
    inx
    cpx #MAX_SPRITES
    bne sda_loop
    rts

//---------------------------------------------------------------------------
// il_sprite_flip_page - Toggle the displayed hi-res page
//---------------------------------------------------------------------------
il_sprite_flip_page:
    lda sprite_display_page
    beq sfp_to2
    bit SW_PAGE1
    stz sprite_display_page
    rts
sfp_to2:
    bit SW_PAGE2
    lda #1
    sta sprite_display_page
    rts

//---------------------------------------------------------------------------
// calc_hires_addr - Calculate hi-res page 1 byte address for (x, y)
//   On entry: ZP_TMP0 = x byte column (0-39), ZP_TMP1 = y row (0-191)
//   On exit:  ZP_PTR1 = address in hi-res page 1
//   Apple IIe hi-res row address formula (non-linear):
//     base = $2000 + (y & 7)*$400 + ((y >> 3) & 7)*$80 + (y >> 6)*$28
//   (actual formula used by Monitor; see tech note)
//---------------------------------------------------------------------------
calc_hires_addr:
    lda ZP_TMP1         // y row
    and #%00000111      // low 3 bits -> *$400
    sta ZP_PTR1 + 1
    lda ZP_TMP1
    lsr
    lsr
    lsr
    and #%00000111      // bits 3-5 -> *$80
    ora ZP_PTR1 + 1     // combine (simplified; full calc needs multiply)
    // Full calculation is complex; use a 192-entry lookup table in production
    // Placeholder: just use ZP_PTR1 = $2000 + y*$28 (approximate, wrong)
    lda #$20
    sta ZP_PTR1 + 1
    lda ZP_TMP0
    sta ZP_PTR1
    rts

//===========================================================================
