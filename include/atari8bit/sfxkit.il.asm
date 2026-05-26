#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Sound Effects (POKEY)
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Provides simple one-shot sound effects via POKEY channel 1.
// No external SFX kit needed — all sound is inline POKEY writes.
//
// SFX IDs match the C64 sfxkit.il.asm values for portability:
//   SFX_GET_READY  $01 — rising arpeggio
//   SFX_DING       $02 — short high beep
//   SFX_WRONG      $04 — descending buzz
//   SFX_POW        $05 — mid-range crack
//   SFX_MISS       $06 — low thud
//   SFX_GAME_OVER  $07 — falling tone
//
// PlaySFX(sfx)  — macro: stores sfx ID, JSRs sfx_play
// sfx_play      — dispatch table handler
// sfx_update    — call once per frame to step envelope/silence
//////////////////////////////////////////////////////////////////

.const SFX_GET_READY = $01
.const SFX_DING      = $02
.const SFX_WRONG     = $04
.const SFX_POW       = $05
.const SFX_MISS      = $06
.const SFX_GAME_OVER = $07

// sfx_active: current SFX ID playing (0 = silent)
sfx_active:   .byte 0
sfx_duration: .byte 0   // frames remaining

// PlaySFX macro — triggers the named sound effect.
.macro PlaySFX(sfx) {
    lda #sfx
    jsr sfx_play
}

// sfx_play: A = SFX ID.  Sets up POKEY channel 1 for that effect.
sfx_play:
    sta sfx_active
    cmp #SFX_GET_READY
    bne sfp_try2
    lda #$60
    sta AUDF1
    lda #AUDC_PURE | $0A
    sta AUDC1
    lda #40
    sta sfx_duration
    rts
sfp_try2:
    cmp #SFX_DING
    bne sfp_try3
    lda #$08
    sta AUDF1
    lda #AUDC_PURE | $0C
    sta AUDC1
    lda #12
    sta sfx_duration
    rts
sfp_try3:
    cmp #SFX_WRONG
    bne sfp_try4
    lda #$40
    sta AUDF1
    lda #AUDC_NOISE5 | $0A
    sta AUDC1
    lda #20
    sta sfx_duration
    rts
sfp_try4:
    cmp #SFX_POW
    bne sfp_try5
    lda #$18
    sta AUDF1
    lda #AUDC_PURE | $0C
    sta AUDC1
    lda #10
    sta sfx_duration
    rts
sfp_try5:
    cmp #SFX_MISS
    bne sfp_try6
    lda #$A0
    sta AUDF1
    lda #AUDC_NOISE5 | $08
    sta AUDC1
    lda #18
    sta sfx_duration
    rts
sfp_try6:
    // SFX_GAME_OVER (or unknown)
    lda #$20
    sta AUDF1
    lda #AUDC_PURE | $0E
    sta AUDC1
    lda #60
    sta sfx_duration
    rts

// sfx_update: decrement duration; silence channel 1 when done.
// Call once per frame (after wait_vbl).
sfx_update:
    lda sfx_duration
    beq sfx_silent
    dec sfx_duration
    rts
sfx_silent:
    lda #0
    sta AUDC1
    sta sfx_active
    rts

//////////////////////////////////////////////////////////////////
