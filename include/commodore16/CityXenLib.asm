//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Usage:
//   #import "CityXenLib.asm"
//   ; ... your C16/Plus-4 game code ...
//
// Target: Commodore 16 (16KB RAM) and Plus-4 (64KB RAM)
// CPU: MOS 7501 / 8501 (NMOS 6502-compatible)
// Video/Sound/Timer chip: TED (MOS 7360 / 8360)
// Assembler: KickAssembler 5.x
//
// Module overview:
//   Constants.asm       — TED registers ($FF00-$FF3F), ZP layout, keys, KERNAL
//   Macros.asm          — CityXenUpstart, ClearScreen, SetScreenColors, sound helpers
//   PrintMacros.asm     — Print, PrintXY, PrintPlot, PrintChr, etc.
//   sys.il.asm          — SaveRegs/LoadRegs, no_subroutine, wait_vbl
//   timers.il.asm       — 16 software timers driven by 50/60Hz IRQ
//   random.il.asm       — LFSR random (lda_random) + TED-raster entropy variant
//   input.il.asm        — TED matrix joystick (port 1 & 2), KERNAL keyboard
//   score.il.asm        — BCD score: score_add/sub/reset/to_str, DrawScore
//   print.il.asm        — print, print_hex, print_decimal, no-leading-zeros
//   string.il.asm       — strcpy, strlen, string_buffer
//   rle.il.asm          — RLE compress / decompress
//   sfxkit.il.asm       — TED chip sound effects (sfx_play, sfx_irq_hook)
//   drawc16screen.il.asm — full-screen blitter for 40×25 pre-built screens
//
// C16/Plus-4 hardware notes:
//   Screen RAM  : $0C00  (40×25 = 1000 chars)
//   Color RAM   : $0800  (1 byte per cell, TED color format)
//   TED chip    : $FF00-$FF3F  (video, sound, timers, keyboard)
//   BASIC start : $1001 (BASIC 3.5)
//   KERNAL table: $FF81-$FFF3 (same addresses as C64)
//   IRQ vector  : $0314/$0315 (same as C64/VIC-20)
//   No hardware sprites — use character set animation instead
//   TED color   : (hue << 4) | luminance, luminance 0-7
//////////////////////////////////////////////////////////////////

#import "Constants.asm"
#import "Macros.asm"
#import "PrintMacros.asm"
#import "sys.il.asm"
#import "timers.il.asm"
#import "random.il.asm"
#import "input.il.asm"
#import "score.il.asm"
#import "print.il.asm"
#import "string.il.asm"
#import "rle.il.asm"
#import "sfxkit.il.asm"
#import "drawc16screen.il.asm"

//////////////////////////////////////////////////////////////////
