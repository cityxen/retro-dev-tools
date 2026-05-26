//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Hardware Constants
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////

#importonce

//////////////////////////////////////////////////////////////////
// GTIA — Graphics Television Interface Adaptor
// Write addresses ($D000-$D01F)

.const HPOSP0   = $D000   // horizontal position: player 0
.const HPOSP1   = $D001   // horizontal position: player 1
.const HPOSP2   = $D002   // horizontal position: player 2
.const HPOSP3   = $D003   // horizontal position: player 3
.const HPOSM0   = $D004   // horizontal position: missile 0
.const HPOSM1   = $D005   // horizontal position: missile 1
.const HPOSM2   = $D006   // horizontal position: missile 2
.const HPOSM3   = $D007   // horizontal position: missile 3
.const SIZEP0   = $D008   // player 0 size (00=normal,01=double,11=quad)
.const SIZEP1   = $D009   // player 1 size
.const SIZEP2   = $D00A   // player 2 size
.const SIZEP3   = $D00B   // player 3 size
.const SIZEM    = $D00C   // missile sizes (2 bits each)
.const GRAFP0   = $D00D   // player 0 graphics register
.const GRAFP1   = $D00E   // player 1 graphics register
.const GRAFP2   = $D00F   // player 2 graphics register
.const GRAFP3   = $D010   // player 3 graphics register
.const GRAFM    = $D011   // missile graphics register
.const COLPM0   = $D012   // player/missile 0 color
.const COLPM1   = $D013   // player/missile 1 color
.const COLPM2   = $D014   // player/missile 2 color
.const COLPM3   = $D015   // player/missile 3 color
.const COLPF0   = $D016   // playfield color 0
.const COLPF1   = $D017   // playfield color 1
.const COLPF2   = $D018   // playfield color 2 (GR.8 foreground pixel color)
.const COLPF3   = $D019   // playfield color 3
.const COLBK    = $D01A   // background color
.const PRIOR    = $D01B   // priority control register
.const VDELAY   = $D01C   // vertical delay
.const GRACTL   = $D01D   // graphics control: enable P/M DMA and display
.const HITCLR   = $D01E   // write: clear all collision registers
.const CONSOL   = $D01F   // read: console keys (START/SELECT/OPTION); write: speaker

// GTIA read addresses (differ from write)
.const TRIG0    = $D010   // joystick 1 fire trigger (bit 0 = 0 when pressed)
.const TRIG1    = $D011   // joystick 2 fire trigger
.const TRIG2    = $D012   // joystick 3 fire trigger
.const TRIG3    = $D013   // joystick 4 fire trigger

//////////////////////////////////////////////////////////////////
// POKEY — Programmable Sound Generator + I/O Controller
// ($D200-$D20F)

.const AUDF1    = $D200   // audio channel 1 frequency
.const AUDC1    = $D201   // audio channel 1 control (bits 7-4: distortion, 3-0: volume)
.const AUDF2    = $D202   // audio channel 2 frequency
.const AUDC2    = $D203   // audio channel 2 control
.const AUDF3    = $D204   // audio channel 3 frequency
.const AUDC3    = $D205   // audio channel 3 control
.const AUDF4    = $D206   // audio channel 4 frequency
.const AUDC4    = $D207   // audio channel 4 control
.const AUDCTL   = $D208   // audio control register
.const KBCODE   = $D209   // keyboard scan code (read)
.const RANDOM   = $D20A   // hardware random number (read; changes each access)
.const SKRES    = $D20A   // reset serial status (write)
.const SKSTAT   = $D20F   // serial/keyboard status (read)
.const IRQEN    = $D20E   // IRQ enable register
.const IRQST    = $D20F   // IRQ status register (read)

// Audio distortion values (upper 4 bits of AUDCx)
.const AUDC_NOISE5    = $00   // 5-bit polynomial (noise)
.const AUDC_NOISE4    = $80   // 4-bit polynomial (noise, higher pitch)
.const AUDC_PURE      = $A0   // pure square wave (tone)
.const AUDC_PURE_HALF = $C0   // pure half frequency
.const AUDC_POLY_5_17 = $60   // 17-bit poly filtered through 5-bit poly

//////////////////////////////////////////////////////////////////
// PIA — Peripheral Interface Adaptor
// ($D300-$D303)

