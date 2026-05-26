#importonce
//===========================================================================
// CityXen Apple IIe Library - System Utilities (Inline Subroutines)
//
// Register save/restore, vertical-blank wait, and other system utilities.
//===========================================================================

// Register save slots
a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
tmp_0:  .byte 0
tmp_1:  .byte 0
tmp_2:  .byte 0
tmp_3:  .byte 0

//---------------------------------------------------------------------------
// SaveRegs / LoadRegs macros - save/restore A, X, Y to RAM slots
//---------------------------------------------------------------------------
.macro SaveRegs() {
    sta a_reg
    stx x_reg
    sty y_reg
}

.macro LoadRegs() {
    lda a_reg
    ldx x_reg
    ldy y_reg
}

//---------------------------------------------------------------------------
// no_subroutine - Empty placeholder subroutine (returns immediately)
//---------------------------------------------------------------------------
no_subroutine:
    rts

//---------------------------------------------------------------------------
// wait_vbl - Wait for the start of the next vertical blank period
//
// On the Apple IIe enhanced with 80-column card, $C019 bit 7 signals VBL.
// Without the 80-col card this is not available; use WAIT or frame counter.
//
// Method used here: poll $C019 bit 7.  If the 80-col card is absent,
// this may not work — use wait_vbl_soft instead (counts cycles via WAIT).
//---------------------------------------------------------------------------
.const VBL_STATUS  = $C019     // bit 7 = 1 during VBL (80-col card required)

wait_vbl:
    // Wait for VBL to START (bit 7 goes high)
wvbl_wait_lo:
    bit VBL_STATUS
    bmi wvbl_wait_lo   // if already in VBL, wait for it to end first
wvbl_wait_hi:
    bit VBL_STATUS
    bpl wvbl_wait_hi   // wait until VBL starts
    rts

//---------------------------------------------------------------------------
// wait_vbl_soft - Software VBL approximation using Monitor WAIT routine.
//   Waits approximately 1/60 second.
//   WAIT delay: ~26.5 * A^2 / 2 microseconds, so A=28 -> ~10ms (rough)
//   For 60Hz: ~16.7ms per frame; A=35 gives ~16.2ms.
//---------------------------------------------------------------------------
wait_vbl_soft:
    lda #35
    jsr WAIT
    rts

//---------------------------------------------------------------------------
// sys_beep - Ring the speaker bell
//---------------------------------------------------------------------------
sys_beep:
    jsr BELL
    rts

//---------------------------------------------------------------------------
// sys_quit - Exit to ProDOS (QUIT call)
//---------------------------------------------------------------------------
sys_prodos_quit_params:
    .byte 4             // param count
    .byte 0             // quit type (0 = normal)
    .word 0             // reserved
    .byte 0             // reserved
    .word 0             // reserved

sys_quit:
    jsr PRODOS_MLI
    .byte MLI_QUIT
    .word sys_prodos_quit_params
    // If QUIT fails, hang
sq_hang:
    bra sq_hang

//===========================================================================
