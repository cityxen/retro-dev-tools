//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Calculate color RAM position
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// calculate_color_pos: compute color RAM pointer only.
//   X = column (0-21), Y = row (0-22)
//   Result: zp_ptr_color_lo/hi
//
// VIC-20: COLOR_RAM at $9600, 22 columns per row.
//////////////////////////////////////////////////////////////////

calculate_color_pos:
    lda #<COLOR_RAM
    sta zp_ptr_color_lo
    lda #>COLOR_RAM
    sta zp_ptr_color_hi

    cpx #$00
!ccp_lp:
    beq !ccp_lp+
    inc zp_ptr_color_lo
    bne !ccp_lp_i+
    inc zp_ptr_color_hi
!ccp_lp_i:
    dex
    jmp !ccp_lp-
!ccp_lp:
    cpy #$00
!ccp_lp:
    beq !ccp_lp+
    lda zp_ptr_color_lo
    clc
    adc #$16                // 22 columns per row
    sta zp_ptr_color_lo
    bcc !ccp_lp_i+
    inc zp_ptr_color_hi
!ccp_lp_i:
    dey
    jmp !ccp_lp-
!ccp_lp:
    rts
