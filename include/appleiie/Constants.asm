#importonce
//===========================================================================
// CityXen Apple IIe Library - Constants
// Apple IIe / 65C02 Hardware Constants and Memory Map
//===========================================================================

//---------------------------------------------------------------------------
// Safe Zero-Page Memory Locations
// Avoid: $00-$05 (ProDOS/Monitor), $FA-$FF (Monitor scratch)
// Generally safe: $06-$09, $1A-$1F, $50-$5F, $E0-$EF
//---------------------------------------------------------------------------

// General-purpose pointer pairs
.const ZP_PTR0       = $06     // 2 bytes: general pointer 0
.const ZP_PTR1       = $08     // 2 bytes: general pointer 1
.const ZP_PTR2       = $1A     // 2 bytes: general pointer 2
.const ZP_PTR3       = $1C     // 2 bytes: general pointer 3
.const ZP_TMP0       = $1E     // 1 byte:  temporary
.const ZP_TMP1       = $1F     // 1 byte:  temporary

// Extended zero-page block (safe for most ProDOS user programs)
.const ZP_A          = $50     // 2 bytes
.const ZP_B          = $52     // 2 bytes
.const ZP_C          = $54     // 2 bytes
.const ZP_D          = $56     // 2 bytes
.const ZP_E          = $58     // 2 bytes
.const ZP_F          = $5A     // 2 bytes
.const ZP_G          = $5C     // 2 bytes
.const ZP_H          = $5E     // 2 bytes

// IRQ-safe zero-page block (avoid touching from main loop when IRQ active)
.const ZP_IRQ_A      = $E0     // 2 bytes
.const ZP_IRQ_B      = $E2     // 2 bytes
.const ZP_IRQ_C      = $E4     // 2 bytes
.const ZP_IRQ_D      = $E6     // 2 bytes

//---------------------------------------------------------------------------
// Cursor / Screen State (Monitor ROM uses these directly)
//---------------------------------------------------------------------------
.const CURSOR_CH     = $24     // Current horizontal position (column, 0-39)
.const CURSOR_CV     = $25     // Current vertical position (row, 0-23)
.const CURSOR_BAS    = $28     // Current row base address (word, $28 lo / $29 hi)

//---------------------------------------------------------------------------
// Text Screen Memory
//---------------------------------------------------------------------------
.const SCREEN_PAGE1  = $0400   // Text page 1 base (40x24 = 960 bytes used)
.const SCREEN_PAGE2  = $0800   // Text page 2 base
.const SCREEN_COLS   = 40
.const SCREEN_ROWS   = 24

// Text screen row base addresses (non-linear interleaved layout)
// Row  0: $0400   Row  8: $0428   Row 16: $0450
// Row  1: $0480   Row  9: $04A8   Row 17: $04D0
// Row  2: $0500   Row 10: $0528   Row 18: $0550
// Row  3: $0580   Row 11: $05A8   Row 19: $05D0
// Row  4: $0600   Row 12: $0628   Row 20: $0650
// Row  5: $0680   Row 13: $06A8   Row 21: $06D0
// Row  6: $0700   Row 14: $0728   Row 22: $0750
// Row  7: $0780   Row 15: $07A8   Row 23: $07D0

//---------------------------------------------------------------------------
// Hi-Res Graphics Memory
//---------------------------------------------------------------------------
.const HIRES_PAGE1   = $2000   // Hi-res page 1 (280x192, ~8KB)
.const HIRES_PAGE2   = $4000   // Hi-res page 2 (280x192, ~8KB)
.const HIRES_COLS    = 280
.const HIRES_ROWS    = 192

// Monitor ROM hi-res state
.const HCOLOR_REG    = $1C     // Current HCOLOR (0-7)
.const HPOSN_LO      = $1D     // Current hi-res X position (lo byte)
.const HPOSN_HI      = $1E     // Current hi-res X position (hi byte, 0 or 1)
.const VPOSN         = $1F     // Current hi-res Y position

//---------------------------------------------------------------------------
// Lo-Res Graphics Memory (shares text page addresses)
//---------------------------------------------------------------------------
.const LORES_PAGE1   = $0400   // Lo-res page 1 (40x48 color blocks)
.const LORES_PAGE2   = $0800   // Lo-res page 2

//---------------------------------------------------------------------------
// Soft Switches ($C000-$CFFF I/O region)
//---------------------------------------------------------------------------

// Keyboard
.const KBD           = $C000   // Read: last key (bit 7=strobe, bits 0-6=ASCII key)
.const KBD_STROBE    = $C010   // Read or write: clear keyboard strobe

// Mode read switches (bit 7 = state)
.const RDTEXT        = $C01A   // Read: bit 7=1 → text mode active
.const RDMIXED       = $C01B   // Read: bit 7=1 → mixed mode active
.const RDPAGE2       = $C01C   // Read: bit 7=1 → page 2 selected
.const RDHIRES       = $C01D   // Read: bit 7=1 → hi-res mode active

