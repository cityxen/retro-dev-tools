#importonce
//===========================================================================
// CityXen Apple IIe Library - Software Sprite Management
//
// The Apple IIe has NO hardware sprites. This module provides a software
// sprite system using hi-res page flipping and XOR blitting:
//   - Sprites drawn on hi-res page 2 (or buffered in $4000-$5FFF)
//   - Background saved/restored per sprite bounding box
//   - Flip between page 1 / page 2 for flicker-free animation
//
// Maximum sprites and complexity depend heavily on sprite size and count.
// For small sprites (8x16 pixels), 4-6 sprites at 60fps is feasible.
//
// See sprite.il.asm for implementation.
//===========================================================================

#import "sprite.il.asm"
// #import "sprite_obj.il.asm"     // Uncomment for multi-sprite object system

//---------------------------------------------------------------------------
// InitSoftSprites - Initialize the software sprite engine
//   Clears sprite tables, sets up pointers to background save buffer.
//   Must be called once before using any other sprite macros.
//---------------------------------------------------------------------------
.macro InitSoftSprites() {
    jsr il_sprite_init
}

//---------------------------------------------------------------------------
// SetSpriteData - Point the sprite engine to a sprite's pixel data
// Usage: SetSpriteData(sprite_slot, data_addr)
//   sprite_slot: 0-based sprite index (0-7)
//   data_addr:   address of 8-byte-wide sprite rows (variable height)
//---------------------------------------------------------------------------
.macro SetSpriteData(sprite_slot, data_addr) {
    lda #sprite_slot
    ldx #<data_addr
    ldy #>data_addr
    jsr il_sprite_set_data
}

//---------------------------------------------------------------------------
// MoveSprite - Set a sprite's position
// Usage: MoveSprite(sprite_slot, x_pos, y_pos)
//   x_pos: 0-279 (hi-res pixel column)
//   y_pos: 0-191 (hi-res pixel row)
//---------------------------------------------------------------------------
.macro MoveSprite(sprite_slot, x_pos, y_pos) {
    lda #sprite_slot
    ldx #x_pos
    ldy #y_pos
    jsr il_sprite_move
}

//---------------------------------------------------------------------------
// DrawSprites - Draw all active sprites onto the hi-res back buffer
//   Call once per frame; then flip pages to display.
//---------------------------------------------------------------------------
.macro DrawSprites() {
    jsr il_sprite_draw_all
}

//---------------------------------------------------------------------------
// FlipPage - Swap display between hi-res page 1 and page 2
//---------------------------------------------------------------------------
.macro FlipPage() {
    jsr il_sprite_flip_page
}

//===========================================================================
