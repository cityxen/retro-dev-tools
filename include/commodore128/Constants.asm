//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

#importonce

//////////////////////////////////////////////////////////////////
// Various Memory Constants
//
// Safe zero page locations (C128 native mode):
// $02-$0A  generally safe for ML programs
// $57-$60  safe (avoid $61-$70 if also using BASIC floating point)
// $A3-$B1  safe
// $F7-$FE  safe
//
// Note: zp_tmp ($FB/$FC) aliases the same locations as sprite.il.asm's
//   rs_srcLo/rs_srcHi ($FB/$FC). Do not call sprite routines and print
//   routines within the same interrupt context simultaneously.
//
// Note: zp_ptr_color is $62/$63 on C128 (differs from C64's $A3/$A4)
//   to avoid overwriting zp_temp which is at $A3 and used by sprite_obj.
//

.const SECONDARY_ADDRESS    = $B9
.const DEVICE_NUMBER        = $BA
.const PNTR                 = $D3
.const CURSOR_X_POS         = $D3
.const TBLX                 = $D6
.const CURSOR_Y_POS         = $D6
.const CURSOR_COLOR         = $0286
.const VICSCN               = $0400
.const SCREEN_RAM           = $0400
.const COLOR_RAM            = $D800
.const TEMP_1               = $FB
.const TEMP_2               = $FC
.const zp_tmp               = $FB
.const zp_tmp_lo            = $FB
.const zp_tmp_hi            = $FC
.const zp_timers            = $F7
.const zp_timers_lo         = $F7
.const zp_timers_hi         = $F8
.const zp_string            = $FD
.const zp_string_lo         = $FD
.const zp_string_hi         = $FE
.const zp_str2              = $02
.const zp_str2_lo           = $02
.const zp_str2_hi           = $03
.const TEMP_7               = $04
.const TEMP_8               = $05
.const zp_ptr_screen        = $60
.const zp_ptr_screen_lo     = $60
.const zp_ptr_screen_hi     = $61
.const zp_ptr_color         = $62
.const zp_ptr_color_lo      = $62
.const zp_ptr_color_hi      = $63
.const zp_point_tmp         = $59
.const zp_point_tmp_lo      = $59
.const zp_point_tmp_hi      = $5A
.const zp_ptr_2             = $64
.const zp_ptr_2_lo          = $64
.const zp_ptr_2_hi          = $65
.const zp_temp              = $A3
.const zp_temp2             = $A4
.const zp_temp3             = $A5
.const JOYPORT_TIMER        = $05

//////////////////////////////////////////////////////////////////
// VARIOUS STUFF
.const ZP_DATA_DIRECTION    = $00
.const ZP_IO_REGISTER       = $01

.const SCREEN_MEM_POINTER   = $0288
.const KERNAL_STOP_VECTOR   = $0328

//////////////////////////////////////////////////////////////////
// SPRITE POINTERS
.const SPRITE_POINTERS      = $7F8
.const SPRITE_0_POINTER     = $7F8
.const SPRITE_1_POINTER     = $7F9
.const SPRITE_2_POINTER     = $7FA
.const SPRITE_3_POINTER     = $7FB
.const SPRITE_4_POINTER     = $7FC
.const SPRITE_5_POINTER     = $7FD
.const SPRITE_6_POINTER     = $7FE
.const SPRITE_7_POINTER     = $7FF

