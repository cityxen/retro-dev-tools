//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Music Stub
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// The VIC-20 has no SID chip.  Music is driven by the VIC chip's
// 3 voices + noise channel via $900A-$900D.
//
// This file defines the CONFIG_MUSIC flag and the play_music
// control byte used by timers.il.asm.  Implement your own music
// engine and point music.play at your play routine.
//
// To enable music integration in the IRQ:
//   1. #import "music.il.asm" (sets #define CONFIG_MUSIC)
//   2. Provide a subroutine labelled music_play_routine
//   3. Set play_music = 1 to start, 0 to stop
//////////////////////////////////////////////////////////////////

#importonce

#define CONFIG_MUSIC

play_music: .byte 0     // 0 = music off, 1 = music on

music:
.play:      // music.play — stub: implement your VIC music engine here
    rts
