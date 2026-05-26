//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 64 LIBRARY
// 
// https://github.com/cityxen/Commodore64_Programming
//
// https://linktr.ee/cityxen
//

/////////////////////////////////////////////
// Some reg bytes
a_reg:  .byte 0
x_reg:  .byte 0
y_reg:  .byte 0
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
// No Subroutine, just rts
no_subroutine:
    rts

/////////////////////////////////////////////
// Wait VBL
wait_vbl:
!wait_not_zero:
    lda $d012
    beq !wait_not_zero-
!wait_zero:
    lda $d012
    bne !wait_zero-
    rts

