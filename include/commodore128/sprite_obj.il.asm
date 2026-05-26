//////////////////////////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
// Sprite Object Management System
//
// Bundles multiple hardware sprites into a single "object" with:
//   - Grouped, non-destructive read-modify-write on VIC-IIe global registers
//     (enable, multicolor, expand X/Y, priority, X-MSB)
//   - Per-sprite X/Y position, color, and sprite-data pointer
//   - Per-sprite animation table with a shared frame timer
//
// NOTE: This module targets 40-column mode (VIC-IIe), which is register-compatible
// with the C64 VIC-II.  For VDC 80-column sprite overlays see c128.il.asm.
//
// ── Object binary format ─────────────────────────────────────────────────────
//   [0] slot_mask    bitmask of HW sprite slots this object owns (bits 0-7)
//   [1] enable_mask  bits to SET   in SPRITE_ENABLE
//   [2] mc_mask      bits to SET   in SPRITE_MULTICOLOR
//   [3] expx_mask    bits to SET   in SPRITE_EXPAND_X
//   [4] expy_mask    bits to SET   in SPRITE_EXPAND_Y
//   [5] pri_mask     bits to SET   in SPRITE_PRIORITY (1=sprite behind bg)
//   [6] msb_mask     bits to SET   in SPRITE_MSB_X   (X position bit 8)
//   [7] anim_speed   ticks between frame advances (0 = static, no animation)
//   [8+] sprite entries, 7 bytes each:
//          slot(1)  xlo(1)  y(1)  color(1)  ptr(1)  anim_lo(1)  anim_hi(1)
//   [$FF] entry-list terminator
//
// ── State block (SpriteObjState): 9 bytes, one per object instance ───────────
//   [0]   frame_timer         shared tick counter, resets at anim_speed
//   [1-8] frame_index[0..7]   per-entry index into that entry's anim table
//
// ── Private zero-page usage (dedicated, does NOT touch shared library ZP) ────
//   $5c/$5d  sobj_zp_obj   object pointer  (written by macros before JSR)
//   $5e/$5f  sobj_zp_st    state pointer   (written by macros before JSR)
//   $92/$93  sobj_zp_an    anim-table pointer (scratch inside sobj_flush)
//   $94/$95  sobj_zp_mv    move table read ptr
//   $57/$58  sobj_zp_sf    sfx table ptr
//
//   IRQ-only set ($a3-$a8): used ONLY by sobj_tick (called from CIA timer IRQ).
//   $a3/$a4  sobj_tzp_obj  IRQ object ptr
//   $a5/$a6  sobj_tzp_st   IRQ state ptr
//   $a7/$a8  sobj_tzp_an   IRQ anim table scratch
//
//   All ranges are from safe zones documented in Constants.asm.
//   This library does NOT touch zp_tmp ($FB/$FC), zp_ptr_2 ($64/$65).
//
// ── Usage example ─────────────────────────────────────────────────────────────
//
//   // Define a yin-yang spinner on sprite slot 7, animated
//   yin_obj:
//   SpriteObjBegin(%10000000, %10000000, %00000000, %00000000, %00000000, %00000000, %10000000, TIMER_SPRITE_ANIM_SPEED)
//   SpriteObjEntry(7, 98, 148, WHITE, sp_ptr_yin_1, <yin_anim_table, >yin_anim_table)
//   SpriteObjEnd()
//
//   yin_anim_table: .byte sp_ptr_yin_1, sp_ptr_yin_2, sp_ptr_yin_3, $00
//
//   yin_state:
//   SpriteObjState()
//
//   // Apply once to initialise:
//   ApplySpriteObj(yin_obj, yin_state)
//
//   // Call every game frame / IRQ tick:
//   TickSpriteObj(yin_obj, yin_state)
//
// ── Two-sprite player body example ───────────────────────────────────────────
//
//   player_obj:
//   SpriteObjBegin(%00000110, %00000110, %00000110, %00000110, %00000110, %00000000, %00000000, 8)
//   SpriteObjEntry(1, 27, 70, GREEN, sp_ptr_body_left_1,  <body_left_anim,  >body_left_anim)
//   SpriteObjEntry(2, 61, 70, GREEN, sp_ptr_body_right_1, <body_right_anim, >body_right_anim)
//   SpriteObjEnd()
//
//   body_left_anim:  .byte sp_ptr_body_left_1, sp_ptr_body_left_2, sp_ptr_body_left_3, $00
//   body_right_anim: .byte sp_ptr_body_right_1, sp_ptr_body_right_2, sp_ptr_body_right_3, $00
//
//   player_state:
//   SpriteObjState()
//
/////////////////////////////////////////
//
// Here's how to use move and SFX features:
//
// Movement table — called every frame from the main loop after wait_vbl:
//
// attack_move_table:
// SpriteObjMoveEntry(4, 0)    // move right 4px per tick
// SpriteObjMoveEntry(4, 0)
// SpriteObjMoveEntry(4, -2)   // curve up
// SpriteObjMoveEntry(4, -2)
// SpriteObjMoveStop()         // freeze at end
//
// start attack:
// ResetSpriteObjMove()
// each frame:
// TickSpriteObjMove(yin_obj, attack_move_table)
//
//////////////////////////////
//
// SFX table — called every frame from the main loop:
//
// yin_sfx_table:
// SpriteObjSfxEntry(0, 1, SFX_POW)    // play POW on voice 1 at frame 0
// SpriteObjSfxEntry(4, 2, SFX_DING)   // play DING on voice 2 at frame 4
// SpriteObjSfxEnd()
//
// each frame:
// TickSpriteObjSfx(yin_state, yin_sfx_table)
//
// Two things to be aware of: the move table only takes one object at a time
// (the static sobj_mv_offset is shared), so reset it when switching which object
// is moving. And movement is 8-bit X — if a sprite needs to cross X=255, update
// SPRITE_MSB_X manually at the crossing point.
//
// ─────────────────────────────────────────────────────────────────────────────
// https://github.com/cityxen/Commodore128_Programming
//////////////////////////////////////////////////////////////////////////////////////

