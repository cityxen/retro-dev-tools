//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Usage:
//   #import "CityXenLib.asm"
//   ; ...your code using macros, constants, and routines...
//
// Target: Atari 800XL (6502 / NTSC)
// Assembler: KickAssembler 5.x
//
// Module overview:
//   Constants.asm     — hardware registers, ZP layout, key codes, colors
//   system.asm        — SC() function, PutChar/PutSpc macros
//   Macros.asm        — display init, color, sound, ataristr, PrintLine
//   PrintMacros.asm   — high-level print macros (PrintXY, ClearLine, etc.)
//   sys.il.asm        — SaveRegs/LoadRegs, a_reg/x_reg/y_reg, no_subroutine
//   timers.il.asm     — frame timer system, wait_vbl, update_timers
//   random.il.asm     — POKEY hardware RNG
//   input.il.asm      — joystick (STICK0/STRIG0) and keyboard (CH) reading
//   score.il.asm      — BCD score management, score_add/sub/reset/to_str
//   print.il.asm      — print_at, print_char, print_hex, print_decimal,
//                       print_no_leading_zeros, print_leading_zeros_as_spaces
//   string.il.asm     — string_buffer, StrLen, StrCpy
//   rle.il.asm        — RLE compress / decompress
//   sfxkit.il.asm     — POKEY sound effects (PlaySFX, sfx_update)
//////////////////////////////////////////////////////////////////

#import "Constants.asm"
#import "system.asm"
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

//////////////////////////////////////////////////////////////////
