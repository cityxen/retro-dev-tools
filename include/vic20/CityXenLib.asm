//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// Usage:
//   #import "CityXenLib.asm"
//   ; ... your VIC-20 game code ...
//
// Target: Commodore VIC-20 (6502, NTSC or PAL)
// Assembler: KickAssembler 5.x
//
// Module overview:
//   Constants.asm       — VIC chip regs, VIA1/VIA2, ZP layout, keys, KERNAL
//   Macros.asm          — CityXenUpstart, ClearScreen, SetScreenColors, sound helpers
//   PrintMacros.asm     — Print, PrintXY, PrintPlot, PrintChr, etc.
//   sys.il.asm          — SaveRegs/LoadRegs, no_subroutine, wait_vbl
//   timers.il.asm       — 16 software timers driven by 60Hz IRQ
//   random.il.asm       — LFSR random (lda_random) + VIC-noise variant
//   input.il.asm        — VIA1 joystick, KERNAL keyboard, get_any_input
//   score.il.asm        — BCD score: score_add/sub/reset/to_str, DrawScore
//   print.il.asm        — print, print_hex, print_decimal, no-leading-zeros
//   string.il.asm       — strcpy, strlen, string_buffer
//   rle.il.asm          — RLE compress / decompress
//   sfxkit.il.asm       — VIC chip sound effects (sfx_play, sfx_irq_hook)
//   drawvicscreen.il.asm — full-screen blitter for 22×23 pre-built screens
//
// VIC-20 hardware notes:
//   Screen RAM  : $1E00  (22×23 = 506 chars, default/unexpanded)
//   Color RAM   : $9600  (nibble per cell)
//   VIC chip    : $9000-$900F
//   VIA 1       : $9110-$911F  (joystick, user port)
//   VIA 2       : $9120-$912F  (serial, keyboard)
//   BASIC start : $1001 (unexpanded), $0401 (+3K), $1201 (+8K)
//   KERNAL table: $FF81-$FFF3 (same addresses as C64)
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
#import "drawvicscreen.il.asm"

//////////////////////////////////////////////////////////////////