// Private ZP addresses — two fully-separate sets to prevent IRQ/main-loop races.
//
// MAIN-LOOP set ($5c-$5f, $92-$95): used by sobj_apply, sobj_flush,
//   sobj_disable, sobj_enable, sobj_tick_move, sobj_tick_sfx.
// IRQ set ($a3-$a8): used ONLY by sobj_tick (called from the CIA timer IRQ).
//
// Because sobj_tick (IRQ) and sobj_flush (main loop) run on different ZP
// regions, the CIA IRQ cannot corrupt the pointer pair that sobj_flush is
// currently dereferencing — the crash-after-N-cycles race is eliminated.
//
// All ranges are from the safe zones documented in Constants.asm.
.const sobj_zp_obj = $5c   // 2 bytes: main-loop object ptr   ($5c=lo, $5d=hi)
.const sobj_zp_st  = $5e   // 2 bytes: main-loop state ptr    ($5e=lo, $5f=hi)
.const sobj_zp_an  = $92   // 2 bytes: anim table scratch     ($92=lo, $93=hi)  [flush/apply]
.const sobj_zp_mv  = $94   // 2 bytes: move table read ptr    ($94=lo, $95=hi)
.const sobj_zp_sf  = $57   // 2 bytes: sfx table ptr          ($57=lo, $58=hi)
// IRQ-only ZP set — NEVER written by any main-loop macro or subroutine
.const sobj_tzp_obj = $a3  // 2 bytes: IRQ object ptr         ($a3=lo, $a4=hi)
.const sobj_tzp_st  = $a5  // 2 bytes: IRQ state ptr          ($a5=lo, $a6=hi)
.const sobj_tzp_an  = $a7  // 2 bytes: IRQ anim table scratch ($a7=lo, $a8=hi)

//--------------------------------------------------------------------
// Data-definition macros (assemble-time, create object bytes)
//--------------------------------------------------------------------

// Open a sprite object block.
// All mask arguments use one bit per sprite slot (bit 0 = slot 0).
// slot_mask must be the OR of every slot used by entries in this object.
.macro SpriteObjBegin(slot_mask, en_mask, mc_mask, expx_mask, expy_mask, pri_mask, msb_mask, anim_speed) {
    .byte slot_mask, en_mask, mc_mask, expx_mask, expy_mask, pri_mask, msb_mask, anim_speed
}

