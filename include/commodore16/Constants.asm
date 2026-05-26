//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Hardware Constants
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Target: Commodore 16 (16KB RAM) and Plus-4 (64KB RAM)
// Video/Sound/Timer chip: TED (MOS 7360 / 8360)
//////////////////////////////////////////////////////////////////

#importonce

//////////////////////////////////////////////////////////////////
// Memory Layout
//   $0000-$00FF  Zero page
//   $0100-$01FF  Stack
//   $0200-$07FF  OS workspace / color RAM ($0800-$0BFF)
//   $0800-$0BFF  Color RAM (attribute memory, 1 byte per cell)
//   $0C00-$0FFF  Screen RAM (40×25 = 1000 bytes, default)
//   $1000-$7FFF  User RAM (C16: to $3FFF; Plus-4: to $7FFF)
//   $8000-$BFFF  BASIC ROM
//   $C000-$DFFF  BASIC extension / function ROM
//   $E000-$FEFF  KERNAL ROM
//   $FD00-$FDFF  I/O area 1 (keyboard 6529, serial)
//   $FE00-$FEFF  I/O area 2
//   $FF00-$FF3F  TED registers
//   $FF40-$FFFF  KERNAL ROM (continued)

// Default screen layout: 40 columns × 25 rows (same as C64)
.const SCREEN_COLS          = 40
.const SCREEN_ROWS          = 25
.const SCREEN_RAM           = $0C00   // Video matrix (text/bitmap)
.const VICSCN               = $0C00
.const COLOR_RAM            = $0800   // Attribute/color memory

//////////////////////////////////////////////////////////////////
// Safe zero-page locations (similar to C64 KERNAL conventions)
// $02-$08:  safe for ML programs
// $57-$60:  safe
// $A3-$B1:  safe
// $F7-$FE:  safe

.const SECONDARY_ADDRESS    = $b9
.const DEVICE_NUMBER        = $bA
.const PNTR                 = $d3
.const CURSOR_X_POS         = $d3
.const TBLX                 = $d6
.const CURSOR_Y_POS         = $d6
.const CURSOR_COLOR         = $0286

.const TEMP_1               = $fb
.const TEMP_2               = $fc
.const zp_tmp               = $4e
.const zp_tmp_lo            = $4e
.const zp_tmp_hi            = $4f
.const zp_timers            = $f7
.const zp_timers_lo         = $f7
.const zp_timers_hi         = $f8
.const zp_string            = $fd
.const zp_string_lo         = $fd
.const zp_string_hi         = $fe
.const zp_str2              = $02
.const zp_str2_lo           = $02
.const zp_str2_hi           = $03
.const TEMP_7               = $04
.const TEMP_8               = $05
.const zp_ptr_screen        = $60
.const zp_ptr_screen_lo     = $60
.const zp_ptr_screen_hi     = $61
.const zp_ptr_color         = $a3
.const zp_ptr_color_lo      = $a3
.const zp_ptr_color_hi      = $a4
.const zp_point_tmp         = $59
.const zp_point_tmp_lo      = $59
.const zp_point_tmp_hi      = $5a
.const zp_ptr_2             = $64
.const zp_ptr_2_lo          = $64
.const zp_ptr_2_hi          = $65
.const zp_temp              = $57
.const zp_temp2             = $57
.const zp_temp3             = $58

//////////////////////////////////////////////////////////////////
// TED CHIP REGISTERS (MOS 7360/8360)
// $FF00-$FF1F primary; $FF20-$FF3F mirrors/extended

// Hardware timers (count down; reload from latch on underflow)
.const TED_TIMER1_LO        = $FF00   // Timer 1 low byte (R/W)
.const TED_TIMER1_HI        = $FF01   // Timer 1 high byte (R/W)
.const TED_TIMER2_LO        = $FF02   // Timer 2 low byte (R/W)
.const TED_TIMER2_HI        = $FF03   // Timer 2 high byte (R/W)
.const TED_TIMER3_LO        = $FF04   // Timer 3 low byte (R/W)
.const TED_TIMER3_HI        = $FF05   // Timer 3 high byte (R/W)

// Video control
.const TED_CONTROL1         = $FF06   // Control register 1
                                      //   bit 7: raster compare bit 8 (MSB)
                                      //   bit 6: extended background color mode
                                      //   bit 5: bitmap mode (1=bitmap, 0=text)
                                      //   bit 4: display enable
                                      //   bit 3: 25/24 row select (1=25, 0=24)
                                      //   bits 2-0: Y-scroll (0-7)
