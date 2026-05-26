//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Hardware Constants
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////

#importonce

//////////////////////////////////////////////////////////////////
// Various Memory Constants
// Safe zero page locations (shared with KERNAL, similar to C64)
// $FB-$FE: safe for machine code programs
// $57-$5C: generally safe
// $60-$65: generally safe
// $A3-$A4: generally safe

.const SECONDARY_ADDRESS    = $b9
.const DEVICE_NUMBER        = $bA
.const PNTR                 = $d3
.const CURSOR_X_POS         = $d3
.const TBLX                 = $d6
.const CURSOR_Y_POS         = $d6
.const CURSOR_COLOR         = $0286

// VIC-20 default screen layout: 22 columns × 23 rows (unexpanded)
.const SCREEN_COLS          = 22
.const SCREEN_ROWS          = 23
.const VICSCN               = $1E00   // Screen RAM (default, unexpanded)
.const SCREEN_RAM           = $1E00
.const COLOR_RAM            = $9600   // Color RAM (nibble per cell)

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
// VIC CHIP CONSTANTS (Video Interface Chip — 6560 NTSC / 6561 PAL)
// Registers at $9000-$900F

.const VIC_TV_X             = $9000   // Horizontal centering
.const VIC_TV_Y             = $9001   // Vertical position
.const VIC_COLUMNS          = $9002   // bits 7-1 = video memory page; bit 0 = extra column
                                      // bits 6-0 (write) = number of displayed columns
.const VIC_ROWS             = $9003   // bit 7 = raster MSB; bits 6-1 = # rows; bit 0 = char height (0=8px,1=16px)
.const VIC_RASTER           = $9004   // Current raster line (read-only, 8 bits)
.const VIC_SCR_CHAR_PTR     = $9005   // bits 7-4 = screen RAM page; bits 3-0 = char ROM/RAM page
.const VIC_LIGHT_PEN_X      = $9006   // Light pen X (read-only)
.const VIC_LIGHT_PEN_Y      = $9007   // Light pen Y (read-only)
.const VIC_POT_1            = $9008   // Paddle/potentiometer 1 (read-only)
.const VIC_POT_2            = $9009   // Paddle/potentiometer 2 (read-only)

// Sound registers
.const VIC_SOUND_VOICE1     = $900A   // Alto voice:    bit 7 = enable, bits 6-0 = frequency
.const VIC_SOUND_VOICE2     = $900B   // Soprano voice: bit 7 = enable, bits 6-0 = frequency
.const VIC_SOUND_VOICE3     = $900C   // Bass voice:    bit 7 = enable, bits 6-0 = frequency
.const VIC_SOUND_NOISE      = $900D   // Noise channel: bit 7 = enable, bits 6-0 = frequency
.const VIC_SOUND_VOLUME     = $900E   // bits 3-0 = master volume (0-15); bits 7-4 = auxiliary color nibble

// Screen/color register
// $900F: bits 7-4 = background color; bits 3-1 = border color; bit 0 = reverse mode
.const VIC_SCREEN_COLOR     = $900F

// Convenience aliases
.const SOUND_VOICE1         = $900A
.const SOUND_VOICE2         = $900B
.const SOUND_VOICE3         = $900C
.const SOUND_NOISE          = $900D
.const SOUND_VOLUME         = $900E

// Note: on VIC-20 border and background are packed into $900F (unlike C64's separate $D020/$D021).
// Use SetBorderColor(n) and SetBackgroundColor(n) macros from Macros.asm.
.const BORDER_BACKGROUND_REG = $900F

//////////////////////////////////////////////////////////////////
// VIA 1 — Versatile Interface Adaptor 1 ($9110-$911F)
// Handles: user port, joystick, light pen, cassette

