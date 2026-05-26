//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

#importonce
//////////////////////////////////////////////////////////////////
// SOUND FX KIT STUFF

#define CONFIG_SFXKIT

.const SFX_LOC = $C000

.const sfx_sound_on  = SFX_LOC
.const sfx_sound_off = SFX_LOC+$10
.const sfx_clear     = SFX_LOC+$1F9
.const sfx_irq_hook  = SFX_LOC+$28

.const SFX_VOICE_1 = $02A7
.const SFX_VOICE_2 = $02A8
.const SFX_VOICE_3 = $02A9

// BASIC SFX
.const SFX_GET_READY = $01
.const SFX_DING      = $02
.const SFX_WRONG     = $04
.const SFX_POW       = $05
.const SFX_MISS      = $06
.const SFX_GAME_OVER = $07

.macro SetSFXKitAddress() {
    FixSFXKit()
}

.macro FixSFXKit() {
    lda #$3A
    sta SFX_LOC+$0128
    sta SFX_LOC+$0129
    sta SFX_LOC+$012A
}

.macro sfx_v1_play(sfx) {
    lda #sfx
    sta SFX_VOICE_1
}

.macro sfx_v2_play(sfx) {
    lda #sfx
    sta SFX_VOICE_2
}

.macro sfx_v3_play(sfx) {
    lda #sfx
    sta SFX_VOICE_3
}
