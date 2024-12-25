////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SFX KIT SOUND STUFF

.const SFK_VOICE_1 = $02a7
.const SFK_VOICE_2 = $02a8
.const SFK_VOICE_3 = $02a9

sfk_sound_on: // add irq routine
	jsr SFX_ON
	rts

sfk_sound_off:
	jsr SFX_OFF
	rts

sfk_clear: 	 
	jsr SFX_CLEAR
	rts

.macro sfk_v1_play(sfx) {
    lda sfx
    sta $02a7
}

.macro sfk_v2_play(sfx) {
    lda sfx
    sta $02a8
}

.macro sfk_v3_play(sfx) {
    lda sfx
    sta $02a9
}