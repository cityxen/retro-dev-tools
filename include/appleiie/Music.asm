#importonce
//===========================================================================
// CityXen Apple IIe Library - Music / Speaker Sound
//
// The Apple IIe has a single 1-bit speaker driven by accessing $C030.
// Each access toggles the speaker cone; rapid toggling produces tones.
//===========================================================================

#import "music.il.asm"

// InitializeMusic - Set up the speaker music IRQ handler
.macro InitializeMusic() {
    jsr il_music_init
}

// PlayNote - Queue a note for the music engine
// Usage: PlayNote(note_id)
.macro PlayNote(note_id) {
    lda #note_id
    jsr il_music_play_note
}

// StopMusic - Silence the speaker and stop music playback
.macro StopMusic() {
    jsr il_music_stop
}

//===========================================================================
