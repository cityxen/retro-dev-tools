#importonce
//===========================================================================
// CityXen Apple IIe Library - Input Handling (Inline Subroutines)
//
// Keyboard: polled via $C000 (KBD) / $C010 (KBD_STROBE)
//   - High bit of $C000 is set when a key is waiting
//   - Reading $C010 clears the strobe (acknowledges the key)
//   - Key code in bits 0-6 (high bit always 1 from $C000, so mask with $7F)
//
// Joystick: analog paddles on $C064/$C065 (X/Y), triggered by $C070
//   - Access $C070 to start the RC comparator charging
//   - Poll $C064/$C065 bit 7; count cycles until it goes low = paddle value
//   - Open Apple (PB0=$C061), Closed Apple (PB1=$C062) for fire buttons
//===========================================================================

// State variables
input_last_key:     .byte 0     // last key pressed (high bit clear, 0-127)
input_key_ready:    .byte 0     // non-zero when a new key is available

// Joystick 1 state (set by il_get_joy)
j1_state:           .byte 0     // combined direction + button flags
j1_x_raw:           .byte 0     // raw paddle 0 value (0-255 approx)
j1_y_raw:           .byte 0     // raw paddle 1 value (0-255 approx)
j1_up:              .byte 0     // non-zero if joystick up
j1_down:            .byte 0     // non-zero if joystick down
j1_left:            .byte 0     // non-zero if joystick left
j1_right:           .byte 0     // non-zero if joystick right
j1_button:          .byte 0     // non-zero if fire button (Open Apple)
j1_button2:         .byte 0     // non-zero if Closed Apple

// Joystick 2 state
j2_state:           .byte 0
j2_x_raw:           .byte 0
j2_y_raw:           .byte 0
j2_up:              .byte 0
j2_down:            .byte 0
j2_left:            .byte 0
j2_right:           .byte 0
j2_button:          .byte 0

// Text input state (for InputText routine)
input_text_buf:     .fill 81, 0     // text input buffer (80 chars + null)
input_text_len:     .byte 0         // current length of text in buffer
input_text_max:     .byte 80        // maximum input length
input_text_x:       .byte 0         // cursor column for text input
input_text_y:       .byte 0         // cursor row for text input

//---------------------------------------------------------------------------
// il_get_key - Wait for a keypress, return in A (high bit clear, 0-127)
//   Clears the keyboard strobe after reading.
//   Also stores key in input_last_key.
//---------------------------------------------------------------------------
il_get_key:
igk_wait:
    lda KBD
    bpl igk_wait           // loop until bit 7 set (key available)
    bit KBD_STROBE          // clear strobe
    and #$7F                // mask off the strobe bit
    sta input_last_key
    rts

//---------------------------------------------------------------------------
// il_check_key - Non-blocking key check. Returns A=$00 if no key,
//   otherwise A = key code (0-127) with carry set.
//---------------------------------------------------------------------------
il_check_key:
    lda KBD
    bpl ick_none
    bit KBD_STROBE
    and #$7F
    sta input_last_key
    lda #$FF
    sta input_key_ready
    sec
    lda input_last_key
    rts
ick_none:
    lda #0
    sta input_key_ready
    clc
    rts

//---------------------------------------------------------------------------
// il_get_joy - Sample joystick 1 (PDL0/PDL1 + PB0/PB1)
//   Fills j1_up/down/left/right/button/button2 and j1_state.
//   Returns j1_state in A.
//
// Paddle sampling method: access PTRIG ($C070) to reset the RC comparator,
//   then count cycles until PDL0/PDL1 bit 7 goes low.  The count (scaled)
//   gives a 0-255 value.  We compare against JOY_THRESHOLD / JOY_CENTER.
//---------------------------------------------------------------------------
il_get_joy:
    stz j1_state
    stz j1_up
    stz j1_down
    stz j1_left
    stz j1_right
    stz j1_button
    stz j1_button2

    // Sample PDL0 (X axis)
    bit PTRIG               // reset comparator
    ldy #0
igj_x:
    bit PDL0                // bit 7 high while charging
    bmi igj_x_done
    iny
    bne igj_x