//////////////////////////////////////////////////////////////////
// VIC-IIe CONSTANTS (same registers as C64 in 40-column mode)
.const SPRITE_LOCATIONS     = $D000
.const SPRITE_0_X           = $D000 // 53248 SP0X Sprite 0 Horizontal Position
.const SPRITE_0_Y           = $D001 // 53249 SP0Y Sprite 0 Vertical Position
.const SPRITE_1_X           = $D002 // 53250 SP1X Sprite 1 Horizontal Position
.const SPRITE_1_Y           = $D003 // 53251 SP1Y Sprite 1 Vertical Position
.const SPRITE_2_X           = $D004 // 53252 SP2X Sprite 2 Horizontal Position
.const SPRITE_2_Y           = $D005 // 53253 SP2Y Sprite 2 Vertical Position
.const SPRITE_3_X           = $D006 // 53254 SP3X Sprite 3 Horizontal Position
.const SPRITE_3_Y           = $D007 // 53255 SP3Y Sprite 3 Vertical Position
.const SPRITE_4_X           = $D008 // 53256 SP4X Sprite 4 Horizontal Position
.const SPRITE_4_Y           = $D009 // 53257 SP4Y Sprite 4 Vertical Position
.const SPRITE_5_X           = $D00A // 53258 SP5X Sprite 5 Horizontal Position
.const SPRITE_5_Y           = $D00B // 53259 SP5Y Sprite 5 Vertical Position
.const SPRITE_6_X           = $D00C // 53260 SP6X Sprite 6 Horizontal Position
.const SPRITE_6_Y           = $D00D // 53261 SP6Y Sprite 6 Vertical Position
.const SPRITE_7_X           = $D00E // 53262 SP7X Sprite 7 Horizontal Position
.const SPRITE_7_Y           = $D00F // 53263 SP7Y Sprite 7 Vertical Position
.const SPRITE_LOCATIONS_MSB = $D010 // 53264 Most Significant Bits of Sprites 0-7 Horizontal Position
.const SPRITE_MSB_X         = $D010 // 53264 Most Significant Bits of Sprites 0-7 Horizontal Position
.const VIC_CONTROL_REG_1    = $D011 // 53265 RST8 ECM- BMM- DEN- RSEL [   YSCROLL   ]
.const VIC_RASTER_COUNTER   = $D012 // 53266
.const VIC_LIGHT_PEN_X      = $D013 // 53267
.const VIC_LIGHT_PEN_Y      = $D014 // 53268
.const SPRITE_ENABLE        = $D015 // 53269
.const VIC_CONTROL_REG_2    = $D016 // 53270 ---- ---- RES- MCM- CSEL [   XSCROLL   ]
.const SPRITE_EXPAND_Y      = $D017 // 53271
.const VIC_MEM_POINTERS     = $D018 // 53272 VM13 VM12 VM11 VM10 CB13 CB12 CB11 ----
.const VIC_INTERRUPT_REG    = $D019 // 53273 IRQ- ---- ---- ---- ILP- IMMC IMBC IRST
.const VIC_INTERRUPT_ENABLE = $D01A // 53274 ---- ---- ---- ---- ELP- EMMC EMBC ERST
.const SPRITE_PRIORITY      = $D01B // 53275
.const SPRITE_MULTICOLOR    = $D01C // 53276
.const SPRITE_EXPAND_X      = $D01D // 53277
.const SPRITE_COLLISION_SPR = $D01E // 53278
.const SPRITE_COLLISION_DATA= $D01F // 53279
.const BORDER_COLOR         = $D020 // 53280
.const BACKGROUND_COLOR     = $D021 // 53281
.const BACKGROUND_COLOR_1   = $D022 // 53282
.const BACKGROUND_COLOR_2   = $D023 // 53283
.const BACKGROUND_COLOR_3   = $D024 // 53284
.const SPRITE_MULTICOLOR_0  = $D025
.const SPRITE_MULTICOLOR_1  = $D026
.const SPRITE_COLORS        = $D027
.const SPRITE_0_COLOR       = $D027
.const SPRITE_1_COLOR       = $D028
.const SPRITE_2_COLOR       = $D029
.const SPRITE_3_COLOR       = $D02A
.const SPRITE_4_COLOR       = $D02B
.const SPRITE_5_COLOR       = $D02C
.const SPRITE_6_COLOR       = $D02D
.const SPRITE_7_COLOR       = $D02E

//////////////////////////////////////////////////////////////////
// C128 2MHz MODE
// Write to this register to toggle CPU speed.
.const C128_2MHZ_REG        = $D030  // Bit 0: 1=2MHz (FAST), 0=1MHz (SLOW)

