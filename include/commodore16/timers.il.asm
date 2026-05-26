//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Software Timer System
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// 16 software timers driven by the 50/60Hz hardware IRQ.
// Installs a custom handler at $0314/$0315 (same vector as C64/VIC-20).
// At end of IRQ, jumps to KERNAL_IRQ_ENTRY ($FCB3) for KERNAL
// housekeeping (keyboard scan, TOD update, etc.).
//
// Timer API:
//   InitTimers(t1..t7)   — set 7 timer reload values and install IRQ
//   InitTimersDefault()  — use built-in default reload values
//   GetTimerTr(t)        — load fired-flag into A (0 = not fired)
//   FullReset(t)         — clear timer and fired flag
//   IfTimerJmp(t,lbl)    — if timer fired, reset it and JMP lbl
//   IfTimerSub(t,sub)    — if timer fired, reset and JSR sub
//   pause1..pause5       — block until timer 0-4 fires once
//
// User hook stubs (define in your code or leave as no_subroutine):
//   irq_timer_user_hook  — called at top of every IRQ
//   init_timers_user_hook — called once during InitTimers
//////////////////////////////////////////////////////////////////

.const TIMER_1 = 0
.const TIMER_2 = 1
.const TIMER_3 = 2
.const TIMER_SCREEN_CHANGE = 3
.const TIMER_4 = 4
.const TIMER_INPUT = 5
.const TIMER_JITTER = 6

.macro ResetTimers() {
    .for (var i = 0; i < 16; i++) {
        ResetTimer(i)
    !:
    }
}

.macro FullReset(t) {
    lda #$00
    SetTimer(t)
    SetTimerTr(t)
}

.macro ResetTimer(t) {
    lda #$00
    ldx #t
    sta irq_timer_table,x
}

.macro ResetTimerTr(t) {
    lda #$00
    ldx #t
    sta irq_timer_tr_table,x
}

.macro SetTimerTo(t) {
    ldx #t
    sta irq_timer_to_table,x
}

.macro GetTimerTo(t) {
    ldx #t
    lda irq_timer_to_table,x
}

.macro SetTimer(t) {
    ldx #t
    sta irq_timer_table,x
}

.macro GetTimer(t) {
    ldx #t
    lda irq_timer_table,x
}

.macro SetTimerTr(t) {
    ldx #t
    sta irq_timer_tr_table,x
}

.macro GetTimerTr(t) {
    ldx #t
    lda irq_timer_tr_table,x
}

.macro IfTimerSub(t,subroutine) {
    GetTimerTr(t)
    beq !+
    lda #$00
    SetTimer(t)
    SetTimerTr(t)
    jsr subroutine
!:
}

.macro IfTimerSubJmp(t,subroutine,routine) {
    GetTimerTr(t)
    beq !+
    lda #$00
    SetTimer(t)
    SetTimerTr(t)
    jsr subroutine
    jmp routine
!:
}

.macro IfTimerJmp(t,routine) {
    GetTimerTr(t)
    beq !+
    lda #$00
    SetTimer(t)
    SetTimerTr(t)
    jmp routine
!:
}

.macro InitTimersDefault() {
    lda #60         // 1 sec  (~60Hz)
    SetTimerTo(0)
    lda #120        // 2 sec
    SetTimerTo(1)
    lda #180        // 3 sec
    SetTimerTo(2)
    lda #240        // 4 sec
    SetTimerTo(3)
    lda #250        // ~4 sec
    SetTimerTo(4)
    jsr init_timers
}

.macro InitTimers(t1,t2,t3,t4,t5,t6,t7) {
    lda #t1
    SetTimerTo(0)
    lda #t2
    SetTimerTo(1)
    lda #t3
    SetTimerTo(2)
    lda #t4
    SetTimerTo(3)
    lda #t5
    SetTimerTo(4)
    lda #t6
    SetTimerTo(5)
    lda #t7
    SetTimerTo(6)
    jsr init_timers
}

//////////////////////////////////////////////////////////////////
// Timer data tables (16 timers)

irq_timer_table:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
irq_timer_to_table:
.byte 10,25,30,60,120,200,50,55,60,65,70,75,15,16,17,20
irq_timer_tr_table:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

//////////////////////////////////////////////////////////////////
// init_timers: install IRQ handler and reset all timers

init_timers:
    sei
    lda #<irq_timers
    sta $0314
    lda #>irq_timers
    sta $0315
    cli
    ResetTimers()
    jsr init_timers_user_hook
    rts

//////////////////////////////////////////////////////////////////
// irq_timers: the installed IRQ handler

irq_timers:

    jsr irq_timer_user_hook

#if CONFIG_MUSIC
    lda play_music
    beq !it+
    jsr music.play
    jmp !it++
#endif
!it:

#if CONFIG_SFXKIT
    jsr sfx_irq_hook
#endif
!it:

    // Increment all 16 timer counters
    ldx #$00
!:
    lda irq_timer_table,x
    adc #$01
    sta irq_timer_table,x
    inx
    cpx #16
    bne !-

    // Check each timer against its timeout; fire if reached
    .for (var i = 0; i < 16; i++) {
        GetTimer(i)
        sta zp_timers
        lda irq_timer_to_table,x
        clc
        cmp zp_timers
        bcs !+
        lda #$00
        SetTimer(i)
        GetTimerTr(i)
        sta zp_timers
        inc zp_timers
        lda zp_timers
        SetTimerTr(i)
        ResetTimer(i)
    !:
    }

    jmp KERNAL_IRQ_ENTRY    // $FCB3 — C16/Plus-4 KERNAL IRQ continuation

//////////////////////////////////////////////////////////////////
// pause1-pause5: block until timer N fires once

pause1:
    ResetTimer(0)
!:
    GetTimerTr(0)
    beq !-
    ResetTimer(0)
    rts

pause2:
    ResetTimer(1)
!:
    GetTimerTr(1)
    beq !-
    ResetTimer(1)
    rts

pause3:
    ResetTimer(2)
!:
    GetTimerTr(2)
    beq !-
    ResetTimer(2)
    rts

pause4:
    ResetTimer(3)
!:
    GetTimerTr(3)
    beq !-
    ResetTimer(3)
    rts

pause5:
    ResetTimer(4)
!:
    GetTimerTr(4)
    beq !-
    ResetTimer(4)
    rts

reset_input_timer:
    ResetTimer(5)
    lda #$00
    SetTimerTr(5)
    rts

reset_jitter_timer:
    ResetTimer(6)
    lda #$00
    SetTimerTr(6)
    rts