.const TED_CONTROL2         = $FF07   // Control register 2
                                      //   bit 4: multicolor mode
                                      //   bit 3: 40/38 column select (1=40, 0=38)
                                      //   bits 2-0: X-scroll (0-7)

// Keyboard/joystick matrix
.const TED_KEYBOARD         = $FF08   // Keyboard row select (write) / row data (read)

// IRQ
.const TED_IRQ_STATUS       = $FF09   // IRQ status register (read)
                                      //   bit 0: timer 1 IRQ
                                      //   bit 1: timer 2 IRQ
                                      //   bit 2: timer 3 IRQ
                                      //   bit 3: raster IRQ
                                      //   bit 4: light pen IRQ
.const TED_IRQ_MASK         = $FF0A   // IRQ mask/enable register (write)
                                      //   same bit layout as TED_IRQ_STATUS
.const TED_RASTER_CMP_HI    = $FF0B   // Raster compare high bits

// Light pen
.const TED_LIGHT_PEN_X      = $FF0C   // Light pen X (read-only)
.const TED_LIGHT_PEN_Y      = $FF0D   // Light pen Y (read-only)

// Sound — two square-wave voices
.const TED_SOUND1_LO        = $FF0E   // Voice 1 frequency low byte
.const TED_SOUND1_HI        = $FF0F   // Voice 1 frequency high byte
.const TED_SOUND2_LO        = $FF10   // Voice 2 frequency low byte
.const TED_SOUND2_HI        = $FF11   // Voice 2 frequency high byte
.const TED_SOUND_CTRL       = $FF12   // Sound control register
                                      //   bits 3-0: master volume (0-15)
                                      //   bit 4: voice 1 enable
                                      //   bit 5: voice 2 enable
                                      //   bit 6: noise enable (some sources)
                                      //   bit 7: noise/voice select (some sources)

// Memory configuration
.const TED_MEM_CONFIG       = $FF13   // Memory mapping control register
.const TED_VIDEO_ADDR       = $FF14   // Video/screen memory address bits (hi)

// Colors
// TED color encoding: bits 7-4 = hue (0-15), bits 3-0 = luminance (0-7)
// color_byte = (hue << 4) | luminance
// Luminance 0 = darkest (black), luminance 7 = brightest
// BLACK (hue 0) = $00 regardless of luminance
.const TED_COLOR_BG         = $FF15   // Background color register
.const TED_COLOR_1          = $FF16   // Extra background / foreground color 1
.const TED_COLOR_2          = $FF17   // Extra background / foreground color 2
.const TED_COLOR_3          = $FF18   // Extra background / foreground color 3
.const TED_BORDER_COLOR     = $FF19   // Border / frame color

// Aliases for C64-style code
.const BACKGROUND_COLOR     = $FF15
.const BORDER_COLOR         = $FF19

// Cursor and position
.const TED_CURSOR_HI        = $FF1A   // Cursor position high byte
.const TED_CURSOR_LO        = $FF1B   // Cursor position low byte
.const TED_RASTER_HI        = $FF1C   // Raster line counter (high bits; bit 7 in $FF06)
.const TED_RASTER_LO        = $FF1D   // Raster line counter low byte (read-only)
.const TED_CHAR_ADDR        = $FF1E   // Character set address register
.const TED_SCREEN_ADDR      = $FF1F   // Screen memory address register

//////////////////////////////////////////////////////////////////
// TED COLOR VALUES
// Format: (hue << 4) | luminance  where luminance 0-7
// These are the standard "full brightness" (luminance = 7) color values.
// Match C64 PETSCII color order (hue 0-15 = same order as C64 16 colors).