// Add one sprite entry with an animation table.
// anim_lo/anim_hi: low/high byte of the table address (<label / >label).
// Set both to 0 for a static (non-animated) entry.
// Animation table: sprite-pointer bytes, terminated by $00 (loops).
.macro SpriteObjEntry(slot, xlo, y, color, ptr, anim_lo, anim_hi) {
    .byte slot, xlo, y, color, ptr, anim_lo, anim_hi
}

// Shorthand for a static (non-animated) sprite entry.
.macro SpriteObjEntryS(slot, xlo, y, color, ptr) {
    .byte slot, xlo, y, color, ptr, 0, 0
}

// Close the entry list.
.macro SpriteObjEnd() {
    .byte $ff
}

// Allocate a 9-byte state block.  Place a label before this in your source.
.macro SpriteObjState() {
    .byte 0,0,0,0,0,0,0,0,0
}

// ── Movement table macros ─────────────────────────────────────────────────────
// One dx/dy pair is consumed per TickSpriteObjMove call.
// dx and dy are signed bytes (-128 … +127).
.macro SpriteObjMoveEntry(dx, dy) {
    .byte dx, dy
}
// Stop at the final position.
.macro SpriteObjMoveStop() {
    .byte $80
}
// Loop back to the start of the table.
.macro SpriteObjMoveLoop() {
    .byte $81
}

// ── Sound-effect table macros ─────────────────────────────────────────────────
// Each entry fires when the first animated entry's frame_index == anim_frame.
// voice: 1, 2, or 3.  sfx_num: any SFX_* constant.
.macro SpriteObjSfxEntry(anim_frame, voice, sfx_num) {
    .byte anim_frame, voice, sfx_num
}
.macro SpriteObjSfxEnd() {
    .byte $ff
}

//--------------------------------------------------------------------
// Runtime macros — load private ZP pointers then JSR
//--------------------------------------------------------------------

// Apply object to VIC-IIe and reset state.  Call once to initialise.
.macro ApplySpriteObj(obj, state) {
    lda #<obj
    sta sobj_zp_obj
    lda #>obj
    sta sobj_zp_obj+1
    lda #<state
    sta sobj_zp_st
    lda #>state
    sta sobj_zp_st+1
    jsr sobj_apply
}

// Advance animation frame counters ONLY.  Safe to call from the IRQ hook.
// Uses the IRQ-only ZP set ($a3-$a8) so it never races with FlushSpriteObj.
// Does NOT write to any VIC-IIe register — no sprite glitches at any raster line.
.macro TickSpriteObj(obj, state) {
    lda #<obj
    sta sobj_tzp_obj
    lda #>obj
    sta sobj_tzp_obj+1
    lda #<state
    sta sobj_tzp_st
    lda #>state
    sta sobj_tzp_st+1
    jsr sobj_tick
}

// Write animated sprite pointers to VIC-IIe.
// Call from the MAIN LOOP after jsr wait_vbl (during VBlank) to avoid sprite glitches.
.macro FlushSpriteObj(obj, state) {
    lda #<obj
    sta sobj_zp_obj
    lda #>obj
    sta sobj_zp_obj+1
    lda #<state
    sta sobj_zp_st
    lda #>state
    sta sobj_zp_st+1
    jsr sobj_flush
}

// Hide all sprites owned by this object (clears enable bits only).
.macro DisableSpriteObj(obj) {
    lda #<obj
    sta sobj_zp_obj
    lda #>obj
    sta sobj_zp_obj+1
    jsr sobj_disable
}

// Show sprites owned by this object (ORs enable_mask into SPRITE_ENABLE).
.macro EnableSpriteObj(obj) {
    lda #<obj
    sta sobj_zp_obj
    lda #>obj
    sta sobj_zp_obj+1
    jsr sobj_enable
}

// Set the color of a single hardware sprite slot directly.
// slot:  hardware sprite number 0-7 (literal constant)
// color: VIC-IIe color value (e.g. WHITE, RED, GREEN …)
.macro SetSpriteObjColor(slot, color) {
    lda #color
    sta SPRITE_0_COLOR + slot
}

// Set sprite color via subroutine.  Load color into A before calling.
// In: A = color value, X = sprite slot (0-7)
.macro SetSpriteObjColorA(slot) {
    ldx #slot
    jsr sobj_set_color
}