igj_x_done:
    sty j1_x_raw

    // Sample PDL1 (Y axis)
    bit PTRIG
    ldy #0
igj_y:
    bit PDL1
    bmi igj_y_done
    iny
    bne igj_y
igj_y_done:
    sty j1_y_raw

    // Read fire buttons
    lda PB0
    bpl igj_no_fire1
    lda #JOY_FIRE
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_button
igj_no_fire1:
    lda PB1
    bpl igj_no_fire2
    lda #JOY_FIRE2
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_button2
igj_no_fire2:

    // Decode X axis
    lda j1_x_raw
    cmp #JOY_CENTER - JOY_THRESHOLD
    bcs igj_not_left
    lda #JOY_LEFT
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_left
igj_not_left:
    lda j1_x_raw
    cmp #JOY_CENTER + JOY_THRESHOLD
    bcc igj_not_right
    lda #JOY_RIGHT
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_right
igj_not_right:

    // Decode Y axis
    lda j1_y_raw
    cmp #JOY_CENTER - JOY_THRESHOLD
    bcs igj_not_up
    lda #JOY_UP
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_up
igj_not_up:
    lda j1_y_raw
    cmp #JOY_CENTER + JOY_THRESHOLD
    bcc igj_not_down
    lda #JOY_DOWN
    ora j1_state
    sta j1_state
    lda #$FF
    sta j1_down
igj_not_down:

    lda j1_state
    rts

//---------------------------------------------------------------------------
// il_get_any_input - Poll keyboard and joystick 1; return non-zero in A
//   if any input is active.  Stores last_key and j1_state.
//---------------------------------------------------------------------------
il_get_any_input:
    jsr il_check_key
    pha
    jsr il_get_joy
    pla
    ora j1_state
    rts

//---------------------------------------------------------------------------
// InputText2 - Full line text input at (input_text_x, input_text_y)
//   Characters echoed to screen with reverse video highlight.
//   RETURN finishes; DELETE removes last character.
//   Result stored in input_text_buf (null-terminated), length in input_text_len.
//
//   Caller sets input_text_x, input_text_y, input_text_max before calling.
//---------------------------------------------------------------------------
.macro InputText2(x_col, y_row, max_len) {
    lda #x_col
    sta input_text_x
    lda #y_row
    sta input_text_y
    lda #max_len
    sta input_text_max
    jsr il_input_text
}

il_input_text:
    stz input_text_len
    stz input_text_buf

it_loop:
    // Position cursor at input_text_x + current length
    lda input_text_x
    clc
    adc input_text_len
    sta CURSOR_CH
    lda input_text_y
    sta CURSOR_CV
    jsr BASCALC

    // Draw blinking cursor (underscore in inverse)
    lda #($5F | CHR_INVERSE)    // inverse underscore
    sta (CURSOR_BAS)

    jsr il_get_key
    pha

    // Erase cursor char first
    lda input_text_x
    clc
    adc input_text_len
    sta CURSOR_CH
    lda input_text_y
    sta CURSOR_CV
    jsr BASCALC
    lda #($A0)                  // normal space ($20 | $80)
    sta (CURSOR_BAS)

    pla

    // RETURN = done
    cmp #KEY_RETURN
    beq it_done

    // DELETE = backspace
    cmp #KEY_DELETE
    beq it_delete
    cmp #KEY_BACKSPACE
    beq it_delete

    // Check if max length reached
    ldx input_text_len
    cpx input_text_max
    bcs it_loop        // ignore if at max

    // Printable? (space and above)
    cmp #KEY_SPACE
    bcc it_loop        // ignore control chars

    // Store character
    sta input_text_buf, x
    // Echo to screen: char | CHR_NORMAL
    ora #CHR_NORMAL
    sta (CURSOR_BAS)
    inc input_text_len
    bra it_loop

it_delete:
    lda input_text_len
    beq it_loop        // nothing to delete
    dec input_text_len
    ldx input_text_len
    stz input_text_buf, x
    bra it_loop

it_done:
    // Null-terminate
    ldx input_text_len
    stz input_text_buf, x
    rts

//===========================================================================
