//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Constants
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////
// Various Memory Constants

.const BASIC_START          = $0401

.const SCREEN_RAM           = $8000
.const SCREEN_COLS          = 40
.const SCREEN_ROWS          = 25

// Zero Page: general temp and pointer storage
.const SCREEN_PTR           = $56
.const SCREEN_PTR_LO        = $56
.const SCREEN_PTR_HI        = $57
.const TEMP_1               = $54
.const TEMP_2               = $55
.const zp_tmp               = $56
.const zp_tmp_lo            = $56
.const zp_tmp_hi            = $57
.const TEMP_3               = $58
.const TEMP_4               = $59
.const TEMP_5               = $5A
.const TEMP_6               = $5B
.const TEMP_7               = $5C
.const TEMP_8               = $5D
.const zp_ptr_screen        = $5E
.const zp_ptr_screen_lo     = $5E
.const zp_ptr_screen_hi     = $5F
.const zp_point_tmp         = $59
.const zp_point_tmp_lo      = $59
.const zp_point_tmp_hi      = $5a
.const zp_ptr_2             = $64
.const zp_ptr_2_lo          = $64
.const zp_ptr_2_hi          = $65
.const zp_temp              = $a3
.const zp_temp2             = $a4
.const zp_temp3             = $a5

// String operation pointers (used by strcpy, print, etc.)
.const zp_string            = $60
.const zp_string_lo         = $60
.const zp_string_hi         = $61
.const zp_str2              = $62
.const zp_str2_lo           = $62
.const zp_str2_hi           = $63

// Stub color pointer aliases (PET has no color RAM, kept for API compatibility)
.const zp_ptr_color         = $64
.const zp_ptr_color_lo      = $64
.const zp_ptr_color_hi      = $65

.const JOYPORT_TIMER        = $05

//////////////////////////////////////////////////////////////////////////////////////
// PET Hardware Registers (PET 4032 / BASIC 4.0)

// VIA 6522 at $E840 — IEEE-488, user port, system timers
.const PET_VIA_BASE         = $E840
.const PET_VIA_PRA          = $E840    // Port A Data
.const PET_VIA_PRB          = $E841    // Port B Data
.const PET_VIA_DDRA         = $E842    // Port A Data Direction
.const PET_VIA_DDRB         = $E843    // Port B Data Direction
.const PET_VIA_T1CL         = $E844    // Timer 1 Counter Low (read clears IFR T1 flag)
.const PET_VIA_T1CH         = $E845    // Timer 1 Counter High
.const PET_VIA_T1LL         = $E846    // Timer 1 Latch Low
.const PET_VIA_T1LH         = $E847    // Timer 1 Latch High
.const PET_VIA_T2CL         = $E848    // Timer 2 Counter Low
.const PET_VIA_T2CH         = $E849    // Timer 2 Counter High
.const PET_VIA_SR           = $E84A    // Shift Register
.const PET_VIA_ACR          = $E84B    // Auxiliary Control Register
.const PET_VIA_PCR          = $E84C    // Peripheral Control Register
.const PET_VIA_IFR          = $E84D    // Interrupt Flag Register
.const PET_VIA_IER          = $E84E    // Interrupt Enable Register
.const PET_VIA_ORA          = $E84F    // Port A (no handshake)

// PIA1 6520 at $E810 — Keyboard matrix
.const PET_PIA1_BASE        = $E810
.const PET_PIA1_PRA         = $E810    // Port A (keyboard row data)
.const PET_PIA1_DDRA        = $E811
.const PET_PIA1_PRB         = $E812    // Port B (keyboard column select)
.const PET_PIA1_CRB         = $E813

// PIA2 6520 at $E820 — Speaker (CB2), diagnostics
.const PET_PIA2_BASE        = $E820
.const PET_PIA2_PRA         = $E820
.const PET_PIA2_DDRA        = $E821
.const PET_PIA2_PRB         = $E822
.const PET_PIA2_CRB         = $E823    // bit 3 = CB2 controls speaker

// PET speaker: toggle CB2 via PIA2 CRB
// CB2 high-output mode: CRB = %xxxxx110 (bits 3:1 = 110)
// CB2 low-output mode:  CRB = %xxxxx100 (bits 3:1 = 100)
.const PET_SPEAKER_HIGH     = %00001110
.const PET_SPEAKER_LOW      = %00001100

// IRQ user hook address (PET 4032 BASIC 4.0)
// The KERNAL's system IRQ handler chains through this RAM vector.
// Adjust if using a different PET ROM revision.
.const PET_IRQ_HOOK_LO      = $0090
.const PET_IRQ_HOOK_HI      = $0091

//////////////////////////////////////////////////////////////////////////////////////
// KERNAL SUBROUTINES ($FF81-$FFF3 — same addresses as Commodore 64)

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
.const KERNAL_SCREEN        = $FFED
.const KERNAL_PLOT          = $FFF0
.const KERNAL_IOBASE        = $FFF3

//////////////////////////////////////////////////////////////////////////////////////
// KEYS (PETSCII / ASCII codes returned by KERNAL_GETIN on PET)

.const KEY_RETURN       = $0d
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
.const KEY_CURSOR_UP    = $91
.const KEY_CURSOR_DOWN  = $11
.const KEY_CURSOR_LEFT  = $9d
.const KEY_CURSOR_RIGHT = $1d
.const KEY_CLEAR        = $93
.const KEY_STOP         = $03