//////////////////////////////////////////////////////////////////
// C128 MMU (Memory Management Unit)
// The MMU is always accessible at $FF00-$FF04 in the CPU address space.
// It is also visible at $D500-$D50B when I/O is mapped (normal operation).
.const MMU_CR               = $FF00  // Configuration Register (always accessible)
.const MMU_LCRA             = $FF01  // Pre-configuration Register 0
.const MMU_LCRB             = $FF02  // Pre-configuration Register 1
.const MMU_LCRC             = $FF03  // Pre-configuration Register 2
.const MMU_LCRD             = $FF04  // Pre-configuration Register 3
.const MMU_IO_CR            = $D500  // Configuration Register (I/O visible)
.const MMU_IO_LCRA          = $D501  // Pre-configuration Register 0 (I/O visible)
.const MMU_IO_LCRB          = $D502  // Pre-configuration Register 1 (I/O visible)
.const MMU_IO_LCRC          = $D503  // Pre-configuration Register 2 (I/O visible)
.const MMU_IO_LCRD          = $D504  // Pre-configuration Register 3 (I/O visible)
.const MMU_IO_MCRLO         = $D505  // Mode Configuration Register Lo
.const MMU_IO_RCR           = $D506  // RAM Configuration Register
.const MMU_IO_P0H           = $D507  // Page 0 Pointer Hi
.const MMU_IO_P0L           = $D508  // Page 0 Pointer Lo
.const MMU_IO_P1H           = $D509  // Page 1 Pointer Hi
.const MMU_IO_P1L           = $D50A  // Page 1 Pointer Lo
.const MMU_IO_VR            = $D50B  // Version Register (read only)

//////////////////////////////////////////////////////////////////
// VDC (Video Display Controller) - 80 Column Chip at $D600
// Access: write internal register index to VDC_ADDRESS,
//   then read or write VDC_DATA. Poll bit 7 of VDC_ADDRESS for ready.
.const VDC_ADDRESS          = $D600  // Address/Status register (write=index, read=status)
.const VDC_DATA             = $D601  // Data register (read/write after selecting index)
// VDC internal register indices:
.const VDC_TOTAL_CHARS      = 0   // Total horizontal characters
.const VDC_DISP_CHARS       = 1   // Displayed characters per row (normally 80)
.const VDC_HSYNC_POS        = 2   // Horizontal sync position
.const VDC_HSYNC_WIDTH      = 3   // Horizontal/vertical sync width
.const VDC_TOTAL_ROWS       = 4   // Total vertical rows (adjusted)
.const VDC_VERT_FINE_ADJ    = 5   // Vertical fine adjust
.const VDC_DISP_ROWS        = 6   // Displayed rows (normally 25)
.const VDC_VSYNC_ROW        = 7   // Vertical sync position
.const VDC_INTERLACE_MODE   = 8   // Interlace mode
.const VDC_CHAR_HEIGHT      = 9   // Character height in scan lines minus 1
.const VDC_CURSOR_MODE      = 10  // Cursor mode / blink rate
.const VDC_CURSOR_END       = 11  // Cursor end scan line
.const VDC_DISP_ADDR_HI     = 12  // Display start address hi
.const VDC_DISP_ADDR_LO     = 13  // Display start address lo
.const VDC_CURSOR_ADDR_HI   = 14  // Cursor position address hi
.const VDC_CURSOR_ADDR_LO   = 15  // Cursor position address lo
.const VDC_LIGHT_PEN_VERT   = 16  // Light pen vertical position (read only)
.const VDC_LIGHT_PEN_HOR    = 17  // Light pen horizontal position (read only)
.const VDC_UPD_ADDR_HI      = 18  // Update address hi (for block copy/fill)
.const VDC_UPD_ADDR_LO      = 19  // Update address lo
.const VDC_ATTR_ADDR_HI     = 20  // Attribute start address hi
.const VDC_ATTR_ADDR_LO     = 21  // Attribute start address lo
.const VDC_CHAR_TOTAL_VERT  = 22  // Character total/vertical (hi=total, lo=disp)
.const VDC_CHAR_DISP_VERT   = 23  // Character display vertical (scan lines)
.const VDC_VERT_SMOOTH_SCR  = 24  // Vertical smooth scroll / blink rate
.const VDC_HOR_SMOOTH_SCR   = 25  // Horizontal smooth scroll / semi-graphics
.const VDC_FORE_BACK_COLOR  = 26  // Foreground/background color
.const VDC_ROW_ATTR_LO      = 27  // Row/attribute address lo
.const VDC_CHAR_BASE_ADDR   = 28  // Character base address / semigraphics mode
.const VDC_UNDERLINE_SCAN   = 29  // Underline scan line
.const VDC_WORD_COUNT       = 30  // Word count for block copy/fill (lo byte)
.const VDC_DATA_REGISTER    = 31  // Data register for block fill / copy source
.const VDC_BLOCK_COPY_SRC_HI = 33 // Block copy source address hi
.const VDC_BLOCK_COPY_SRC_LO = 34 // Block copy source address lo
.const VDC_DISP_ENABLE_BGN  = 35  // Display enable begin
.const VDC_DISP_ENABLE_END  = 36  // Display enable end
.const VDC_RAM_REFRESH      = 37  // RAM refresh cycles per horizontal line

