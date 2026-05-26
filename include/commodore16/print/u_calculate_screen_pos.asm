//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Calculate screen position
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// calculate_screen_pos: compute screen and color RAM pointers.
//   X = column (0-39), Y = row (0-24)
//   Result: zp_ptr_screen_lo/hi and zp_ptr_color_lo/hi
//
// C16/Plus-4: 40 columns per row (add $28 per row, same as C64).
// Screen RAM: $0C00  Color RAM: $0800
//////////////////////////////////////////////////////////////////

calculate_screen_pos:
    lda #<SCREEN_RAM
    sta zp_ptr_screen_lo
    lda #>SCREEN_RAM
    sta zp_ptr_screen_hi
    lda #<COLOR_RAM
    sta zp_ptr_color_lo
    lda #>COLOR_RAM
    sta zp_ptr_color_hi

    cpx #$00
!csp_lp:
    beq !csp_lp+
    inc zp_ptr_screen_lo
    inc zp_ptr_color_lo
    bne !csp_lp_i+
    inc zp_ptr_screen_hi
    inc zp_ptr_color_hi
!csp_lp_i:
    dex
    jmp !csp_lp-
!csp_lp:
    cpy #$00                // add Y rows × 40 to pointer
!csp_lp:
    beq !csp_lp+
    lda zp_ptr_screen_lo
    clc
    adc #$28                // 40 ($28) columns per row
    sta zp_ptr_screen_lo
    lda zp_ptr_color_lo
    clc
    adc #$28
    sta zp_ptr_color_lo
    bcc !csp_lp_i+
    inc zp_ptr_screen_hi
    inc zp_ptr_color_hi
!csp_lp_i:
    dey
    jmp !csp_lp-
!csp_lp:
    rts

increment_screen_pos:
    inc zp_ptr_screen_lo
    bne !isp_exit+
    inc zp_ptr_screen_hi
!isp_exit:
    rts

addto_screen_pos:
    lda zp_ptr_screen_lo
    clc
    adc #$28                // advance by one row (40 bytes)
    sta zp_ptr_screen_lo
    bcc !asp_exit+
    inc zp_ptr_screen_hi
!asp_exit:
    rts
