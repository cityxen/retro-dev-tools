//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — KickAssembler Macros
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// Notes:
//  - Must include Constants.asm before Macros.asm
//  - These macros expand inline; use sparingly in hot loops.
//  - VIC-20 screen: 22 columns × 23 rows (unexpanded default)
//  - Border/background share register $900F (unlike C64's $D020/$D021)
//////////////////////////////////////////////////////////////////

#import "Constants.asm"

//////////////////////////////////////////////////////////////////
// Screen and color

// SetBorderColor(n): set border color (bits 3-1 of $900F; n must be 0-7).
.macro SetBorderColor(n) {
    lda VIC_SCREEN_COLOR
    and #%11110001          // clear bits 3-1
    ora #[n << 1]           // set border color bits
    sta VIC_SCREEN_COLOR
}

// SetBackgroundColor(n): set background color (bits 7-4 of $900F; n must be 0-7).
.macro SetBackgroundColor(n) {
    lda VIC_SCREEN_COLOR
    and #%00001111          // clear bits 7-4
    ora #[n << 4]           // set background color bits
    sta VIC_SCREEN_COLOR
}

// SetScreenColors(border, background): set both border and background.
.macro SetScreenColors(border, background) {
    lda #[(background << 4) | (border << 1)]
    sta VIC_SCREEN_COLOR
}

// ClearScreen(): clear screen via KERNAL (chr $93) and reset colors to defaults.
.macro ClearScreen() {
    lda #$93
    jsr KERNAL_CHROUT
}

// ClearScreenColors(border, background): clear and set colors.
.macro ClearScreenColors(border, background) {
    lda #$93
    jsr KERNAL_CHROUT
    SetScreenColors(border, background)
}

// SetVolume(v): set master volume (0-15).
.macro SetVolume(v) {
    lda VIC_SOUND_VOLUME
    and #$f0
    ora #[v & $0f]
    sta VIC_SOUND_VOLUME
}

// SilenceAll(): mute all VIC sound voices.
.macro SilenceAll() {
    lda #$00
    sta VIC_SOUND_VOICE1
    sta VIC_SOUND_VOICE2
    sta VIC_SOUND_VOICE3
    sta VIC_SOUND_NOISE
    sta VIC_SOUND_VOLUME
}

//////////////////////////////////////////////////////////////////
// BASIC Upstart (VIC-20 unexpanded — BASIC RAM starts at $1001)

.macro CityXenUpstart(start) {

* = $1001 "BASIC Upstart"
.word usend             // link address
.word 2026              // line number
.byte $9e               // SYS token
.text toIntString(start)
.text ":"
.byte $80               // end of BASIC line
.text ":"
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE
.text " -=*(CITYXEN)*=-"
usend:
.byte 0
.word 0
* = $1020 "vars and lib init"

}

// CityXenUpstart3K(start): for VIC-20 with +3K expansion (BASIC at $0401).
.macro CityXenUpstart3K(start) {

* = $0401 "BASIC Upstart"
.word usend3k
.word 2026
.byte $9e
.text toIntString(start)
.text ":"
.byte $80
.text ":"
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE,KEY_DELETE,KEY_DELETE,KEY_DELETE
.byte KEY_DELETE
.text " -=*(CITYXEN)*=-"
usend3k:
.byte 0
.word 0
* = $0420 "vars and lib init"

}

//////////////////////////////////////////////////////////////////
// Zero-page pointer helper

.macro zp_str(x) {
    lda #<x
    sta zp_tmp_lo
    lda #>x
    sta zp_tmp_hi
}

//////////////////////////////////////////////////////////////////
// Key dispatch helpers

.macro ReadKeyJSR(x,sbr) {
!check_key:
    cmp #x
    bne !check_key+
    jsr sbr
!check_key:
}

.macro ReadKeyJMP(x,sbr) {
!check_key:
    cmp #x
    bne !check_key+
    jmp sbr
!check_key:
}

.macro KeySub(key,subroutine) {
    cmp #key
    bne !+
    jsr subroutine
!:
}

.macro KeyJmp(key,label) {
    cmp #key
    bne !+
    jmp label
!:
}

//////////////////////////////////////////////////////////////////
// Joystick read helpers (active-low: 0 = direction pressed)

// ReadJoyJSR(dir, sbr): if joystick direction pressed, JSR sbr.
// dir: "UP","DOWN","LEFT","RIGHT","FIRE"
.macro ReadJoyJSR(dir,sbr) {
    .if (dir=="UP")    { lda JOYSTICK_PORT : and #JOY_UP_BIT    : bne !+    : jsr sbr }
    .if (dir=="DOWN")  { lda JOYSTICK_PORT : and #JOY_DOWN_BIT  : bne !+    : jsr sbr }
    .if (dir=="LEFT")  { lda JOYSTICK_PORT : and #JOY_LEFT_BIT  : bne !+    : jsr sbr }
    .if (dir=="RIGHT") { lda JOYSTICK_PORT : and #JOY_RIGHT_BIT : bne !+    : jsr sbr }
    .if (dir=="FIRE")  { lda JOYSTICK_FIRE_REG : and #JOY_FIRE_BIT : bne !+ : jsr sbr }
!:
}

.macro ReadJoyJMP(dir,sbr) {
    .if (dir=="UP")    { lda JOYSTICK_PORT : and #JOY_UP_BIT    : bne !+    : jmp sbr }
    .if (dir=="DOWN")  { lda JOYSTICK_PORT : and #JOY_DOWN_BIT  : bne !+    : jmp sbr }
    .if (dir=="LEFT")  { lda JOYSTICK_PORT : and #JOY_LEFT_BIT  : bne !+    : jmp sbr }
    .if (dir=="RIGHT") { lda JOYSTICK_PORT : and #JOY_RIGHT_BIT : bne !+    : jmp sbr }
    .if (dir=="FIRE")  { lda JOYSTICK_FIRE_REG : and #JOY_FIRE_BIT : bne !+ : jmp sbr }
!:
}

//////////////////////////////////////////////////////////////////
// Wait for any key

.macro WaitKey() {
    lda #$00
!:
    jsr KERNAL_GETIN
    beq !-
}

//////////////////////////////////////////////////////////////////
// Joystick direction bit masks (for use with AND against $9111)

.const STICK_UP    = JOY_UP_BIT
.const STICK_DOWN  = JOY_DOWN_BIT
.const STICK_LEFT  = JOY_LEFT_BIT
.const STICK_RIGHT = JOY_RIGHT_BIT
.const STICK_NONE  = $3C    // bits 2-5 all set = no direction pressed