//////////////////////////////////////////////////////////////////
// SID CONSTANTS (same as C64)
.const SID_V1_FREQ_LOW      = $D400 // (54272) frequency voice 1 low byte
.const SID_V1_FREQ_HIGH     = $D401 // (54273) frequency voice 1 high byte
.const SID_V1_PULSE_LOW     = $D402 // (54274) pulse wave duty cycle voice 1 low byte
.const SID_V1_PULSE_HIGH    = $D403 // (54275) pulse wave duty cycle voice 1 high byte
.const SID_V1_CONTROL_REG   = $D404 // (54276) control register voice 1
.const SID_V1_ATK_DECAY     = $D405 // (54277) attack/decay voice 1
.const SID_V1_SUS_REL       = $D406 // (54278) sustain/release voice 1
.const SID_V2_FREQ_LOW      = $D407 // (54279) frequency voice 2 low byte
.const SID_V2_FREQ_HIGH     = $D408 // (54280) frequency voice 2 high byte
.const SID_V2_PULSE_LOW     = $D409 // (54281) pulse wave duty cycle voice 2 low byte
.const SID_V2_PULSE_HIGH    = $D40A // (54282) pulse wave duty cycle voice 2 high byte
.const SID_V2_CONTROL_REG   = $D40B // (54283) control register voice 2
.const SID_V2_ATK_DECAY     = $D40C // (54284) attack/decay voice 2
.const SID_V2_SUS_REL       = $D40D // (54285) sustain/release voice 2
.const SID_V3_FREQ_LOW      = $D40E // (54286) frequency voice 3 low byte
.const SID_V3_FREQ_HIGH     = $D40F // (54287) frequency voice 3 high byte
.const SID_V3_PULSE_LOW     = $D410 // (54288) pulse wave duty cycle voice 3 low byte
.const SID_V3_PULSE_HIGH    = $D411 // (54289) pulse wave duty cycle voice 3 high byte
.const SID_V3_CONTROL_REG   = $D412 // (54290) control register voice 3
.const SID_V3_ATK_DECAY     = $D413 // (54291) attack/decay voice 3
.const SID_V3_SUS_REL       = $D414 // (54292) sustain/release voice 3
.const SID_FILTER_CUTOFF_LOW= $D415 // (54293) filter cutoff frequency low byte
.const SID_FILTER_CUTOFF_HIGH=$D416 // (54294) filter cutoff frequency high byte
.const SID_FILTER_RESONANCE = $D417 // (54295) filter resonance and routing
.const SID_VOLUME_FILTER    = $D418 // (54296) filter mode and main volume
.const PADDLE_X             = $D419 // (54297) paddle x (read only)
.const PADDLE_Y             = $D41A // (54298) paddle y (read only)
.const SID_OSCILLATOR_V3    = $D41B // (54299) oscillator voice 3 (read only)
.const SID_ENVELOPE_V3      = $D41C // (54300) envelope voice 3 (read only)

//////////////////////////////////////////////////////////////////
// IO CONSTANTS (same CIA chip addresses as C64)
.const JOYSTICK_PORT_2      = $DC00
.const JOY2_NONE            = $7F
.const CIA_1                = $DC00
.const JOYSTICK_PORT_1      = $DC01
.const JOY1_NONE            = $FF

.const CIA_2                = $DD00  // 0-1 VIC bank (00: bank3, 01: bank2, 10: bank1, 11: bank0)
                                     // 7 serial data in, 6 serial clock in
                                     // 5 serial data out, 4 serial clock out
                                     // 3 serial atn out, 2 rs232 txd

//////////////////////////////////////////////////////////////////
// User Port Stuff
.const USER_PORT_DATA       = $DD01  // User Port Data
.const USER_PORT_DATA_DIR   = $DD03  // User Port Data Direction (1=output, 0=input per bit)

//////////////////////////////////////////////////////////////////
// 1541 Ultimate II Command Interface
.const UII_CONTROL          = $DF1C  // CONTROL REGISTER (WRITE)
.const UII_STATUS           = $DF1C  // STATUS REGISTER (READ)
.const UII_COMMAND          = $DF1D  // COMMAND DATA REGISTER (WRITE)
.const UII_ID               = $DF1D  // IDENTIFICATION REGISTER (READ) $C9
.const UII_RESPONSE         = $DF1E  // RESPONSE DATA REGISTER (READ ONLY)
.const UII_STATUS_DATA      = $DF1F  // STATUS DATA REGISTER

