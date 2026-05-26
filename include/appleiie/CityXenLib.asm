//===========================================================================
// CityXen Apple IIe Library - Main Include Hub
//
// #import this file once per project to pull in all definitions, macros,
// and inline subroutines.
//
// Usage:
//   #import "../include/CityXenLib.asm"
//   // ... your code using macros and constants ...
//   CityXenUpstart(my_entry)
//===========================================================================

.cpu _65C02     // Apple IIe uses the 65C02 processor

#import "Constants.asm"
#import "Macros.asm"
#import "sys.il.asm"
#import "timers.il.asm"
#import "random.il.asm"
#import "input.il.asm"
#import "score.il.asm"
#import "print.il.asm"
#import "string.il.asm"
#import "rle.il.asm"
#import "disk.il.asm"
#import "drawapplescreen.il.asm"
#import "DrawAppleScreen.asm"
#import "PrintMacros.asm"
#import "SpriteManagement.asm"
#import "honkheckbutt.il.asm"
#import "userport.il.asm"
// #import "Music.asm"   // Uncomment to include speaker music system
// #import "music.il.asm"

//===========================================================================
