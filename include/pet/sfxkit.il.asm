//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Sound FX Kit (PET speaker stub)
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// The PET has a 1-bit speaker driven by PIA2 CB2 (bit in PET_PIA2_CRB).
// No SID chip is present.  This module provides simple beep/chirp routines
// and the same constant names as the C64 sfxkit for API compatibility.
// Complex SFX (multi-voice, envelope, etc.) are not possible on PET.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

#define CONFIG_SFXKIT

// SFX identifiers (kept for source compatibility with C64 code)
.const SFX_GET_READY = $01
.const SFX_DING      = $02
.const SFX_WRONG     = $04
.const SFX_POW       = $05
.const SFX_MISS      = $06
.const SFX_GAME_OVER = $07

// Voice slots (PET: single speaker, only voice 1 has effect)
.const SFX_VOICE_1   = $02a7
.const SFX_VOICE_2   = $02a8
.const SFX_VOICE_3   = $02a9

// SFX tone parameters
sfx_tone_hi:  .byte 0      // tone period high byte (stored by sfx_play_tone)
sfx_tone_lo:  .byte 0      // tone period low byte

//////////////////////////////////////////////////////////////////////////////////////
// sfx_v1_play(sfx) — play a named sound effect via voice 1

.macro sfx_v1_play(sfx) {
    lda #sfx
    jsr sfx_play
}

.macro sfx_v2_play(sfx) {
    // PET has one speaker; route same as voice 1
    lda #sfx
    jsr sfx_play
}

.macro sfx_v3_play(sfx) {
    lda #sfx
    jsr sfx_play
}

//////////////////////////////////////////////////////////////////////////////////////
// sfx_play — dispatch on A = SFX_* constant, generate a short beep

sfx_play:
    cmp #SFX_DING
    beq sfx_ding
    cmp #SFX_WRONG
    beq sfx_wrong
    cmp #SFX_POW
    beq sfx_pow
    cmp #SFX_MISS
    beq sfx_miss
    cmp #SFX_GAME_OVER
    beq sfx_gameover
    // SFX_GET_READY or unknown — short beep
    lda #$07
    jsr KERNAL_CHROUT
    rts

sfx_ding:
    lda #$07
    jsr KERNAL_CHROUT
    rts

sfx_wrong:
    lda #$07
    jsr KERNAL_CHROUT
    rts

sfx_pow:
    lda #$07
    jsr KERNAL_CHROUT
    rts

sfx_miss:
    lda #$07
    jsr KERNAL_CHROUT
    rts

sfx_gameover:
    lda #$07
    jsr KERNAL_CHROUT
    lda #$07
    jsr KERNAL_CHROUT
    rts

//////////////////////////////////////////////////////////////////////////////////////
// sfx_toggle_speaker — toggle PIA2 CB2 to produce one click
// Call in a tight loop with a delay between calls to generate a tone.

sfx_toggle_speaker_high:
    lda PET_PIA2_CRB
    and #%11110111
    ora #PET_SPEAKER_HIGH
    sta PET_PIA2_CRB
    rts

sfx_toggle_speaker_low:
    lda PET_PIA2_CRB
    and #%11110111
    ora #PET_SPEAKER_LOW
    sta PET_PIA2_CRB
    rts
