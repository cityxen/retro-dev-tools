//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Input Handling
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// PET has no joystick ports.  All input is via keyboard using KERNAL_GETIN.
// The j1_* variables are provided for API compatibility with game code that
// was originally written for joystick-equipped platforms; map them to keys
// via the honkheckbutt.il.asm or your own input mapping.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// Last key read by get_key
last_key: .byte 0

// Joystick-style state bytes (keyboard-driven, updated by il_get_any_input)
j1_up:     .byte 0
j1_down:   .byte 0
j1_left:   .byte 0
j1_right:  .byte 0
j1_button: .byte 0

// Keyboard directional mapping — change these to remap controls
.const INPUT_KEY_UP     = KEY_CURSOR_UP
.const INPUT_KEY_DOWN   = KEY_CURSOR_DOWN
.const INPUT_KEY_LEFT   = KEY_CURSOR_LEFT
.const INPUT_KEY_RIGHT  = KEY_CURSOR_RIGHT
.const INPUT_KEY_FIRE   = KEY_SPACE

//////////////////////////////////////////////////////////////////////////////////////
// get_key — read a key, gated by TIMER_INPUT
// Returns A = key code (0 if no key / timer not fired)
// Stores result in last_key.

get_key:
    lda irq_timer_tr_table + TIMER_INPUT
    beq gk_done_no_key
    lda #0
    sta irq_timer_tr_table + TIMER_INPUT
    jsr il_get_key
    rts
gk_done_no_key:
    lda #0
    sta last_key
    rts

il_get_key:
    jsr KERNAL_GETIN
    sta last_key
    rts

//////////////////////////////////////////////////////////////////////////////////////
// il_get_any_input — read keyboard, update j1_* state bytes
// Stores 1 in j1_* if the matching key is held, 0 otherwise.
// Call once per frame (after timer gate if desired).

il_get_any_input:
    // Clear all direction state
    lda #0
    sta j1_up
    sta j1_down
    sta j1_left
    sta j1_right
    sta j1_button

    jsr KERNAL_GETIN
    sta last_key
    beq gai_done            // no key pressed

    cmp #INPUT_KEY_UP
    bne gai_chk_down
    lda #1
    sta j1_up
    jmp gai_done
gai_chk_down:
    cmp #INPUT_KEY_DOWN
    bne gai_chk_left
    lda #1
    sta j1_down
    jmp gai_done
gai_chk_left:
    cmp #INPUT_KEY_LEFT
    bne gai_chk_right
    lda #1
    sta j1_left
    jmp gai_done
gai_chk_right:
    cmp #INPUT_KEY_RIGHT
    bne gai_chk_fire
    lda #1
    sta j1_right
    jmp gai_done
gai_chk_fire:
    cmp #INPUT_KEY_FIRE
    bne gai_done
    lda #1
    sta j1_button
gai_done:
    rts

//////////////////////////////////////////////////////////////////////////////////////
// InputText - Read a line of text into a buffer (up to max_len chars)
// Usage: InputText(col, row, max_len)
// Result stored in string_buffer (from string.il.asm)

.macro InputText(col, row, max_len) {
    PlotCursor(col, row)
    lda #max_len
    jsr il_input_text
}

// il_input_text — A = max length on entry
// Reads chars via GETIN, echoes via CHROUT, handles RETURN and DELETE.
// Stores null-terminated result in string_buffer.

il_input_text:
    sta it_max              // save max length
    lda #0
    sta it_len
    sta string_buffer       // pre-null-terminate

it_loop:
    jsr KERNAL_GETIN
    beq it_loop             // wait for key

    cmp #KEY_RETURN
    beq it_done

    cmp #KEY_DELETE
    beq it_backspace

    // Check max length
    ldx it_len
    cpx it_max
    beq it_loop             // full — ignore

    // Store char and echo
    sta string_buffer, x
    jsr KERNAL_CHROUT
    inx
    lda #0
    sta string_buffer, x    // keep null-terminated
    stx it_len
    jmp it_loop

it_backspace:
    ldx it_len
    beq it_loop             // nothing to delete
    dex
    lda #0
    sta string_buffer, x
    stx it_len
    lda #KEY_DELETE
    jsr KERNAL_CHROUT
    jmp it_loop

it_done:
    rts

it_max: .byte 0
it_len: .byte 0
