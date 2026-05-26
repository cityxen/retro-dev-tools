//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// System Utilities
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

/////////////////////////////////////////////
// Register save/restore storage

a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
tmp_0:  .byte 0
tmp_1:  .byte 0
tmp_2:  .byte 0
tmp_3:  .byte 0

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

/////////////////////////////////////////////
// No-op subroutine (stub target)

no_subroutine:
    rts

/////////////////////////////////////////////
// wait_vbl - Wait for VIA Timer 1 interrupt flag (system 50/60Hz tick)
// Polls PET_VIA_IFR bit 6; clears flag by reading T1C-L.
// Call once per frame to synchronize to the system clock.

wait_vbl:
wait_vbl_loop:
    lda PET_VIA_IFR
    and #%01000000          // bit 6 = Timer 1 interrupt flag
    beq wait_vbl_loop
    lda PET_VIA_T1CL        // reading T1C-L clears the flag
    rts

/////////////////////////////////////////////
// sys_beep - Emit a BELL character via KERNAL

sys_beep:
    lda #$07
    jsr KERNAL_CHROUT
    rts

/////////////////////////////////////////////
// sys_hang - Infinite loop (crash/halt)

sys_hang:
    jmp sys_hang