// Advance the move table one step and apply (dx,dy) to every sprite slot in obj.
// Call from the main loop after jsr wait_vbl (writes VIC-IIe X/Y registers).
// Reset offset with ResetSpriteObjMove before starting a new path.
.macro TickSpriteObjMove(obj, move_tbl) {
    lda #<obj
    sta sobj_zp_obj
    lda #>obj
    sta sobj_zp_obj+1
    lda #<move_tbl
    sta sobj_mv_tbl_lo
    lda #>move_tbl
    sta sobj_mv_tbl_hi
    jsr sobj_tick_move
}

// Reset movement state to the beginning of the table.
.macro ResetSpriteObjMove() {
    lda #0
    sta sobj_mv_offset
    sta sobj_mv_stopped
}

// Scan the sfx table and play any sound whose anim_frame matches the
// current animation frame of sprite_state.  Safe to call every frame —
// each frame index triggers its sounds exactly once.
.macro TickSpriteObjSfx(sprite_state, sfx_tbl) {
    lda #<sprite_state
    sta sobj_zp_st
    lda #>sprite_state
    sta sobj_zp_st+1
    lda #<sfx_tbl
    sta sobj_zp_sf
    lda #>sfx_tbl
    sta sobj_zp_sf+1
    jsr sobj_tick_sfx
}

// Reset sfx so the next animation cycle will re-trigger sounds.
.macro ResetSpriteObjSfx() {
    lda #$ff
    sta sobj_sfx_last_frame
}

//--------------------------------------------------------------------
// sobj_apply
// Write all object settings to the VIC-IIe; reset the state block.
// In:  sobj_zp_obj ($5c/$5d) → sprite object data
//      sobj_zp_st  ($5e/$5f) → state block (9 bytes)
// Clobbers: A, X, Y
// Does NOT touch: zp_tmp, zp_ptr_2
//--------------------------------------------------------------------
sobj_apply:
    // Zero the 9-byte state block
    lda #0
    ldy #8
sobj_apply_clr:
    sta (sobj_zp_st),y
    dey
    bpl sobj_apply_clr

    // ~slot_mask → sobj_inv_mask  (clears owned bits before ORing new values)
    ldy #0
    lda (sobj_zp_obj),y
    eor #$ff
    sta sobj_inv_mask

    // SPRITE_ENABLE  (offset 1)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_ENABLE
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_ENABLE

    // SPRITE_MULTICOLOR  (offset 2)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_MULTICOLOR
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_MULTICOLOR

    // SPRITE_EXPAND_X  (offset 3)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_EXPAND_X
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_EXPAND_X

    // SPRITE_EXPAND_Y  (offset 4)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_EXPAND_Y
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_EXPAND_Y

    // SPRITE_PRIORITY  (offset 5)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_PRIORITY
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_PRIORITY

    // SPRITE_MSB_X  (offset 6)
    iny
    lda (sobj_zp_obj),y
    sta sobj_new_bits
    lda SPRITE_MSB_X
    and sobj_inv_mask
    ora sobj_new_bits
    sta SPRITE_MSB_X

    // offset 7 = anim_speed — used only by sobj_tick, skip here
    // entries start at offset 8
    lda #0
    sta sobj_entry_idx
    ldy #8

sobj_apply_loop:
    lda (sobj_zp_obj),y    // slot byte ($FF = terminator)
    cmp #$ff
    beq sobj_apply_done

    sta sobj_slot_tmp      // save slot number (0-7)
    asl                    // slot * 2  (index into interleaved X/Y registers)
    sta sobj_slot2_tmp

    iny                    // +1: X low byte
    lda (sobj_zp_obj),y
    ldx sobj_slot2_tmp
    sta SPRITE_0_X,x       // $D000 + slot*2 = SP{slot}X

    iny                    // +2: Y position
    lda (sobj_zp_obj),y
    sta SPRITE_0_Y,x       // $D001 + slot*2 = SP{slot}Y  (X unchanged)

    iny                    // +3: colour
    lda (sobj_zp_obj),y
    ldx sobj_slot_tmp
    sta SPRITE_0_COLOR,x   // $D027 + slot = SP{slot}COLOR

    iny                    // +4: sprite data pointer
    lda (sobj_zp_obj),y
    sta SPRITE_0_POINTER,x // $07F8 + slot = SP{slot}POINTER

    iny                    // +5: anim_lo (skip — used by tick)
    iny                    // +6: anim_hi (skip)
    iny                    // +7: advance to next entry's slot byte

    inc sobj_entry_idx
    jmp sobj_apply_loop

