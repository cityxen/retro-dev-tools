//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Calculate Screen Position
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// PET screen RAM is at $8000, linear layout: row * 40 + col.
// (Unlike C64's $0400 or Apple IIe's interleaved layout.)
//
// calculate_screen_pos(X=col, Y=row) -> zp_ptr_screen = address
//////////////////////////////////////////////////////////////////////////////////////

calculate_screen_pos:
    // Start at SCREEN_RAM ($8000)
    lda #<SCREEN_RAM
    sta zp_ptr_screen_lo
    lda #>SCREEN_RAM
    sta zp_ptr_screen_hi

    // Add X (column)
    cpx #$00
csp_col_loop:
    beq csp_col_done
    inc zp_ptr_screen_lo
    bne csp_col_inc
    inc zp_ptr_screen_hi
csp_col_inc:
    dex
    jmp csp_col_loop
csp_col_done:

    // Add Y * 40 (row)
    cpy #$00
csp_row_loop:
    beq csp_done
    lda zp_ptr_screen_lo
    clc
    adc #$28            // add 40
    sta zp_ptr_screen_lo
    bcc csp_row_next
    inc zp_ptr_screen_hi
csp_row_next:
    dey
    jmp csp_row_loop
csp_done:
    rts

increment_screen_pos:
    inc zp_ptr_screen_lo
    bne isp_exit
    inc zp_ptr_screen_hi
isp_exit:
    rts

addto_screen_pos:
    lda zp_ptr_screen_lo
    clc
    adc #$28
    sta zp_ptr_screen_lo
    bcc asp_exit
    inc zp_ptr_screen_hi
asp_exit:
    rts
