#importonce
//===========================================================================
// CityXen Apple IIe Library - IRQ-Driven Timer System
//
// Provides up to 16 software timers driven by a vertical-blank IRQ.
// The Apple IIe does not have a CIA chip; instead we hook the IRQ vector
// at $03FE/$03FF.  The VBL signal is not directly accessible as an IRQ
// source without a slot card, so we approximate using a ProDOS-compatible
// interrupt handler registered via the ProDOS interrupt manager, or we
// install a direct IRQ handler and poll the vertical-blank via $C019
// (VBL status on enhanced Apple IIe with 80-col card).
//
// If ProDOS is active, use il_timers_prodos_install to register safely.
// For bare-metal use, call il_timers_bare_install (replaces $03FE vector).
//
// Each timer counts in frames (ticks at ~60Hz).
// Timer 0-5 are "named" timers; timers 6-15 are user-defined.
//===========================================================================

.const MAX_TIMERS   = 16
.const TIMER_FREQ   = 60       // ticks per second (NTSC ~59.94 Hz)

// Named timer indices (mirror C64 port convention)
.const TIMER_1      = 0
.const TIMER_2      = 1
.const TIMER_3      = 2
.const TIMER_4      = 3
.const TIMER_5      = 4
.const TIMER_6      = 5

// Timer tables (MAX_TIMERS entries each)
irq_timer_table:    .fill MAX_TIMERS, 0     // current tick count per timer
irq_timer_to_table: .fill MAX_TIMERS, 60    // timeout value per timer (frames)
irq_timer_tr_table: .fill MAX_TIMERS, 0     // trigger flag (set when timer fires)

// IRQ state save
irq_save_a: .byte 0
irq_save_x: .byte 0
irq_save_y: .byte 0

// Previous IRQ vector (for chaining)
prev_irq_lo: .byte $00
prev_irq_hi: .byte $00

//---------------------------------------------------------------------------
// Macros
//---------------------------------------------------------------------------

.macro ResetTimers() {
    jsr il_reset_timers
}

.macro FullReset() {
    jsr il_reset_timers
}

.macro SetTimer(timer_idx, timeout_frames) {
    lda #timeout_frames
    ldx #timer_idx
    sta irq_timer_to_table, x
    stz irq_timer_table, x
    stz irq_timer_tr_table, x
}

.macro GetTimer(timer_idx) {
    ldx #timer_idx
    lda irq_timer_table, x
}

.macro SetTimerTr(timer_idx, trigger_val) {
    lda #trigger_val
    ldx #timer_idx
    sta irq_timer_tr_table, x
}

.macro GetTimerTr(timer_idx) {
    ldx #timer_idx
    lda irq_timer_tr_table, x
}

.macro IfTimerSub(timer_idx, target_label) {
    ldx #timer_idx
    lda irq_timer_tr_table, x
    beq its_skip
    stz irq_timer_tr_table, x
    jsr target_label
its_skip:
}

.macro IfTimerJmp(timer_idx, target_label) {
    ldx #timer_idx
    lda irq_timer_tr_table, x
    beq itj_skip
    stz irq_timer_tr_table, x
    jmp target_label
itj_skip:
}

// pause macros - spin until a specific timer fires
.macro pause1() {
pause1_loop:
    ldx #TIMER_1
    lda irq_timer_tr_table, x
    beq pause1_loop
    stz irq_timer_tr_table, x
}

.macro pause2() {
pause2_loop:
    ldx #TIMER_2
    lda irq_timer_tr_table, x
    beq pause2_loop
    stz irq_timer_tr_table, x
}

.macro pause3() {
pause3_loop:
    ldx #TIMER_3
    lda irq_timer_tr_table, x
    beq pause3_loop
    stz irq_timer_tr_table, x
}

.macro pause4() {
pause4_loop:
    ldx #TIMER_4
    lda irq_timer_tr_table, x
    beq pause4_loop
    stz irq_timer_tr_table, x
}

.macro pause5() {
pause5_loop:
    ldx #TIMER_5
    lda irq_timer_tr_table, x
    beq pause5_loop
    stz irq_timer_tr_table, x
}

.macro InitTimersDefault() {
    jsr il_timers_init_default
}

.macro InitTimers() {
    jsr il_timers_init_default
}

//---------------------------------------------------------------------------
// il_reset_timers - Zero all timer counts and trigger flags
//---------------------------------------------------------------------------
il_reset_timers:
    ldx #MAX_TIMERS - 1
rt_loop:
    stz irq_timer_table, x
    stz irq_timer_tr_table, x
    dex
    bpl rt_loop
    rts

//---------------------------------------------------------------------------
// il_timers_init_default - Initialize timers and install IRQ handler
//   Sets all timer timeouts to TIMER_FREQ (1 second each).
//   Installs il_irq_timers as the IRQ handler.
//---------------------------------------------------------------------------
il_timers_init_default:
    jsr il_reset_timers
    ldx #MAX_TIMERS - 1
itid_loop:
    lda #TIMER_FREQ
    sta irq_timer_to_table, x
    dex
    bpl itid_loop
    // Fall through to install handler
il_timers_bare_install:
    // Save current IRQ vector for chaining
    lda IRQ_VECTOR_LO
    sta prev_irq_lo
    lda IRQ_VECTOR_HI
    sta prev_irq_hi
    // Install our handler
    sei
    lda #<il_irq_timers
    sta IRQ_VECTOR_LO
    lda #>il_irq_timers
    sta IRQ_VECTOR_HI
    cli
    rts

//---------------------------------------------------------------------------
// il_irq_timers - IRQ handler: increment timers, set triggers
//   Must be entered via IRQ (not JSR); ends with RTI.
//   Preserves A, X, Y.
//---------------------------------------------------------------------------
il_irq_timers:
    sta irq_save_a
    stx irq_save_x
    sty irq_save_y

    ldx #MAX_TIMERS - 1
irqt_loop:
    inc irq_timer_table, x
    lda irq_timer_table, x
    cmp irq_timer_to_table, x
    bcc irqt_next
    // Timer fired: reset count, set trigger
    stz irq_timer_table, x
    lda #$FF
    sta irq_timer_tr_table, x
irqt_next:
    dex
    bpl irqt_loop

    lda irq_save_a
    ldx irq_save_x
    ldy irq_save_y
    rti

//===========================================================================