.const VIA1_PORT_A          = $9110   // Port A data
.const VIA1_PORT_B          = $9111   // Port B data
.const VIA1_DDR_A           = $9112   // Port A data-direction register
.const VIA1_DDR_B           = $9113   // Port B data-direction register
.const VIA1_TIMER1_LO       = $9114
.const VIA1_TIMER1_HI       = $9115
.const VIA1_TIMER1_LATCH_LO = $9116
.const VIA1_TIMER1_LATCH_HI = $9117
.const VIA1_TIMER2_LO       = $9118
.const VIA1_TIMER2_HI       = $9119
.const VIA1_SHIFT           = $911A
.const VIA1_ACR             = $911B
.const VIA1_PCR             = $911C
.const VIA1_IFR             = $911D
.const VIA1_IER             = $911E
.const VIA1_PORT_A_NH       = $911F   // Port A (no handshake)

// Joystick via VIA1:
//   Port B ($9111) directions: bit 2=Up, bit 3=Down, bit 4=Left, bit 5=Right (active low, 0=pressed)
//   Port A ($9110) fire:       bit 5=Fire (active low, 0=pressed)
.const JOYSTICK_PORT        = $9111   // Joystick directions
.const JOYSTICK_FIRE_REG    = $9110   // Joystick fire button register
.const JOY_UP_BIT           = $04    // Bit mask — bit 2
.const JOY_DOWN_BIT         = $08    // Bit mask — bit 3
.const JOY_LEFT_BIT         = $10    // Bit mask — bit 4
.const JOY_RIGHT_BIT        = $20    // Bit mask — bit 5
.const JOY_FIRE_BIT         = $20    // Bit mask — bit 5 of VIA1_PORT_A

// User port (VIA1 Port A)
.const USER_PORT_DATA       = $9110
.const USER_PORT_DATA_DIR   = $9112

//////////////////////////////////////////////////////////////////
// VIA 2 — Versatile Interface Adaptor 2 ($9120-$912F)
// Handles: serial bus, keyboard matrix

.const VIA2_PORT_A          = $9120
.const VIA2_PORT_B          = $9121
.const VIA2_DDR_A           = $9122
.const VIA2_DDR_B           = $9123
.const VIA2_TIMER1_LO       = $9124
.const VIA2_TIMER1_HI       = $9125
.const VIA2_TIMER1_LATCH_LO = $9126
.const VIA2_TIMER1_LATCH_HI = $9127
.const VIA2_TIMER2_LO       = $9128
.const VIA2_TIMER2_HI       = $9129
.const VIA2_SHIFT           = $912A
.const VIA2_ACR             = $912B
.const VIA2_PCR             = $912C
.const VIA2_IFR             = $912D
.const VIA2_IER             = $912E
.const VIA2_PORT_A_NH       = $912F

//////////////////////////////////////////////////////////////////
// KERNAL SUBROUTINE ADDRESSES
// (VIC-20 shares the same $FF81-$FFF3 jump table as C64)

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
.const KERNAL_SCREEN        = $FFED   // Output: X=cols (22), Y=rows (23)
.const KERNAL_PLOT          = $FFF0
.const KERNAL_IOBASE        = $FFF3

// IRQ — VIC-20 IRQ vector (same address as C64)
.const KERNAL_IRQ_VECTOR    = $0314
.const KERNAL_IRQ_VECTOR_HI = $0315
.const KERNAL_IRQ_ENTRY     = $EABF   // VIC-20 KERNAL IRQ service continuation (jmp here at end of IRQ)

.const KERNAL_WAIT_KEY      = $F142

//////////////////////////////////////////////////////////////////
// KEYS (PETSCII — identical to C64)

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

// Color values (same 16-color palette as C64; KickAssembler built-ins match)
// BLACK=0 WHITE=1 RED=2 CYAN=3 PURPLE=4 GREEN=5 BLUE=6 YELLOW=7
// ORANGE=8 BROWN=9 LIGHT_RED=10 DARK_GRAY=11 GRAY=12 LIGHT_GREEN=13 LIGHT_BLUE=14 LIGHT_GRAY=15
// Note: $900F border/background only supports colors 0-7.