sobj_apply_done:
    rts

//--------------------------------------------------------------------
// sobj_tick
// Advance animation frame counters ONLY.  No VIC-IIe register writes.
// Safe to call from the CIA timer IRQ hook at any raster position.
// Uses the IRQ-only ZP set (sobj_tzp_*) so it NEVER touches the same
// ZP locations as sobj_flush — eliminating the crash-after-N-cycles race.
// In:  sobj_tzp_obj ($a3/$a4) → sprite object data
//      sobj_tzp_st  ($a5/$a6) → state block
// Clobbers: A, Y, sobj_tzp_an ($a7/$a8)
// Does NOT touch: sobj_zp_obj/st/an, zp_tmp
//--------------------------------------------------------------------
sobj_tick:
    // Read anim_speed (offset 7); bail out if 0 (static object)
    ldy #7
    lda (sobj_tzp_obj),y
    bne !+
    rts
!:
    sta sobj_anim_speed

    // Increment shared frame_timer (state[0])
    ldy #0
    lda (sobj_tzp_st),y
    clc
    adc #1
    sta (sobj_tzp_st),y
    cmp sobj_anim_speed
    bcc sobj_tick_done       // not yet time to advance

    // Timer met speed: reset timer, walk entries and advance frame indices
    lda #0
    sta (sobj_tzp_st),y      // reset frame_timer (state[0])

    lda #0
    sta sobj_tick_idx
    ldy #8                   // first entry's slot byte

sobj_tick_loop:
    lda (sobj_tzp_obj),y
    cmp #$ff
    beq sobj_tick_done

    sty sobj_tick_ysave      // save current Y (slot byte of this entry)

    // Load anim table pointer from entry+5 (anim_lo) and entry+6 (anim_hi)
    lda sobj_tick_ysave
    clc
    adc #5
    tay
    lda (sobj_tzp_obj),y     // anim_lo
    sta sobj_tzp_an
    iny
    lda (sobj_tzp_obj),y     // anim_hi
    sta sobj_tzp_an+1

    // Skip static entries (anim ptr == $0000)
    lda sobj_tzp_an
    ora sobj_tzp_an+1
    beq sobj_tick_no_anim

    // Load current frame_index from state[1 + entry_idx]
    lda sobj_tick_idx
    clc
    adc #1
    tay
    lda (sobj_tzp_st),y      // A = current frame_index
    clc
    adc #1                   // A = next frame_index (candidate)
    tay                      // Y = next frame_index

    // If anim_table[next_frame_index] == $00, wrap to frame 0
    lda (sobj_tzp_an),y
    bne !+
    ldy #0                   // terminator hit: wrap to frame 0
!:
    // Y = new frame_index; store back into state[1 + entry_idx]
    sty sobj_tick_frame      // save new frame_index
    lda sobj_tick_idx
    clc
    adc #1
    tay                      // Y = state offset (1 + entry_idx)
    lda sobj_tick_frame
    sta (sobj_tzp_st),y

sobj_tick_no_anim:
    lda sobj_tick_ysave
    clc
    adc #7
    tay
    inc sobj_tick_idx
    jmp sobj_tick_loop

sobj_tick_done:
    rts

//--------------------------------------------------------------------
// sobj_disable
// Clear SPRITE_ENABLE bits for all slots owned by the object.
// In:  sobj_zp_obj ($5c/$5d) → sprite object data
// Clobbers: A, Y
//--------------------------------------------------------------------
sobj_disable:
    ldy #0
    lda (sobj_zp_obj),y    // slot_mask
    eor #$ff
    and SPRITE_ENABLE
    sta SPRITE_ENABLE
    rts

//--------------------------------------------------------------------
// sobj_enable
// Set SPRITE_ENABLE bits per the object's enable_mask.
// In:  sobj_zp_obj ($5c/$5d) → sprite object data
// Clobbers: A, Y
//--------------------------------------------------------------------
sobj_enable:
    ldy #1
    lda (sobj_zp_obj),y    // enable_mask
    ora SPRITE_ENABLE
    sta SPRITE_ENABLE
    rts