// Display mode switches (any read/write toggles)
.const SW_GRAPHICS   = $C050   // Enable graphics (lo-res default)
.const SW_TEXT       = $C051   // Enable text mode
.const SW_FULLSCR    = $C052   // Full-screen graphics (no text rows)
.const SW_MIXED      = $C053   // Mixed graphics + 4 text rows at bottom
.const SW_PAGE1      = $C054   // Select display page 1
.const SW_PAGE2      = $C055   // Select display page 2
.const SW_LORES      = $C056   // Lo-res graphics
.const SW_HIRES      = $C057   // Hi-res graphics

// Audio
.const SPEAKER       = $C030   // Toggle speaker (any access clicks the speaker)
.const CASSETTE_OUT  = $C020   // Toggle cassette output

// Annunciator outputs (game port auxiliary)
.const AN0_OFF       = $C058
.const AN0_ON        = $C059
.const AN1_OFF       = $C05A
.const AN1_ON        = $C05B
.const AN2_OFF       = $C05C
.const AN2_ON        = $C05D
.const AN3_OFF       = $C05E
.const AN3_ON        = $C05F

// Pushbuttons / Apple keys (bit 7 = pressed)
.const PB0           = $C061   // Open Apple key / joystick button 0
.const PB1           = $C062   // Closed Apple key / joystick button 1
.const PB2           = $C063   // Joystick button 2 (if present)

// Paddle / Joystick analog (read while bit 7 high = comparator charging)
.const PDL0          = $C064   // Paddle 0 / Joystick 1 X axis
.const PDL1          = $C065   // Paddle 1 / Joystick 1 Y axis
.const PDL2          = $C066   // Paddle 2 / Joystick 2 X axis
.const PDL3          = $C067   // Paddle 3 / Joystick 2 Y axis
.const PTRIG         = $C070   // Paddle trigger: resets comparator (start timing)

// 80-Column Card Soft Switches
.const COL80_OFF     = $C00C
.const COL80_ON      = $C00D
.const ALTCHR_OFF    = $C00E
.const ALTCHR_ON     = $C00F

//---------------------------------------------------------------------------
// Language Card / Extended RAM Switches
//---------------------------------------------------------------------------
.const LCBANK2       = $C080   // Read LC bank 2, write disabled
.const LCROMREAD     = $C081   // Read ROM, write LC bank 2 (2 accesses needed)
.const LC_OFF        = $C082   // Read ROM, write disabled
.const LCBANK1       = $C083   // Read/write LC bank 1
// Alternate (even address = single access, odd = double access needed)
.const LCBANK2B      = $C084
.const LCROMREADB    = $C085
.const LC_OFFB       = $C086
.const LCBANK1B      = $C087

//---------------------------------------------------------------------------
// Monitor ROM Subroutines
//---------------------------------------------------------------------------

// Output
.const COUT          = $FDED   // Print char in A (high bit set) to current cursor
.const COUT1         = $FDF0   // Print char in A (no special char handling)
.const CROUT         = $FD8E   // Print carriage return (advances line, scrolls)
.const PRBYTE        = $FDDA   // Print A as two ASCII hex digits
.const PRHEX         = $FDE3   // Print low nibble of A as one hex digit

// Input
.const RDKEY         = $FD0C   // Read keypress into A, waits, clears strobe (high bit set)
.const KEYIN         = $FD1B   // Alternate key input entry point

// Cursor / Screen
.const HOME          = $FC58   // Clear screen and home cursor (text page 1)
.const VTAB          = $FC22   // Move cursor to row in CV ($25), update BAS
.const BASCALC       = $FBC1   // Calculate screen row base: A=row → $28/$29 = base

// Timing
.const WAIT          = $FCA8   // Delay: approx 26.5 * A * A / 2 microseconds
.const BELL          = $FF3A   // Ring bell

// Hi-Res
.const HCLR          = $F3F6   // Clear hi-res page 1 to black
.const HPLOT0        = $F457   // Plot point at HPOSN/VPOSN in HCOLOR
.const HLIN          = $F53A   // Draw hi-res horizontal line
.const HVLIN         = $F5CB   // Draw hi-res vertical line

// Lo-Res
.const PLOT          = $F800   // Plot lo-res block: Y=row, X=col, A=color
.const HLINE         = $F819   // Draw lo-res horizontal line

// Utility
.const SETPWRC       = $FB2F   // Set power-on byte (Applesoft detect)

//---------------------------------------------------------------------------
// ProDOS Machine Language Interface (MLI)
//---------------------------------------------------------------------------
.const PRODOS_MLI    = $BF00   // MLI call entry: jsr PRODOS_MLI / .byte cmd / .word param_ptr