//////////////////////////////////////////////////////////////////
// KERNAL JUMP TABLE (same addresses as C64 for backward compatibility)
.const KERNAL_SCINIT        = $FF81  // Initialize screen editor and devices
.const KERNAL_IOINIT        = $FF84  // Initialize system I/O
.const KERNAL_RAMTAS        = $FF87  // Initialize RAM and test
.const KERNAL_RESTOR        = $FF8A  // Initialize KERNAL indirects
.const KERNAL_VECTOR        = $FF8D  // Copy/swap user and KERNAL vectors
.const KERNAL_SETMSG        = $FF90  // Set KERNAL message output flag
.const KERNAL_LSTNSA        = $FF93  // Send LISTEN secondary address
.const KERNAL_SECLSN        = $FF93  // Send LISTEN secondary address (alias)
.const KERNAL_TALKSA        = $FF96  // Send TALK secondary address
.const KERNAL_SECTLK        = $FF96  // Send TALK secondary address (alias)
.const KERNAL_MEMBOT        = $FF99  // Set/read bottom of system RAM
.const KERNAL_MEMTOP        = $FF9C  // Set/read top of system RAM
.const KERNAL_SCNKEY        = $FF9F  // Scan keyboard
.const KERNAL_SETTMO        = $FFA2  // Set serial bus timeout
.const KERNAL_IECIN         = $FFA5  // Serial bus byte input
.const KERNAL_IECOUT        = $FFA8  // Serial bus byte output
.const KERNAL_UNTALK        = $FFAB  // Send UNTALK command
.const KERNAL_UNLSTN        = $FFAE  // Send UNLISTEN command
.const KERNAL_LISTEN        = $FFB1  // Send LISTEN command
.const KERNAL_TALK          = $FFB4  // Send TALK command
.const KERNAL_READST        = $FFB7  // Read I/O status byte
.const KERNAL_SETLFS        = $FFBA  // Set logical file, device, secondary address
.const KERNAL_SETNAM        = $FFBD  // Set filename pointer and length
.const KERNAL_OPEN          = $FFC0  // Open logical file
.const KERNAL_CLOSE         = $FFC3  // Close logical file
.const KERNAL_CHKIN         = $FFC6  // Set input channel
.const KERNAL_CHKOUT        = $FFC9  // Set output channel
.const KERNAL_CLRCHN        = $FFCC  // Restore default I/O channels
.const KERNAL_CHRIN         = $FFCF  // Input character from channel
.const KERNAL_CHROUT        = $FFD2  // Output character to channel
.const KERNAL_LOAD          = $FFD5  // Load from file
.const KERNAL_SAVE          = $FFD8  // Save to file
.const KERNAL_SETTIM        = $FFDB  // Set internal clock (TOD)
.const KERNAL_RDTIM         = $FFDE  // Read internal clock (TOD)
.const KERNAL_STOP          = $FFE1  // Scan STOP key
.const KERNAL_GETIN         = $FFE4  // Read buffered keyboard input
.const KERNAL_CLALL         = $FFE7  // Close all files and channels
.const KERNAL_UDTIM         = $FFEA  // Increment internal clock
.const KERNAL_SCREEN        = $FFED  // Get screen dimensions
.const KERNAL_PLOT          = $FFF0  // Read/set cursor position
.const KERNAL_IOBASE        = $FFF3  // Read base address of I/O block

