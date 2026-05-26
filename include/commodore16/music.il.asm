//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Music stub
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Define CONFIG_MUSIC before importing CityXenLib.asm to enable
// music playback. Supply your own music.play routine and set
// play_music to 1 to start playback.
//////////////////////////////////////////////////////////////////

#importonce

#define CONFIG_MUSIC

play_music: .byte 0

music.play:
    rts
