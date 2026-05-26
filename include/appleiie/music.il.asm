#importonce
//===========================================================================
// CityXen Apple IIe Library - Speaker Music Configuration
//
// The Apple IIe speaker is a 1-bit device driven by toggling $C030.
// Tones are produced by toggling at the target frequency.
// Music playback requires a tight timing loop or IRQ-based driver.
//
// This module provides constants and minimal stubs.
// A full speaker music driver is beyond this stub — link an external
// driver (e.g. Mockingboard support or a pure-speaker PWM engine).
//===========================================================================

// Set CONFIG_MUSIC = 1 to enable music integration in timers.il.asm
.const CONFIG_MUSIC = 0

// Note frequency table index constants (for a future music engine)
.const NOTE_C3  = 0
.const NOTE_D3  = 1
.const NOTE_E3  = 2
.const NOTE_F3  = 3
.const NOTE_G3  = 4
.const NOTE_A3  = 5
.const NOTE_B3  = 6
.const NOTE_C4  = 7   // middle C
.const NOTE_D4  = 8
.const NOTE_E4  = 9
.const NOTE_F4  = 10
.const NOTE_G4  = 11
.const NOTE_A4  = 12
.const NOTE_B4  = 13
.const NOTE_C5  = 14
.const NOTE_REST = 15

//---------------------------------------------------------------------------
// il_music_init - Initialize music engine (stub)
//   Replace body with actual speaker music driver init.
//---------------------------------------------------------------------------
il_music_init:
    rts

//---------------------------------------------------------------------------
// il_music_play_note - Queue a note (stub)
//   A = note index
//---------------------------------------------------------------------------
il_music_play_note:
    rts

//---------------------------------------------------------------------------
// il_music_stop - Stop music playback (stub)
//---------------------------------------------------------------------------
il_music_stop:
    rts

//===========================================================================