//////////////////////////////////////////////////////////////////
// NEW C128 KERNAL ENTRIES (not available on C64)
.const KERNAL_SPIN_SPOUT    = $FF47  // Setup fast serial ports for I/O
.const KERNAL_CLOSE_ALL     = $FF4A  // Close all files on a device (A = device number)
.const KERNAL_C64MODE       = $FF4D  // Reconfigure system as C64
.const KERNAL_DMA_CALL      = $FF50  // Send command to DMA device
.const KERNAL_BOOT_CALL     = $FF53  // Boot load program from disk
.const KERNAL_PHOENIX       = $FF56  // Initialize function cartridges
.const KERNAL_LKUPLA        = $FF59  // Search file table for given logical address
.const KERNAL_LKUPSA        = $FF5C  // Search file table for given secondary address
.const KERNAL_SWAPPER       = $FF5F  // Switch active screen between 40 and 80 columns
.const KERNAL_DLCHR         = $FF62  // Initialize 80-column character RAM from ROM
.const KERNAL_PFKEY         = $FF65  // Program a function key (X=key, Y/A=string ptr)
.const KERNAL_SETBNK        = $FF68  // Set bank for LOAD/SAVE/verify I/O (A=bank)
.const KERNAL_GETCFG        = $FF6B  // Lookup MMU configuration data for given bank
.const KERNAL_JSRFAR        = $FF6E  // JSR to routine in any memory bank
.const KERNAL_JMPFAR        = $FF71  // JMP to routine in any memory bank
.const KERNAL_INDFET        = $FF74  // LDA (fetvec),Y from any bank
.const KERNAL_INDSTA        = $FF77  // STA (stavec),Y to any bank
.const KERNAL_INDCMP        = $FF7A  // CMP (cmpvec),Y against any bank
.const KERNAL_PRIMM         = $FF7D  // Print immediate string (null-terminated, follows JSR)

//////////////////////////////////////////////////////////////////
// INTERNAL KERNAL ROUTINES (C128 native mode)
// Note: These are ROM-internal addresses, NOT jump table entries.
// The KERNAL jump table entries above ($FF47-$FFF3) are preferred.
// KERNAL_IRQ_ENTRY: chain target for custom IRQ handlers installed at $0314/$0315.
// Equivalent to C64's $EA31 (keyboard scan + TOD clock update).
.const KERNAL_IRQ_ENTRY     = $FA65  // C128 KERNAL IRQ entry (keyboard scan / TOD)

//////////////////////////////////////////////////////////////////
// KERNAL WAIT
.const KERNAL_WAIT_KEY      = $F142  // C64 address — verify C128 ROM address before use

//////////////////////////////////////////////////////////////////
// KEYS (PETSCII codes — same as C64)
.const KEY_RETURN       = $0D
.const LINE_FEED        = $0D
.const KEY_HOME         = $13
.const KEY_DELETE       = $14
.const KEY_SPACE        = $20
.const KEY_DOLLAR_SIGN  = $24
.const KEY_ASTERISK     = $2A
.const KEY_MINUS        = $2D
.const KEY_PLUS         = $2B
.const KEY_COLON        = $3A
.const KEY_SEMICOLON    = $3B
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
.const KEY_EQUAL        = $3D
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
.const KEY_J            = $4A
.const KEY_K            = $4B
.const KEY_L            = $4C
.const KEY_M            = $4D
.const KEY_N            = $4E
.const KEY_O            = $4F
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
.const KEY_Z            = $5A
.const KEY_F1           = $85
.const KEY_F2           = $89
.const KEY_F3           = $86
.const KEY_F4           = $8A
.const KEY_F5           = $87
.const KEY_F6           = $8B
.const KEY_F7           = $88
.const KEY_F8           = $8C  // C128 adds F9-F14 on the extended keypad
.const KEY_F9           = $8D  // C128 extended function key
.const KEY_F10          = $8E  // C128 extended function key
.const KEY_F11          = $8F  // C128 extended function key
.const KEY_F12          = $90  // C128 extended function key
.const KEY_CURSOR_UP    = $91
.const KEY_CURSOR_DOWN  = $11
.const KEY_CURSOR_LEFT  = $9D
.const KEY_CURSOR_RIGHT = $1D
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

//////////////////////////////////////////////////////////////////
// Floating Point Arithmetic (C128 BASIC 7.0)
//
// C128 BASIC 7.0 floating point routines are at different ROM addresses
// than C64 BASIC 2.0. The constants below are NOT provided because the
// specific addresses depend on the exact C128 ROM revision.
//
// To use floating point routines in C128 native mode, look up the correct
// addresses in the C128 Programmer's Reference Guide, Chapter 5 (Math
// Routines), and add them here as:
//   .const FADD  = $xxxx   // Add FAC and RAM
//   .const FADDT = $xxxx   // Add FAC and ARG
//   .const FSUB  = $xxxx   // Subtract
//   etc.
//
// FAC and ARG register layout is the same as C64 (same zero-page layout):
//   FAC exponent:  $61, mantissa: $62-$65, sign: $66, round: $70
//   ARG exponent:  $69, mantissa: $6A-$6D, sign: $6E

