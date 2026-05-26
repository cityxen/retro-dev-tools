//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Software Frame Timer System
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Provides N repeating software timers driven by VBL polling.
// VBL sync uses RTCLOK+2 ($0014), which increments once per
// frame (~60Hz NTSC).  Call update_timers once per VBL.
//
// API (same as Apple IIe / C64 ports):
//   wait_vbl             -- spin until next VBL frame starts
//   update_timers        -- decrement all timers; call after wait_vbl
//   SetTimerReload(n, v) -- set reload value for timer n to literal v
//   ResetTimer(n)        -- reload timer n countdown
//   ResetTimerFired(n)   -- clear fired flag for timer n
//   GetTimerFired(n)     -- load fired flag into A (0 = not fired)
//   GetTimer(n)          -- load countdown value into A
//////////////////////////////////////////////////////////////////

#importonce

.const TIMER_COUNT = 4

// Timer storage
timer_reload: .byte 60, 120, 720, 80
timer_val:    .byte 60, 120, 720, 80
timer_fired:  .byte  0,   0,   0,  0

//////////////////////////////////////////////////////////////////
// Macros

.macro SetTimerReload(n, v) {
    lda #[v]
    sta timer_reload + [n]
}

.macro ResetTimer(n) {
    lda timer_reload + [n]
    sta timer_val + [n]
}

.macro ResetTimerFired(n) {
    lda #$00
    sta timer_fired + [n]
}

.macro GetTimer(n) {
    lda timer_val + [n]
}

.macro GetTimerFired(n) {
    lda timer_fired + [n]
}

//////////////////////////////////////////////////////////////////
// wait_vbl
// Spins until RTCLOK+2 increments (once per VBL, ~60Hz NTSC).
// Preserves X, Y.  Trashes A.
wait_vbl:
    lda RTCLOK2       // read current frame counter
wv_loop:
    cmp RTCLOK2       // wait until it changes
    beq wv_loop
    rts

//////////////////////////////////////////////////////////////////
// update_timers
// Decrement all timer countdowns; set fired flags on expiry.
// Call once per frame, after wait_vbl.
// Trashes A, X.
update_timers:
    ldx #TIMER_COUNT - 1
ut_loop:
    lda timer_val,x
    beq ut_next         // already 0 (shouldn't normally happen)
    dec timer_val,x
    bne ut_next
    // Countdown hit 0 — fire and reload
    inc timer_fired,x
    lda timer_reload,x
    sta timer_val,x
ut_next:
    dex
    bpl ut_loop
    rts

//////////////////////////////////////////////////////////////////
// Doodle countdown (16-bit, in frames)
// tick_doodle_timer: decrement; A = (lo | hi) after; A=0 = expired.
tick_doodle_timer:
    lda doodle_timer_lo
    bne tt_lo_nonzero
    lda doodle_timer_hi
    beq tt_expired
    dec doodle_timer_hi
tt_lo_nonzero:
    dec doodle_timer_lo
    lda doodle_timer_lo
    ora doodle_timer_hi
    rts
tt_expired:
    lda #0
    rts

// load_doodle_timer: reload doodle_timer from doodle_timer_set_lo/hi
load_doodle_timer:
    lda doodle_timer_set_lo
    sta doodle_timer_lo
    lda doodle_timer_set_hi
    sta doodle_timer_hi
    rts

//////////////////////////////////////////////////////////////////
