#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Joystick & keyboard input
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Uses Atari OS joystick shadows (updated each VBL frame):
//   STICK0 ($0278): bits 3=R, 2=L, 1=D, 0=U  (0 = direction active)
//   STRIG0 ($0284): 0 = fire pressed, 1 = not pressed
//
// Uses OS keyboard shadow CH ($02FC): $FF = no key pending.
//
// Joystick 1 API:
//   get_j1      — read STICK0/STRIG0 into j1_* variables
//   j1_stick    — raw STICK0 byte
//   j1_up/down/left/right — direction bits (0=active, nonzero=inactive)
//   j1_button   — 0=pressed, nonzero=not pressed (raw STRIG0)
//   j1_fired    — 1 if fire newly pressed this frame (edge detect)
//
// Keyboard API:
//   get_key     — read CH into k_value; $FF = no key
//   k_value     — last keyboard result ($FF = none)
//   WaitKey()   — macro: spin until any key pressed
//   KeySub(key, sub)    — macro: if A==key, JSR sub
//   KeyJmp(key, label)  — macro: if A==key, JMP label
//
// Combined:
//   get_any_input   — read joystick + key, set i_compare nonzero if any activity
//   i_compare       — nonzero if any input detected
//////////////////////////////////////////////////////////////////

// ─── Joystick 1 state ────────────────────────────────────────

j1_stick:       .byte $0F   // raw STICK0 ($0F = neutral)
j1_up:          .byte $01
j1_down:        .byte $02
j1_left:        .byte $04
j1_right:       .byte $08
j1_button:      .byte 1     // raw STRIG0 (1 = not pressed)
j1_prev_btn:    .byte 1     // previous STRIG0 for edge detection
j1_fired:       .byte 0     // 1 = fire newly pressed this frame

// get_j1: read STICK0 and STRIG0 into j1_* variables.
//         Call once per frame before checking directions.
get_j1:
    lda STICK0
    sta j1_stick
    and #STICK_UP
    sta j1_up
    lda j1_stick
    and #STICK_DOWN
    sta j1_down
    lda j1_stick
    and #STICK_LEFT
    sta j1_left
    lda j1_stick
    and #STICK_RIGHT
    sta j1_right
    // Fire button edge detection
    lda #0
    sta j1_fired
    lda STRIG0
    sta j1_button
    bne gj1_not_pressed     // STRIG0 nonzero = not pressed
    lda j1_prev_btn
    beq gj1_held            // was already pressed = held, not new
    lda #1
    sta j1_fired            // newly pressed
gj1_held:
    lda #0
    sta j1_prev_btn         // remember fire is down
    rts
gj1_not_pressed:
    lda #1
    sta j1_prev_btn         // remember fire is up
    rts

// ─── Keyboard ────────────────────────────────────────────────

k_value: .byte $FF

// get_key: read CH keyboard shadow into k_value.
//          Returns k_value in A.  $FF = no key pending.
get_key:
    lda CH
    cmp #KEY_NONE           // $FF = no key
    beq gk_none
    pha
    lda #KEY_NONE
    sta CH                  // consume the keypress
    pla
    sta k_value
    rts
gk_none:
    lda #KEY_NONE
    sta k_value
    rts

// WaitKey: spin until a key is pressed.
.macro WaitKey() {
!:
    jsr get_key
    cmp #KEY_NONE
    beq !-
}

// KeySub: if A (current key) == key, JSR subroutine.
.macro KeySub(key, subroutine) {
    cmp #key
    bne !+
    jsr subroutine
!:
}

// KeyJmp: if A (current key) == key, JMP label.
.macro KeyJmp(key, label) {
    cmp #key
    bne !+
    jmp label
!:
}

// ─── Any input ───────────────────────────────────────────────

i_compare: .byte 0

// get_any_input: checks joystick 1 and keyboard.
//                i_compare = nonzero if any input active.
get_any_input:
    lda #0
    sta i_compare

    jsr get_j1

    lda j1_button
    bne !+
    inc i_compare
!:
    lda j1_up
    bne !+
    inc i_compare
!:
    lda j1_down
    bne !+
    inc i_compare
!:
    lda j1_left
    bne !+
    inc i_compare
!:
    lda j1_right
    bne !+
    inc i_compare
!:

    jsr get_key
    lda k_value
    cmp #KEY_NONE
    beq !+
    inc i_compare
!:

    lda i_compare
    rts

//////////////////////////////////////////////////////////////////
