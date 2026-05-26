//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Software Timer System
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// Seven software countdown timers driven by the system VIA Timer 1 IRQ.
// The IRQ handler is installed at PET_IRQ_HOOK_LO/HI ($0090/$0091) — the
// PET BASIC 4.0 user-hook vector.  If your ROM revision uses a different
// address, change PET_IRQ_HOOK_LO/HI in Constants.asm.
//
// Usage:
//   InitTimers(t0,t1,t2,t3,t4,t5,t6)   // set reload periods (in IRQ ticks)
//   IfTimerJmp(n, label)                 // branch if timer n has fired
//   IfTimerSub(n, label)                 // JSR if timer n has fired
//   ResetTimer(n)                        // restart timer n
//   pause1() ... pause5()               // spin-wait for timer 1..5
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// Timer indices
.const TIMER_1            = 0
.const TIMER_2            = 1
.const TIMER_3            = 2
.const TIMER_SCREEN_CHANGE= 3
.const TIMER_4            = 4
.const TIMER_INPUT        = 5
.const TIMER_JITTER       = 6

.const NUM_TIMERS         = 7

// Timer tables (live in regular RAM, not ZP)
irq_timer_table:         .fill NUM_TIMERS, 0   // current countdown
irq_timer_to_table:      .fill NUM_TIMERS, 0   // reload period
irq_timer_tr_table:      .fill NUM_TIMERS, 0   // "fired" flag (non-zero = fired)

// Saved previous IRQ hook vector
irq_old_lo: .byte 0
irq_old_hi: .byte 0

//////////////////////////////////////////////////////////////////////////////////////
// InitTimers macro — set timer periods and install IRQ hook
// Each argument is the reload period for timers 0-6 in IRQ ticks.

.macro InitTimers(t0,t1,t2,t3,t4,t5,t6) {
    lda #t0
    sta irq_timer_to_table+0
    sta irq_timer_table+0
    lda #t1
    sta irq_timer_to_table+1
    sta irq_timer_table+1
    lda #t2
    sta irq_timer_to_table+2
    sta irq_timer_table+2
    lda #t3
    sta irq_timer_to_table+3
    sta irq_timer_table+3
    lda #t4
    sta irq_timer_to_table+4
    sta irq_timer_table+4
    lda #t5
    sta irq_timer_to_table+5
    sta irq_timer_table+5
    lda #t6
    sta irq_timer_to_table+6
    sta irq_timer_table+6
    jsr init_timers
}

//////////////////////////////////////////////////////////////////////////////////////
// ResetTimer(n) — restart timer n from its reload period

.macro ResetTimer(n) {
    lda irq_timer_to_table+n
    sta irq_timer_table+n
    lda #0
    sta irq_timer_tr_table+n
}

//////////////////////////////////////////////////////////////////////////////////////
// IfTimerJmp(n, label) — JMP to label when timer n fires (clears flag)

.macro IfTimerJmp(n, lbl) {
    lda irq_timer_tr_table+n
    beq itj_skip
    lda #0
    sta irq_timer_tr_table+n
    jmp lbl
itj_skip:
}

//////////////////////////////////////////////////////////////////////////////////////
// IfTimerSub(n, label) — JSR to label when timer n fires (clears flag)

.macro IfTimerSub(n, lbl) {
    lda irq_timer_tr_table+n
    beq its_skip
    lda #0
    sta irq_timer_tr_table+n
    jsr lbl
its_skip:
}

//////////////////////////////////////////////////////////////////////////////////////
// pause1 … pause5 — spin-wait until the given timer fires

.macro pause1() {
pause1_loop:
    ldx #TIMER_1
    lda irq_timer_tr_table, x
    beq pause1_loop
    lda #0
    sta irq_timer_tr_table, x
}

.macro pause2() {
pause2_loop:
    ldx #TIMER_2
    lda irq_timer_tr_table, x
    beq pause2_loop
    lda #0
    sta irq_timer_tr_table, x
}

.macro pause3() {
pause3_loop:
    ldx #TIMER_3
    lda irq_timer_tr_table, x
    beq pause3_loop
    lda #0
    sta irq_timer_tr_table, x
}

.macro pause4() {
pause4_loop:
    ldx #TIMER_4
    lda irq_timer_tr_table, x
    beq pause4_loop
    lda #0
    sta irq_timer_tr_table, x
}

.macro pause5() {
pause5_loop:
    ldx #TIMER_INPUT
    lda irq_timer_tr_table, x
    beq pause5_loop
    lda #0
    sta irq_timer_tr_table, x
}

//////////////////////////////////////////////////////////////////////////////////////
// init_timers — install IRQ hook at PET_IRQ_HOOK_LO/HI and call user hook

init_timers:
    // Save existing hook vector
    lda PET_IRQ_HOOK_LO
    sta irq_old_lo
    lda PET_IRQ_HOOK_HI
    sta irq_old_hi

    // Install our handler
    lda #<irq_handler
    sta PET_IRQ_HOOK_LO
    lda #>irq_handler
    sta PET_IRQ_HOOK_HI

    jsr init_timers_user_hook
    rts

//////////////////////////////////////////////////////////////////////////////////////
// irq_handler — called by PET KERNAL at each system tick
// Decrements all active timer counters; sets fired flag on expiry.

irq_handler:
    // Preserve registers (PET 6502 — no stz, no bra)
    pha
    txa
    pha
    tya
    pha

    ldx #0
irq_loop:
    lda irq_timer_to_table, x  // if period is 0 the timer is disabled
    beq irq_next
    lda irq_timer_table, x
    beq irq_fired              // already at 0, still set flag
    sec
    sbc #1
    sta irq_timer_table, x
    bne irq_next               // not yet zero — keep going
irq_fired:
    lda irq_timer_to_table, x  // reload
    sta irq_timer_table, x
    lda #1
    sta irq_timer_tr_table, x  // set fired flag
irq_next:
    inx
    cpx #NUM_TIMERS
    bne irq_loop

    pla
    tay
    pla
    tax
    pla

    // Chain to previous hook (or fall through to RTI via KERNAL)
    jmp (irq_old_lo)           // indirect jump through our saved vector word

//////////////////////////////////////////////////////////////////////////////////////
// init_timers_user_hook — override in game code for custom IRQ-time work
// Default is a no-op rts.

init_timers_user_hook:
    rts
