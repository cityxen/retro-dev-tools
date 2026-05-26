//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — KickAssembler Macros
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Notes:
//  - Must include Constants.asm before Macros.asm
//  - These macros expand inline; use sparingly in hot loops.
//  - C16/Plus-4 screen: 40 columns × 25 rows
//  - Border ($FF19) and background ($FF15) are separate TED registers.
//  - TED color encoding: (hue << 4) | luminance  (use TED_* constants)
//////////////////////////////////////////////////////////////////

#import "Constants.asm"

//////////////////////////////////////////////////////////////////
// Screen and color

// SetBorderColor(n): set TED border color.
// n should be a TED_* color constant, e.g. TED_BLUE.
.macro SetBorderColor(n) {
    lda #n
    sta TED_BORDER_COLOR
}

// SetBackgroundColor(n): set TED background color.
.macro SetBackgroundColor(n) {
    lda #n
    sta TED_COLOR_BG
}

// SetScreenColors(border, background): set both border and background.
.macro SetScreenColors(border, background) {
    lda #border
    sta TED_BORDER_COLOR
    lda #background
    sta TED_COLOR_BG
}

// ClearScreen(): clear screen via KERNAL (chr $93).
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

// SetVolume(v): set TED master volume (bits 3-0 of $FF12; 0-15).
.macro SetVolume(v) {
    lda TED_SOUND_CTRL
    and #$f0
    ora #[v & $0f]
    sta TED_SOUND_CTRL
}

// SilenceAll(): disable all TED sound voices and set volume to 0.
.macro SilenceAll() {
    lda #$00
    sta TED_SOUND_CTRL
}

//////////////////////////////////////////////////////////////////
// BASIC Upstart (C16 / Plus-4 — BASIC 3.5 RAM starts at $1001)

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
// Joystick read helpers (active-low via TED keyboard matrix)

// ReadJoyJSR(dir, sbr): if joystick port 1 direction pressed, JSR sbr.
.macro ReadJoyJSR(dir,sbr) {
    .if (dir=="UP")    { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_UP_BIT    : beq !+    : bne !skip+ }
    .if (dir=="DOWN")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_DOWN_BIT  : beq !+    : bne !skip+ }
    .if (dir=="LEFT")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_LEFT_BIT  : beq !+    : bne !skip+ }
    .if (dir=="RIGHT") { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_RIGHT_BIT : beq !+    : bne !skip+ }
    .if (dir=="FIRE")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_FIRE_BIT  : beq !+    : bne !skip+ }
!:  jsr sbr
!skip:
}

.macro ReadJoyJMP(dir,sbr) {
    .if (dir=="UP")    { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_UP_BIT    : beq !+    : bne !skip+ }
    .if (dir=="DOWN")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_DOWN_BIT  : beq !+    : bne !skip+ }
    .if (dir=="LEFT")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_LEFT_BIT  : beq !+    : bne !skip+ }
    .if (dir=="RIGHT") { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_RIGHT_BIT : beq !+    : bne !skip+ }
    .if (dir=="FIRE")  { lda #JOY1_COL_SELECT : sta TED_KEYBOARD : lda TED_KEYBOARD : and #JOY_FIRE_BIT  : beq !+    : bne !skip+ }
!:  jmp sbr
!skip:
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
// Joystick direction bit mask aliases

.const STICK_UP    = JOY_UP_BIT
.const STICK_DOWN  = JOY_DOWN_BIT
.const STICK_LEFT  = JOY_LEFT_BIT
.const STICK_RIGHT = JOY_RIGHT_BIT
.const STICK_NONE  = $1F    // bits 0-4 all set = no direction pressed
