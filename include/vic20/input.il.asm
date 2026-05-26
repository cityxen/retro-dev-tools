//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Joystick & Keyboard Input
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// VIC-20 has one joystick port (9-pin Atari style):
//   Directions via VIA1 Port B ($9111), active low (0 = pressed):
//     bit 2 = Up, bit 3 = Down, bit 4 = Left, bit 5 = Right
//   Fire button via VIA1 Port A ($9110), bit 5, active low.
//
// Keyboard via KERNAL_GETIN ($FFE4) — PETSCII codes.
//
// API:
//   get_j1         — read joystick directions and fire into j1_* vars
//   get_j1_m2      — method-2 history read (compat with C64 library)
//   j1_up/down/left/right/button — direction state ($ff = not pressed, 0 = pressed)
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
// Joystick — Method 1: direct read

j1_up:      .byte $ff
j1_down:    .byte $ff
j1_left:    .byte $ff
j1_right:   .byte $ff
j1_button:  .byte $ff

// get_j1: read VIA1 and populate j1_* (0 = pressed, $ff = not pressed).
get_j1:
    lda JOYSTICK_PORT       // $9111 — direction bits 2-5
    and #JOY_UP_BIT
    beq gj1_up_on
    lda #$ff
    sta j1_up
    jmp gj1_up_done
gj1_up_on:
    lda #$00
    sta j1_up
gj1_up_done:
    lda JOYSTICK_PORT
    and #JOY_DOWN_BIT
    beq gj1_down_on
    lda #$ff
    sta j1_down
    jmp gj1_down_done
gj1_down_on:
    lda #$00
    sta j1_down
gj1_down_done:
    lda JOYSTICK_PORT
    and #JOY_LEFT_BIT
    beq gj1_left_on
    lda #$ff
    sta j1_left
    jmp gj1_left_done
gj1_left_on:
    lda #$00
    sta j1_left
gj1_left_done:
    lda JOYSTICK_PORT
    and #JOY_RIGHT_BIT
    beq gj1_right_on
    lda #$ff
    sta j1_right
    jmp gj1_right_done
gj1_right_on:
    lda #$00
    sta j1_right
gj1_right_done:
    lda JOYSTICK_FIRE_REG   // $9110 — fire on bit 5
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
// Joystick — Method 2: shift-register history (C64 library compatible)
// Uses 8-bit shift: $ff = never pressed, $00 = held, $7f/$80 = recently toggled.

get_j1_m2:
il_get_j1_m2:
    lda JOYSTICK_PORT       // $9111
    and #JOY_UP_BIT
    beq gm2_up_pressed
    lda #$01                // bit = high → not pressed
    jmp gm2_up_shift
gm2_up_pressed:
    lda #$00
gm2_up_shift:
    asl j1_up
    ora j1_up               // insert new bit at LSB
    sta j1_up

    lda JOYSTICK_PORT
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

    lda JOYSTICK_PORT
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

    lda JOYSTICK_PORT
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

    lda JOYSTICK_FIRE_REG
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