//--------------------------------------------------------------------
// sobj_flush
// Write current animation frame pointers to VIC-IIe sprite registers.
// Call from the MAIN LOOP after jsr wait_vbl so writes always land
// during VBlank, away from the VIC-IIe sprite DMA window.
// In:  sobj_zp_obj ($5c/$5d) → sprite object data
//      sobj_zp_st  ($5e/$5f) → state block
// Clobbers: A, X, Y, sobj_zp_an ($92/$93)
//--------------------------------------------------------------------
sobj_flush:
    lda #0
    sta sobj_entry_idx
    ldy #8

sobj_flush_loop:
    lda (sobj_zp_obj),y
    cmp #$ff
    beq sobj_flush_done

    sta sobj_slot_tmp
    sty sobj_yobj_save

    // Load anim table pointer (entry+5, entry+6)
    lda sobj_yobj_save
    clc
    adc #5
    tay
    lda (sobj_zp_obj),y
    sta sobj_zp_an
    iny
    lda (sobj_zp_obj),y
    sta sobj_zp_an+1

    // Skip static entries (pointer set once by sobj_apply, never changes)
    lda sobj_zp_an
    ora sobj_zp_an+1
    beq sobj_flush_next

    // Read anim_table[frame_index] and write to sprite pointer register
    lda sobj_entry_idx
    clc
    adc #1
    tay
    lda (sobj_zp_st),y     // frame_index for this entry
    tay
    lda (sobj_zp_an),y     // anim_table[frame_index] = sprite ptr value
    ldx sobj_slot_tmp
    sta SPRITE_0_POINTER,x

sobj_flush_next:
    lda sobj_yobj_save
    clc
    adc #7
    tay
    inc sobj_entry_idx
    jmp sobj_flush_loop

sobj_flush_done:
    rts

//--------------------------------------------------------------------
// sobj_set_color
// In:  A = color value
//      X = sprite slot (0-7)
// Clobbers: nothing
//--------------------------------------------------------------------
sobj_set_color:
    sta SPRITE_0_COLOR,x
    rts

//--------------------------------------------------------------------
// sobj_tick_move
// Consume one [dx,dy] entry from the move table and apply to all
// sprite slots owned by the object.
// Sentinels: $80 in dx position = stop; $81 = loop to table start.
// In:  sobj_zp_obj    ($5c/$5d) → sprite object data
//      sobj_mv_tbl_lo/hi        → move table start address
//      sobj_mv_offset           → current byte offset into table
//      sobj_mv_stopped          → 1 if halted
// Clobbers: A, X, Y, sobj_zp_mv ($94/$95)
// Note: X movement is 8-bit only; manual MSB_X update needed for
//       sprites that cross the X=255 screen boundary.
//--------------------------------------------------------------------
sobj_tick_move:
    lda sobj_mv_stopped
    bne sobj_mv_done

    // Compute current read pointer: table_start + byte_offset
    lda sobj_mv_tbl_lo
    clc
    adc sobj_mv_offset
    sta sobj_zp_mv
    lda sobj_mv_tbl_hi
    adc #0
    sta sobj_zp_mv+1

    // Read dx; check for stop ($80) or loop ($81) sentinel
    ldy #0
    lda (sobj_zp_mv),y
    cmp #$80
    bne sobj_mv_chk_loop
    lda #1
    sta sobj_mv_stopped
    jmp sobj_mv_done

sobj_mv_chk_loop:
    cmp #$81
    bne sobj_mv_have_delta
    // Loop: reset offset and pointer to table start
    lda #0
    sta sobj_mv_offset
    lda sobj_mv_tbl_lo
    sta sobj_zp_mv
    lda sobj_mv_tbl_hi
    sta sobj_zp_mv+1
    ldy #0
    lda (sobj_zp_mv),y       // re-read dx from start

sobj_mv_have_delta:
    sta sobj_mv_dx
    iny
    lda (sobj_zp_mv),y
    sta sobj_mv_dy

    // Advance offset past this entry
    lda sobj_mv_offset
    clc
    adc #2
    sta sobj_mv_offset

    // Apply (dx,dy) to every slot set in slot_mask
    ldy #0
    lda (sobj_zp_obj),y      // slot_mask (object offset 0)
    sta sobj_mv_slotmask
    lda #0
    sta sobj_mv_slot

