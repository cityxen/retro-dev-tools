//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Calculate color RAM position
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// calculate_color_pos: compute color RAM pointer only.
//   X = column (0-39), Y = row (0-24)
//   Result: zp_ptr_color_lo/hi
//
// C16/Plus-4: COLOR_RAM at $0800, 40 columns per row.
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
    adc #$28                // 40 columns per row
    sta zp_ptr_color_lo
    bcc !ccp_lp_i+
    inc zp_ptr_color_hi
!ccp_lp_i:
    dey
    jmp !ccp_lp-
!ccp_lp:
    rts