.const PORTA    = $D300   // joystick port 1&2 direction bits
                          // bits 3-0 = stick 1 (3=right,2=left,1=down,0=up; 0=pressed)
                          // bits 7-4 = stick 2
.const PORTB    = $D301   // port B (memory bank switching on 800XL)

//////////////////////////////////////////////////////////////////
// ANTIC — Alphanumeric Television Interface Controller
// ($D400-$D40F)

.const DMACTL   = $D400   // DMA control (use SDMCTL shadow instead)
.const CHACTL   = $D401   // character control
.const DLISTL   = $D402   // display list pointer low (use SDLSTL shadow)
.const DLISTH   = $D403   // display list pointer high (use SDLSTH shadow)
.const HSCROL   = $D404   // horizontal fine scroll
.const VSCROL   = $D405   // vertical fine scroll
.const PMBASE   = $D407   // player/missile base page (2KB or 1KB aligned)
.const CHBASE   = $D409   // character set base page
.const WSYNC    = $D40A   // write: wait for next horizontal sync
.const VCOUNT   = $D40B   // read: vertical line counter (0-131 NTSC)
.const NMIEN    = $D40E   // NMI enable: bit7=VBL, bit6=DLI
.const NMIST    = $D40F   // NMI status (read) / NMI reset (write)

// Display list mode bytes
.const DL_BLANK8  = $70   // 8 blank scan lines
.const DL_BLANK4  = $60   // 4 blank scan lines
.const DL_BLANK2  = $50   // 2 blank scan lines
.const DL_BLANK1  = $40   // 1 blank scan line
.const DL_GR0     = $02   // ANTIC mode 2: 40-col text, 8 scan lines/row
.const DL_GR8     = $0F   // ANTIC mode F: 320-pixel mono bitmap, 1 scan line/mode line
.const DL_LMS     = $40   // Load Memory Scan bit: append 2-byte address to mode byte
.const DL_HSCROL  = $10   // horizontal scroll enable bit
.const DL_VSCROL  = $20   // vertical scroll enable bit
.const DL_JMP     = $01   // display list JMP (+ address, wraps display list)
.const DL_JVB     = $41   // display list JMP with VBL (standard end-of-list)

// DMACTL / SDMCTL values
.const DMA_ENABLE_WIDE  = $22   // normal width, enable DMA, no P/M DMA
.const DMA_ENABLE_PM    = $2E   // normal width, enable DMA, enable P/M single-line DMA
.const DMA_OFF          = $00   // disable all DMA

//////////////////////////////////////////////////////////////////
// OS Shadow Registers (write here; OS copies to hardware each VBL)

.const SDMCTL   = $022F   // shadow of DMACTL
.const SDLSTL   = $0230   // shadow of DLISTL (display list pointer lo)
.const SDLSTH   = $0231   // shadow of DLISTH (display list pointer hi)
.const PCOLR0   = $02C0   // shadow of COLPM0
.const PCOLR1   = $02C1   // shadow of COLPM1
.const PCOLR2   = $02C2   // shadow of COLPM2
.const PCOLR3   = $02C3   // shadow of COLPM3
.const COLOR0   = $02C4   // shadow of COLPF0
.const COLOR1   = $02C5   // shadow of COLPF1
.const COLOR2   = $02C6   // shadow of COLPF2
.const COLOR3   = $02C7   // shadow of COLPF3
.const COLOR4   = $02C8   // shadow of COLBK
.const CHBAS    = $02F4   // shadow of CHBASE

//////////////////////////////////////////////////////////////////
// OS Joystick Shadows (updated each frame by OS VBL handler)

.const STICK0   = $0278   // joystick 0 direction shadow (bits: 3=R,2=L,1=D,0=U; 0=pressed)
.const STICK1   = $0279   // joystick 1 direction shadow
.const STRIG0   = $0284   // joystick 0 trigger shadow (0=pressed, 1=not pressed)
.const STRIG1   = $0285   // joystick 1 trigger shadow

//////////////////////////////////////////////////////////////////
// OS Real-Time Clock (incremented each VBL ~60Hz NTSC)

.const RTCLOK   = $0012   // real-time clock MSB (incremented least often)
.const RTCLOK1  = $0013   // real-time clock middle byte
.const RTCLOK2  = $0014   // real-time clock LSB (incremented every frame)

//////////////////////////////////////////////////////////////////
// OS Vectors

