//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Sound Effects (TED chip)
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Simple one-shot SFX using the TED chip's 2 square-wave voices.
// SFX IDs match the C64/VIC-20 sfxkit.il.asm values for portability.
//
// TED sound registers:
//   TED_SOUND1_LO/HI ($FF0E/$FF0F) — voice 1 frequency
//   TED_SOUND2_LO/HI ($FF10/$FF11) — voice 2 frequency
//   TED_SOUND_CTRL   ($FF12)       — bits 3-0: volume, bit 4: v1 en, bit 5: v2 en
//
// Frequency: 10-bit value split across LO (bits 7-0) and HI (bits 9-8 in bits 1-0).
// Higher frequency values = lower pitch (TED counts up to overflow).
//
// SFX IDs:
//   SFX_GET_READY  $01 — rising beep (voice 1)
//   SFX_DING       $02 — short high beep (voice 1)
//   SFX_WRONG      $04 — low buzz (voice 2)
//   SFX_POW        $05 — mid crack (voice 1)
//   SFX_MISS       $06 — low thud (voice 2)
//   SFX_GAME_OVER  $07 — falling tone (voice 1)
//
// API:
//   sfx_v1_play(sfx_id)  — play SFX
//   sfx_irq_hook         — call from IRQ to decrement duration & silence
//////////////////////////////////////////////////////////////////

#importonce

#define CONFIG_SFXKIT

.const SFX_GET_READY = $01
.const SFX_DING      = $02
.const SFX_WRONG     = $04
.const SFX_POW       = $05
.const SFX_MISS      = $06
.const SFX_GAME_OVER = $07

sfx_active:   .byte 0
sfx_duration: .byte 0

// PlaySFX macro — trigger a sound effect.
.macro sfx_v1_play(sfx) {
    lda #sfx
    jsr sfx_play
}
.macro sfx_v2_play(sfx) {
    lda #sfx
    jsr sfx_play
}
.macro sfx_v3_play(sfx) {
    lda #sfx
    jsr sfx_play
}

// sfx_play: A = SFX ID.
// Writes directly to TED sound registers and sets sfx_duration.
sfx_play:
    sta sfx_active
    cmp #SFX_GET_READY
    bne sfp2
    // Voice 1: mid frequency, enable
    lda #$50
    sta TED_SOUND1_LO
    lda #$11            // voice 1 enable (bit 4) + hi freq bits
    sta TED_SOUND_CTRL
    lda #$0f
    ora TED_SOUND_CTRL
    sta TED_SOUND_CTRL
    lda #40
    sta sfx_duration
    rts
sfp2:
    cmp #SFX_DING
    bne sfp3
    // Voice 1: high frequency
    lda #$10
    sta TED_SOUND1_LO
    lda TED_SOUND_CTRL
    and #$f0
    ora #$1f            // volume 15, voice 1 enable
    sta TED_SOUND_CTRL
    lda #10
    sta sfx_duration
    rts
sfp3:
    cmp #SFX_WRONG
    bne sfp4
    // Voice 2: low frequency buzz
    lda #$c0
    sta TED_SOUND2_LO
    lda TED_SOUND_CTRL
    and #$f0
    ora #$2f            // volume 15, voice 2 enable
    sta TED_SOUND_CTRL
    lda #20
    sta sfx_duration
    rts
sfp4:
    cmp #SFX_POW
    bne sfp5
    // Voice 1: mid-low frequency
    lda #$70
    sta TED_SOUND1_LO
    lda TED_SOUND_CTRL
    and #$f0
    ora #$1f
    sta TED_SOUND_CTRL
    lda #8
    sta sfx_duration
    rts
sfp5:
    cmp #SFX_MISS
    bne sfp6
    // Voice 2: lower frequency thud
    lda #$e0
    sta TED_SOUND2_LO
    lda TED_SOUND_CTRL
    and #$f0
    ora #$28            // volume 8, voice 2 enable
    sta TED_SOUND_CTRL
    lda #15
    sta sfx_duration
    rts
sfp6:
    // SFX_GAME_OVER (or unknown): voice 1, low pitch
    lda #$f0
    sta TED_SOUND1_LO
    lda TED_SOUND_CTRL
    and #$f0
    ora #$1f
    sta TED_SOUND_CTRL
    lda #60
    sta sfx_duration
    rts

// sfx_irq_hook: decrement duration; silence when done.
// Install via CONFIG_SFXKIT — called once per IRQ frame.
sfx_irq_hook:
    lda sfx_duration
    beq sfx_silent
    dec sfx_duration
    rts
sfx_silent:
    lda #$00
    sta TED_SOUND_CTRL
    sta sfx_active
    rts