// MLI Command Codes
.const MLI_QUIT      = $65
.const MLI_READ_BLK  = $80
.const MLI_WRITE_BLK = $81
.const MLI_GET_TIME  = $82
.const MLI_CREATE    = $C0
.const MLI_DESTROY   = $C1
.const MLI_RENAME    = $C2
.const MLI_SET_INFO  = $C3
.const MLI_GET_INFO  = $C4
.const MLI_ONLINE    = $C5
.const MLI_SET_PFX   = $C6
.const MLI_GET_PFX   = $C7
.const MLI_OPEN      = $C8
.const MLI_NEWLINE   = $C9
.const MLI_READ      = $CA
.const MLI_WRITE     = $CB
.const MLI_CLOSE     = $CC
.const MLI_FLUSH     = $CD
.const MLI_SET_MARK  = $CE
.const MLI_GET_MARK  = $CF
.const MLI_SET_EOF   = $D0
.const MLI_GET_EOF   = $D1

// ProDOS Global Page (system variables)
.const PRODOS_DATELO = $BF90
.const PRODOS_DATEHI = $BF91
.const PRODOS_TIMELO = $BF92
.const PRODOS_TIMEHI = $BF93

// ProDOS File Types
.const FTYPE_TXT     = $04
.const FTYPE_BIN     = $06
.const FTYPE_SYS     = $FF

// ProDOS Access Flags
.const ACCESS_READ   = $01
.const ACCESS_WRITE  = $02
.const ACCESS_RDWR   = $03

// ProDOS Error Codes
.const ERR_NONE      = $00
.const ERR_BADCALL   = $01
.const ERR_BADPCOUNT = $04
.const ERR_BADPATH   = $40
.const ERR_NODEV     = $28
.const ERR_EOF       = $4C
.const ERR_NOROOM    = $48

//---------------------------------------------------------------------------
// Keyboard Key Constants (ASCII, high bit clear, as returned by RDKEY - 1)
//---------------------------------------------------------------------------
.const KEY_RETURN    = $0D
.const KEY_BACKSPACE = $08     // Left arrow / backspace
.const KEY_RIGHT     = $15     // Right arrow (Control-U)
.const KEY_UP        = $0B     // Up arrow (Control-K)
.const KEY_DOWN      = $0A     // Down arrow (line feed)
.const KEY_DELETE    = $7F     // Delete / Rubout
.const KEY_SPACE     = $20
.const KEY_ESCAPE    = $1B
.const KEY_CTRL_C    = $03
// Open Apple / Closed Apple read via PB0/PB1 soft switches (not ASCII)

//---------------------------------------------------------------------------
// Joystick Direction Bit Flags (returned by input routines)
//---------------------------------------------------------------------------
.const JOY_UP        = %00000001
.const JOY_DOWN      = %00000010
.const JOY_LEFT      = %00000100
.const JOY_RIGHT     = %00001000
.const JOY_FIRE      = %00010000   // Open Apple button (PB0)
.const JOY_FIRE2     = %00100000   // Closed Apple button (PB1)

.const JOY_THRESHOLD = 48          // Units from center (0-127 scale each side)
.const JOY_CENTER    = 128         // Nominal center value

//---------------------------------------------------------------------------
// Lo-Res Color Constants (nibble pairs; both nibbles same for solid block)
//---------------------------------------------------------------------------
.const BLACK         = $00
.const MAGENTA       = $11
.const DARK_BLUE     = $22
.const PURPLE        = $33
.const DARK_GREEN    = $44
.const GREY1         = $55
.const MEDIUM_BLUE   = $66
.const LIGHT_BLUE    = $77
.const BROWN         = $88
.const ORANGE        = $99
.const GREY2         = $AA
.const PINK          = $BB
.const GREEN         = $CC
.const YELLOW        = $DD
.const AQUA          = $EE
.const WHITE         = $FF

//---------------------------------------------------------------------------
// Hi-Res HCOLOR Values (0-7 for Monitor ROM HPLOT calls)
//---------------------------------------------------------------------------
.const HCLR_BLACK    = 0
.const HCLR_GREEN    = 1
.const HCLR_VIOLET   = 2
.const HCLR_WHITE    = 3
.const HCLR_BLACK2   = 4
.const HCLR_ORANGE   = 5
.const HCLR_BLUE     = 6
.const HCLR_WHITE2   = 7

//---------------------------------------------------------------------------
// Apple IIe Text Character Encoding
// Screen RAM stores: $00-$3F = inverse, $40-$7F = flash, $80-$FF = normal
//---------------------------------------------------------------------------
.const CHR_INVERSE   = $00     // Add to ASCII code for inverse video
.const CHR_FLASH     = $40     // Add to ASCII code for flashing
.const CHR_NORMAL    = $80     // Add to ASCII code for normal video (most common)

//---------------------------------------------------------------------------
// IRQ Vector (Apple IIe)
//---------------------------------------------------------------------------
.const IRQ_VECTOR_LO = $03FE
.const IRQ_VECTOR_HI = $03FF

//===========================================================================