.const VVBLKI   = $0222   // immediate VBL vector (runs at VBL start)
.const VVBLKD   = $0224   // deferred VBL vector (runs after OS VBL processing)
.const XITVBL   = $E462   // OS exit-VBL: JMP here at end of custom VBL handler
.const SETVBL   = $E45C   // OS routine: install custom VBL handler

//////////////////////////////////////////////////////////////////
// OS Screen

.const SAVMSC   = $0058   // current screen memory address (set by OS)
.const RAMTOP   = $006A   // top of available RAM page (divide by 256 for page #)

//////////////////////////////////////////////////////////////////
// Zero Page (safe user area: $80-$FF; avoid $00-$7F = OS use)

.const ZP_PTR_LO  = $80   // general 16-bit pointer lo
.const ZP_PTR_HI  = $81   //                        hi
.const ZP_TMP     = $82   // scratch byte
.const ZP_TMP2    = $83   // scratch byte 2
.const ZP_TMP3    = $84   // scratch byte 3
.const ZP_SPR_LO  = $85   // sprite address accumulator lo
.const ZP_SPR_HI  = $86   //                             hi
.const ZP_PCUR_LO = $87   // print cursor lo (destination for print routines)
.const ZP_PCUR_HI = $88   //               hi
.const ZP_STR_LO  = $89   // secondary string pointer lo (strcpy source, etc.)
.const ZP_STR_HI  = $8A   //                           hi

//////////////////////////////////////////////////////////////////
// ATASCII → Screen Code Mapping
// Screen code = ATASCII - $20  (for printable chars $20-$7F)
// Screen code 0 = space, 33 = 'A', 16 = '0', 26 = ':', etc.

//////////////////////////////////////////////////////////////////
// Key Constants (KBCODE values from POKEY)

// CH ($02FC) — OS keyboard shadow, $FF when no key pending
.const CH         = $02FC

.const KEY_NONE   = $FF   // value in CH when no key pressed
.const KEY_SPACE  = $21
.const KEY_RETURN = $0C
.const KEY_ESC    = $1C
.const KEY_DEL    = $34
.const KEY_TAB    = $2C
.const KEY_A      = $3F
.const KEY_B      = $15
.const KEY_C      = $12
.const KEY_D      = $3A
.const KEY_E      = $2A
.const KEY_F      = $38
.const KEY_G      = $3D
.const KEY_H      = $39
.const KEY_I      = $0D
.const KEY_J      = $01
.const KEY_K      = $05
.const KEY_L      = $00
.const KEY_M      = $25
.const KEY_N      = $23
.const KEY_O      = $08
.const KEY_P      = $0A
.const KEY_Q      = $47
.const KEY_R      = $28
.const KEY_S      = $3E
.const KEY_T      = $2D
.const KEY_U      = $0B
.const KEY_V      = $10
.const KEY_W      = $2F
.const KEY_X      = $16
.const KEY_Y      = $2B
.const KEY_Z      = $17
.const KEY_0      = $32
.const KEY_1      = $1F
.const KEY_2      = $1E
.const KEY_3      = $1A
.const KEY_4      = $18
.const KEY_5      = $1D
.const KEY_6      = $1B
.const KEY_7      = $33
.const KEY_8      = $35
.const KEY_9      = $30
.const KEY_F1     = $03
.const KEY_F2     = $04
.const KEY_F3     = $13
.const KEY_F4     = $14
.const KEY_START  = $06   // Start console key via KBCODE (not standard)
.const KEY_SELECT = $07
.const KEY_OPTION = $0E

//////////////////////////////////////////////////////////////////
// Console Button Bits (CONSOL read)

.const CONSOL_START  = $01
.const CONSOL_SELECT = $02
.const CONSOL_OPTION = $04

//////////////////////////////////////////////////////////////////
// Color Values (Atari NTSC: upper 4 bits = hue, lower 4 bits = luminance)
// Luminance: 0 = darkest, 14 = brightest (must be even)

.const COLOR_BLACK      = $00
.const COLOR_WHITE      = $0E
.const COLOR_GRAY       = $08
.const COLOR_RED        = $32
.const COLOR_ORANGE     = $1A
.const COLOR_YELLOW     = $1C
.const COLOR_GREEN      = $C4
.const COLOR_BLUE       = $94
.const COLOR_CYAN       = $AC
.const COLOR_PURPLE     = $64

//////////////////////////////////////////////////////////////////
