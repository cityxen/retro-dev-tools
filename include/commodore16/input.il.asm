//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Joystick & Keyboard Input
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// C16/Plus-4 joystick input uses the TED keyboard matrix ($FF08):
//   Write column select byte to $FF08, then read back $FF08.
//   Active low — 0 = direction pressed.
//
//   Joystick port 1: write $7F, read bits 0-4
//     bit 0 = Up, bit 1 = Down, bit 2 = Left, bit 3 = Right, bit 4 = Fire
//   Joystick port 2: write $BF, same bit layout
//
// NOTE: Exact bit positions should be verified against the Plus-4
// Programmer's Reference Guide for your specific hardware.
//
// Keyboard via KERNAL_GETIN ($FFE4) — PETSCII codes.
//
// API:
//   get_j1         — read joystick port 1 into j1_* vars
//   get_j2         — read joystick port 2 into j2_* vars
//   get_j1_m2      — method-2 history read (C64 library compatible)
//   j1_up/down/left/right/button — port 1 state ($ff = not pressed, 0 = pressed)
//   j2_up/down/left/right/button — port 2 state
//   get_key        — poll KERNAL_GETIN (timer-gated via TIMER_INPUT)
//   k_value        — last key from get_key (0 = none)
//   get_any_input  — check joystick + keyboard; i_compare = nonzero if any
//////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// Keyboard

k_value:    .byte 0

input_get_key:
get_key:
il_get_key:
    GetTimerTr(TIMER_INPUT)
    beq !+
    FullReset(TIMER_INPUT)
    jsr KERNAL_GETIN
    sta k_value
    rts
!:
    lda #$00
    sta k_value
    rts

////////////////////////////////////////////////////////////
// Joystick port 1 — Method 1: direct read

j1_up:      .byte $ff
j1_down:    .byte $ff
j1_left:    .byte $ff
j1_right:   .byte $ff
j1_button:  .byte $ff

// get_j1: read TED keyboard matrix (port 1) and populate j1_*.
// 0 = pressed, $ff = not pressed.
get_j1:
    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD

    lda TED_KEYBOARD
    and #JOY_UP_BIT
    beq gj1_up_on
    lda #$ff
    sta j1_up
    jmp gj1_up_done
gj1_up_on:
    lda #$00
    sta j1_up
gj1_up_done:

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_DOWN_BIT
    beq gj1_down_on
    lda #$ff
    sta j1_down
    jmp gj1_down_done
gj1_down_on:
    lda #$00
    sta j1_down
gj1_down_done:

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_LEFT_BIT
    beq gj1_left_on
    lda #$ff
    sta j1_left
    jmp gj1_left_done
gj1_left_on:
    lda #$00
    sta j1_left
gj1_left_done:

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_RIGHT_BIT
    beq gj1_right_on
    lda #$ff
    sta j1_right
    jmp gj1_right_done
gj1_right_on:
    lda #$00
    sta j1_right
gj1_right_done:

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_FIRE_BIT
    beq gj1_fire_on
    lda #$ff
    sta j1_button
    rts
gj1_fire_on:
    lda #$00
    sta j1_button
    rts

////////////////////////////////////////////////////////////
// Joystick port 2

j2_up:      .byte $ff
j2_down:    .byte $ff
j2_left:    .byte $ff
j2_right:   .byte $ff
j2_button:  .byte $ff

get_j2:
    lda #JOY2_COL_SELECT
    sta TED_KEYBOARD

    lda TED_KEYBOARD
    and #JOY_UP_BIT
    beq gj2_up_on
    lda #$ff
    sta j2_up
    jmp gj2_up_done
gj2_up_on:
    lda #$00
    sta j2_up
gj2_up_done:

    lda #JOY2_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_DOWN_BIT
    beq gj2_down_on
    lda #$ff
    sta j2_down
    jmp gj2_down_done
gj2_down_on:
    lda #$00
    sta j2_down
gj2_down_done:

    lda #JOY2_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_LEFT_BIT
    beq gj2_left_on
    lda #$ff
    sta j2_left
    jmp gj2_left_done
gj2_left_on:
    lda #$00
    sta j2_left
gj2_left_done:

    lda #JOY2_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_RIGHT_BIT
    beq gj2_right_on
    lda #$ff
    sta j2_right
    jmp gj2_right_done
gj2_right_on:
    lda #$00
    sta j2_right
gj2_right_done:

    lda #JOY2_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_FIRE_BIT
    beq gj2_fire_on
    lda #$ff
    sta j2_button
    rts
gj2_fire_on:
    lda #$00
    sta j2_button
    rts

////////////////////////////////////////////////////////////
// Joystick port 1 — Method 2: shift-register history (C64 library compatible)
// Uses 8-bit shift: $ff = never pressed, $00 = held, $7f/$80 = recently toggled.

get_j1_m2:
il_get_j1_m2:
    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_UP_BIT
    beq gm2_up_pressed
    lda #$01
    jmp gm2_up_shift
gm2_up_pressed:
    lda #$00
gm2_up_shift:
    asl j1_up
    ora j1_up
    sta j1_up

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_DOWN_BIT
    beq gm2_dn_pressed
    lda #$01
    jmp gm2_dn_shift
gm2_dn_pressed:
    lda #$00
gm2_dn_shift:
    asl j1_down
    ora j1_down
    sta j1_down

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_LEFT_BIT
    beq gm2_lt_pressed
    lda #$01
    jmp gm2_lt_shift
gm2_lt_pressed:
    lda #$00
gm2_lt_shift:
    asl j1_left
    ora j1_left
    sta j1_left

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_RIGHT_BIT
    beq gm2_rt_pressed
    lda #$01
    jmp gm2_rt_shift
gm2_rt_pressed:
    lda #$00
gm2_rt_shift:
    asl j1_right
    ora j1_right
    sta j1_right

    lda #JOY1_COL_SELECT
    sta TED_KEYBOARD
    lda TED_KEYBOARD
    and #JOY_FIRE_BIT
    beq gm2_fire_pressed
    lda #$01
    jmp gm2_fire_shift
gm2_fire_pressed:
    lda #$00
gm2_fire_shift:
    asl j1_button
    ora j1_button
    sta j1_button
    rts

////////////////////////////////////////////////////////////
// get_any_input: set i_compare nonzero if joystick or key active.

i_compare: .byte 0

get_any_input:
il_get_any_input:
    lda #$00
    sta i_compare

    jsr get_j1

    lda j1_button
    cmp #$ff
    beq !+
    inc i_compare
!:
    lda j1_up
    cmp #$ff
    beq !+
    inc i_compare
!:
    lda j1_left
    cmp #$ff
    beq !+
    inc i_compare
!:
    lda j1_right
    cmp #$ff
    beq !+
    inc i_compare
!:
    lda j1_down
    cmp #$ff
    beq !+
    inc i_compare
!:

    jsr il_get_key

    lda i_compare
    ora k_value
    sta i_compare
    rts
