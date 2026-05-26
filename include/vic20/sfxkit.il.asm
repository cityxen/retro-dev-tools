//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Sound Effects (VIC chip)
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// Simple one-shot SFX using the VIC chip's 3 voices + noise.
// SFX IDs match the C64 sfxkit.il.asm values for portability.
//
// SFX IDs:
//   SFX_GET_READY  $01 — rising arpeggio (voice 1 soprano)
//   SFX_DING       $02 — short high beep (voice 1)
//   SFX_WRONG      $04 — noise burst
//   SFX_POW        $05 — mid crack (voice 2)
//   SFX_MISS       $06 — low noise thud
//   SFX_GAME_OVER  $07 — falling bass tone (voice 3)
//
// VIC voice register format: bit 7 = enable, bits 6-0 = frequency
// Lower frequency values = higher pitch (frequency is subtracted from 255).
//
// API:
//   sfx_v1_play(sfx_id)  — play SFX on voice 1 (or noise)
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
// Writes directly to VIC sound registers and sets sfx_duration.
sfx_play:
    sta sfx_active
    cmp #SFX_GET_READY
    bne sfp2
    lda #$80|$50        // voice 1 (alto), enable, mid-low freq
    sta VIC_SOUND_VOICE1
    lda #$0f
    sta VIC_SOUND_VOLUME
    lda #40
    sta sfx_duration
    rts
sfp2:
    cmp #SFX_DING
    bne sfp3
    lda #$80|$10        // voice 1, high freq
    sta VIC_SOUND_VOICE1
    lda #$0f
    sta VIC_SOUND_VOLUME
    lda #10
    sta sfx_duration
    rts
sfp3:
    cmp #SFX_WRONG
    bne sfp4
    lda #$80|$40        // noise channel, mid freq
    sta VIC_SOUND_NOISE
    lda #$0f
    sta VIC_SOUND_VOLUME
    lda #20
    sta sfx_duration
    rts
sfp4:
    cmp #SFX_POW
    bne sfp5
    lda #$80|$30        // voice 2 (soprano), mid-low
    sta VIC_SOUND_VOICE2
    lda #$0f
    sta VIC_SOUND_VOLUME
    lda #8
    sta sfx_duration
    rts
sfp5:
    cmp #SFX_MISS
    bne sfp6
    lda #$80|$60        // noise, lower freq
    sta VIC_SOUND_NOISE
    lda #$08
    sta VIC_SOUND_VOLUME
    lda #15
    sta sfx_duration
    rts
sfp6:
    // SFX_GAME_OVER (or unknown)
    lda #$80|$70        // voice 3 (bass), low freq
    sta VIC_SOUND_VOICE3
    lda #$0f
    sta VIC_SOUND_VOLUME
    lda #60
    sta sfx_duration
    rts

// sfx_irq_hook: decrement duration; silence all voices when done.
// Install via CONFIG_SFXKIT — called once per IRQ frame.
sfx_irq_hook:
    lda sfx_duration
    beq sfx_silent
    dec sfx_duration
    rts
sfx_silent:
    lda #$00
    sta VIC_SOUND_VOICE1
    sta VIC_SOUND_VOICE2
    sta VIC_SOUND_VOICE3
    sta VIC_SOUND_NOISE
    sta VIC_SOUND_VOLUME
    sta sfx_active
    rts
