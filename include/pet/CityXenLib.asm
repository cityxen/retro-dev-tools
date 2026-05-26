//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Main Include Hub
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// #import this file once per project to pull in all definitions, macros,
// and inline subroutines.
//
// Usage:
//   #import "../include/CityXenLib.asm"
//   // ... your code using macros and constants ...
//   CityXenUpstart(my_entry)
//
// Notes:
//   - CPU is MOS 6502 (NOT 65C02): no stz, no bra, no (zp) indirect
//   - Screen RAM at $8000, no color RAM
//   - Timers hook via PET_IRQ_HOOK_LO/HI ($0090/$0091 for BASIC 4.0)
//   - No sprites, no SID, no VIC
//////////////////////////////////////////////////////////////////////////////////////

#import "Constants.asm"
#import "Macros.asm"
#import "sys.il.asm"
#import "timers.il.asm"
#import "random.il.asm"
#import "input.il.asm"
#import "print.il.asm"
#import "string.il.asm"
#import "score.il.asm"
#import "rle.il.asm"
#import "disk.il.asm"
#import "DrawPetMateScreen.asm"
#import "PrintMacros.asm"
#import "honkheckbutt.il.asm"
#import "userport.il.asm"
// #import "sfxkit.il.asm"    // Uncomment to include PIA speaker SFX stubs

//////////////////////////////////////////////////////////////////////////////////////