.const TED_BLACK            = $00   // Black (any hue, lum 0 — or hue 0 at any lum)
.const TED_WHITE            = $17   // White (hue 1, lum 7)
.const TED_RED              = $27   // Red (hue 2, lum 7)
.const TED_CYAN             = $37   // Cyan (hue 3, lum 7)
.const TED_PURPLE           = $47   // Purple/Violet (hue 4, lum 7)
.const TED_VIOLET           = $47
.const TED_GREEN            = $57   // Green (hue 5, lum 7)
.const TED_BLUE             = $67   // Blue (hue 6, lum 7)
.const TED_YELLOW           = $77   // Yellow (hue 7, lum 7)
.const TED_ORANGE           = $87   // Orange (hue 8, lum 7)
.const TED_BROWN            = $97   // Brown (hue 9, lum 7)
.const TED_LIGHT_RED        = $A7   // Light Red (hue A, lum 7)
.const TED_DARK_GRAY        = $B7   // Dark Gray (hue B, lum 7)
.const TED_GRAY             = $C7   // Medium Gray (hue C, lum 7)
.const TED_LIGHT_GREEN      = $D7   // Light Green (hue D, lum 7)
.const TED_LIGHT_BLUE       = $E7   // Light Blue (hue E, lum 7)
.const TED_LIGHT_GRAY       = $F7   // Light Gray (hue F, lum 7)

// Mid-luminance (lum 4) variants — useful for dark backgrounds
.const TED_DARK_RED         = $24
.const TED_DARK_GREEN       = $54
.const TED_DARK_BLUE        = $64
.const TED_DARK_CYAN        = $34
.const TED_DARK_YELLOW      = $74

// TED color macro helpers — build any color value at runtime
// MakeTEDColor(hue, luminance): assemble a TED color byte
.macro MakeTEDColor(h, l) {
    lda #[(h << 4) | (l & 7)]
}

//////////////////////////////////////////////////////////////////
// KERNAL SUBROUTINE ADDRESSES
// C16/Plus-4 shares the same jump table layout as C64 ($FF81-$FFF3).

.const KERNAL_SCINIT        = $FF81
.const KERNAL_IOINIT        = $FF84
.const KERNAL_RAMTAS        = $FF87
.const KERNAL_RESTOR        = $FF8A
.const KERNAL_VECTOR        = $FF8D
.const KERNAL_SETMSG        = $FF90
.const KERNAL_LSTNSA        = $FF93
.const KERNAL_SECLSN        = $FF93
.const KERNAL_TALKSA        = $FF96
.const KERNAL_SECTLK        = $FF96
.const KERNAL_MEMBOT        = $FF99
.const KERNAL_MEMTOP        = $FF9C
.const KERNAL_SCNKEY        = $FF9F
.const KERNAL_SETTMO        = $FFA2
.const KERNAL_IECIN         = $FFA5
.const KERNAL_IECOUT        = $FFA8
.const KERNAL_UNTALK        = $FFAB
.const KERNAL_UNLSTN        = $FFAE
.const KERNAL_LISTEN        = $FFB1
.const KERNAL_TALK          = $FFB4
.const KERNAL_READST        = $FFB7
.const KERNAL_SETLFS        = $FFBA
.const KERNAL_SETNAM        = $FFBD
.const KERNAL_OPEN          = $FFC0
.const KERNAL_CLOSE         = $FFC3
.const KERNAL_CHKIN         = $FFC6
.const KERNAL_CHKOUT        = $FFC9
.const KERNAL_CLRCHN        = $FFCC
.const KERNAL_CHRIN         = $FFCF
.const KERNAL_CHROUT        = $FFD2
.const KERNAL_LOAD          = $FFD5
.const KERNAL_SAVE          = $FFD8
.const KERNAL_SETTIM        = $FFDB
.const KERNAL_RDTIM         = $FFDE
.const KERNAL_STOP          = $FFE1
.const KERNAL_GETIN         = $FFE4
.const KERNAL_CLALL         = $FFE7
.const KERNAL_UDTIM         = $FFEA
.const KERNAL_SCREEN        = $FFED   // Output: X=40 (cols), Y=25 (rows)
.const KERNAL_PLOT          = $FFF0
.const KERNAL_IOBASE        = $FFF3

// IRQ vector (same address as C64)
.const KERNAL_IRQ_VECTOR    = $0314
.const KERNAL_IRQ_VECTOR_HI = $0315

// C16/Plus-4 KERNAL IRQ service continuation.
// After our custom IRQ handler, jump here so the KERNAL completes
// its own IRQ work (keyboard scan, TOD update) and does RTI.
// NOTE: Verify this address against your specific ROM version.
// Common value for NTSC Plus-4 / C16 KERNAL: $FCB3
.const KERNAL_IRQ_ENTRY     = $FCB3

.const KERNAL_WAIT_KEY      = $F142