sobj_mv_slot_loop:
    lsr sobj_mv_slotmask     // shift bit 0 into carry
    bcc sobj_mv_skip_slot    // bit was 0: slot not owned

    lda sobj_mv_slot
    asl                      // slot * 2 = X/Y register index
    tax
    lda SPRITE_0_X,x
    clc
    adc sobj_mv_dx
    sta SPRITE_0_X,x
    lda SPRITE_0_Y,x
    clc
    adc sobj_mv_dy
    sta SPRITE_0_Y,x

sobj_mv_skip_slot:
    inc sobj_mv_slot
    lda sobj_mv_slot
    cmp #8
    bne sobj_mv_slot_loop

sobj_mv_done:
    rts

//--------------------------------------------------------------------
// sobj_tick_sfx
// Scan the sfx table and play any entry whose anim_frame matches
// the current frame_index (state[1]) of the sprite object.
// Fires at most once per unique frame_index value.
// In:  sobj_zp_st  ($5e/$5f) → sprite state block
//      sobj_zp_sf  ($57/$58) → sfx table
// Clobbers: A, X, Y
//--------------------------------------------------------------------
sobj_tick_sfx:
    // Read frame_index for entry 0 (state[1])
    ldy #1
    lda (sobj_zp_st),y
    cmp sobj_sfx_last_frame  // already handled this frame?
    beq sobj_sfx_done
    sta sobj_sfx_last_frame
    sta sobj_sfx_cur_frame

    ldy #0
sobj_sfx_scan:
    lda (sobj_zp_sf),y       // anim_frame byte (or $FF terminator)
    cmp #$ff
    beq sobj_sfx_done
    cmp sobj_sfx_cur_frame
    bne sobj_sfx_next        // no match: skip this entry

    // Match: read voice (1/2/3) then sfx number
    iny
    lda (sobj_zp_sf),y       // voice
    tax
    dex                      // voice 1→0, 2→1, 3→2
    iny
    lda (sobj_zp_sf),y       // sfx number
    sta SFX_VOICE_1,x        // SFX_VOICE_1=$02a7, +0/+1/+2 → voice 1/2/3
    iny
    jmp sobj_sfx_scan        // continue scanning (multiple sfx per frame ok)

sobj_sfx_next:
    iny
    iny
    iny                      // skip [frame, voice, sfx]
    jmp sobj_sfx_scan

sobj_sfx_done:
    rts

//--------------------------------------------------------------------
// Internal variables (not zero-page; no ZP conflicts)
//--------------------------------------------------------------------
sobj_inv_mask:   .byte 0   // ~slot_mask for read-modify-write
sobj_new_bits:   .byte 0   // new mask bits to OR into VIC register / frame_index temp
sobj_slot_tmp:   .byte 0   // current entry's hardware slot number (0-7)
sobj_slot2_tmp:  .byte 0   // slot * 2  (X/Y register index)
sobj_entry_idx:  .byte 0   // entry loop counter (0-7)
sobj_yobj_save:  .byte 0   // saved object-buffer Y offset
sobj_anim_speed: .byte 0   // cached anim_speed for tick comparison
// sobj_tick private scratch — separate from sobj_flush vars (no shared state)
sobj_tick_idx:   .byte 0   // entry loop counter inside sobj_tick
sobj_tick_ysave: .byte 0   // saved object-buffer Y offset inside sobj_tick
sobj_tick_frame: .byte 0   // new frame_index temp inside sobj_tick
// Movement engine
sobj_mv_tbl_lo:  .byte 0   // move table start address lo (for loop reset)
sobj_mv_tbl_hi:  .byte 0   // move table start address hi
sobj_mv_offset:  .byte 0   // current byte offset into move table (0, 2, 4 …)
sobj_mv_stopped: .byte 0   // 1 = path finished, stop applying movement
sobj_mv_slotmask:.byte 0   // working copy of slot_mask during slot iteration
sobj_mv_slot:    .byte 0   // slot counter (0-7) during slot iteration
sobj_mv_dx:      .byte 0   // current signed X delta
sobj_mv_dy:      .byte 0   // current signed Y delta
// SFX engine
sobj_sfx_last_frame: .byte $ff  // frame_index at which sfx was last scanned
sobj_sfx_cur_frame:  .byte 0    // frame_index being matched during scan