//////////////////////////////////////////////////////////////////
// JOYSTICK / KEYBOARD via TED keyboard matrix ($FF08)
//
// To read a keyboard row, write the column mask to $FF08,
// then read back $FF08 to get which rows are active (active low).
//
// Joystick port 1 connects to the keyboard matrix:
//   Write $7F to $FF08 (select all columns except bit 7)
//   Read $FF08: bit 0=up, bit 1=down, bit 2=left, bit 3=right, bit 4=fire
//   (active low — 0 = direction pressed)
//
// Joystick port 2 connects to a different row:
//   Write $BF to $FF08 (select all columns except bit 6)
//   Same bit layout for directions.
//
// NOTE: Exact bit positions should be verified against the
// Plus-4 Programmer's Reference Guide for your hardware revision.

.const JOY1_COL_SELECT      = $7F   // Write to $FF08 to read joystick port 1
.const JOY2_COL_SELECT      = $BF   // Write to $FF08 to read joystick port 2

.const JOY_UP_BIT           = $01   // Bit mask — bit 0
.const JOY_DOWN_BIT         = $02   // Bit mask — bit 1
.const JOY_LEFT_BIT         = $04   // Bit mask — bit 2
.const JOY_RIGHT_BIT        = $08   // Bit mask — bit 3
.const JOY_FIRE_BIT         = $10   // Bit mask — bit 4

//////////////////////////////////////////////////////////////////
// KEYS (PETSCII — same as C64)

.const KEY_RETURN       = $0d
.const LINE_FEED        = $0d
.const KEY_HOME         = $13
.const KEY_DELETE       = $14
.const KEY_SPACE        = $20
.const KEY_DOLLAR_SIGN  = $24
.const KEY_ASTERISK     = $2a
.const KEY_MINUS        = $2d
.const KEY_PLUS         = $2b
.const KEY_COLON        = $3a
.const KEY_SEMICOLON    = $3b
.const KEY_0            = $30
.const KEY_1            = $31
.const KEY_2            = $32
.const KEY_3            = $33
.const KEY_4            = $34
.const KEY_5            = $35
.const KEY_6            = $36
.const KEY_7            = $37
.const KEY_8            = $38
.const KEY_9            = $39
.const KEY_EQUAL        = $3d
.const KEY_AT           = $40
.const KEY_A            = $41
.const KEY_B            = $42
.const KEY_C            = $43
.const KEY_D            = $44
.const KEY_E            = $45
.const KEY_F            = $46
.const KEY_G            = $47
.const KEY_H            = $48
.const KEY_I            = $49
.const KEY_J            = $4a
.const KEY_K            = $4b
.const KEY_L            = $4c
.const KEY_M            = $4d
.const KEY_N            = $4e
.const KEY_O            = $4f
.const KEY_P            = $50
.const KEY_Q            = $51
.const KEY_R            = $52
.const KEY_S            = $53
.const KEY_T            = $54
.const KEY_U            = $55
.const KEY_V            = $56
.const KEY_W            = $57
.const KEY_X            = $58
.const KEY_Y            = $59
.const KEY_Z            = $5a
.const KEY_F1           = $85
.const KEY_F2           = $89
.const KEY_F3           = $86
.const KEY_F4           = $8a
.const KEY_F5           = $87
.const KEY_F6           = $8b
.const KEY_F7           = $88
.const KEY_F8           = $89
.const KEY_CURSOR_UP    = $91
.const KEY_CURSOR_DOWN  = $11
.const KEY_CURSOR_LEFT  = $9d
.const KEY_CURSOR_RIGHT = $1d
.const KEY_CLEAR        = $93

.const KEY_BLACK    = 144
.const KEY_WHITE    = 5
.const KEY_RED      = 28
.const KEY_CYAN     = 159
.const KEY_VIOLET   = 156
.const KEY_GREEN    = 30
.const KEY_BLUE     = 31
.const KEY_YELLOW   = 158
.const KEY_ORANGE   = 129
.const KEY_BROWN    = 149
.const KEY_LT_RED   = 150
.const KEY_DK_GREY  = 151
.const KEY_GREY     = 152
.const KEY_LT_GREEN = 153
.const KEY_LT_BLUE  = 154
.const KEY_LT_GREY  = 155

// KickAssembler built-in color names (0-15) match the C64/C16 hue ordering.
// For TED hardware registers, use TED_* constants above.
