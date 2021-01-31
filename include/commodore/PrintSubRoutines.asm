//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's C64 Assembly Language Library: PrintSubRoutines
//////////////////////////////////////////////////////////////////////////////////////

.macro PrintHex(xpos,ypos) {
    ldx #xpos
    ldy #ypos
    jsr print_hex
}

//////////////////////////////////////////////////////////////////////////////////////
// print_hex
//////////////////////////////////////////////////////////////////////////////////////
// Print 2 character HEX representation of a byte onto the screen at x,y location
//////////////////////////////////////////////////////////////////////////////////////
// usage:
// 
//      ldx #$05 
//      ldy #$06
//      lda #$15
//      jsr print_hex
//
//////////////////////////////////////////////////////////////////////////////////////
print_hex:
    sta zp_temp
    jsr calculate_screen_pos
    lda zp_temp
print_hex_no_calc:
    sta zp_temp
    lsr
    lsr
    lsr
    lsr
    tax
    lda print_hex_screencode_conversion_table,x
    ldx #$00
    sta (zp_ptr_screen,x)
    lda zp_temp
    and #$0f
    tax
    lda print_hex_screencode_conversion_table,x
    inc zp_ptr_screen_lo
    ldx #$00
    sta (zp_ptr_screen,x)
    rts
print_hex_screencode_conversion_table:
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$01,$02,$03,$04,$05,$06

//////////////////////////////////////////////////////////////////////////////////////
// calculate_screen_pos
//////////////////////////////////////////////////////////////////////////////////////
// Calculate screen position based on x and y registers
//////////////////////////////////////////////////////////////////////////////////////
// Usage:
// 
//      ldx #$05
//      ldy #$10
//      jsr calculate_screen_pos
//
//////////////////////////////////////////////////////////////////////////////////////
// Result: Stores screen location in zp_ptr_screen
//////////////////////////////////////////////////////////////////////////////////////
calculate_screen_pos: // x = xpos y = ypos
    lda #<SCREEN_RAM    // enter screen pos into zp
    sta zp_ptr_screen_lo
    lda #>SCREEN_RAM
    sta zp_ptr_screen_hi
    cpx #$00 // add x pos to screen pos
!csp_lp:
    beq !csp_lp+
    inc zp_ptr_screen_lo
    bne !csp_lp_i+
    inc zp_ptr_screen_hi
!csp_lp_i:
    dex
    jmp !csp_lp-
!csp_lp:
    cpy #$00 // add y pos to screen pos
!csp_lp:
    beq !csp_lp+
    lda zp_ptr_screen_lo
    clc
    adc #$28
    sta zp_ptr_screen_lo
    bcc !csp_lp_i+
    inc zp_ptr_screen_hi
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
    adc #$28
    sta zp_ptr_screen_lo
    bcc !asp_exit+
    inc zp_ptr_screen_hi
!asp_exit:
    rts

//////////////////////////////////////////////////////////////////////////////////////
// calculate_color_pos
//////////////////////////////////////////////////////////////////////////////////////
// Calculate color position based on x and y registers
//////////////////////////////////////////////////////////////////////////////////////
// Usage:
// 
//      ldx #$05
//      ldy #$10
//      jsr calculate_color_pos
//
//////////////////////////////////////////////////////////////////////////////////////
// Result: Stores color location in zp_ptr_color
//////////////////////////////////////////////////////////////////////////////////////
calculate_color_pos: // x = xpos y = ypos
    lda #<COLOR_RAM    // enter color pos into zp
    sta zp_ptr_color_lo
    lda #>COLOR_RAM
    sta zp_ptr_color_hi
    cpx #$00 // add x pos to color pos
!ccp_lp:
    beq !ccp_lp+
    inc zp_ptr_color_lo
    bne !ccp_lp_i+
    inc zp_ptr_color_hi
!ccp_lp_i:
    dex
    jmp !ccp_lp-
!ccp_lp:
    cpy #$00 // add y pos to color pos
!ccp_lp:
    beq !ccp_lp+
    lda zp_ptr_color_lo
    clc
    adc #$28
    sta zp_ptr_color_lo
    bcc !ccp_lp_i+
    inc zp_ptr_color_hi
!ccp_lp_i:
    dey
    jmp !ccp_lp-
!ccp_lp:
    rts

increment_color_pos:
    inc zp_ptr_color_lo
    bne !icp_exit+
    inc zp_ptr_color_hi
!icp_exit:
    rts

addto_color_pos:
    lda zp_ptr_color_lo
    clc
    adc #$28
    sta zp_ptr_color_lo
    bcc !acp_exit+
    inc zp_ptr_color_hi
!acp_exit:
    rts

.macro PrintAtColor(xpos,ypos,var_string,color) {
    ldx #$00
printatloop:
    lda var_string,x
    beq printexit
    sta SCREEN_RAM + xpos + ypos*40,x
    lda #color
    sta COLOR_RAM + xpos + ypos*40,x
    inx
    jmp printatloop    
printexit:
}

.macro PrintStrAtColor(xpos,ypos,var_in_string,color) {
    jmp over_table
var_string:
    .text var_in_string; .byte 0
over_table:
    ldx #$00
printatloop:
    lda var_string,x
    beq printexit
    sta SCREEN_RAM + xpos + ypos*40,x
    lda #color
    sta COLOR_RAM + xpos + ypos*40,x
    inx
    jmp printatloop    
printexit:
}

.macro PrintStrAtRainbow(xpos,ypos,var_in_string) {
    jmp over_table
var_string:
    .text var_in_string; .byte 0
over_table:
    ldy #$00
    ldx #$00
printatloop:
    lda var_string,x
    beq printexit
    sta SCREEN_RAM + xpos + ypos*40,x
    lda rainbowtable,y
    sta COLOR_RAM + xpos + ypos*40,x
    inx
    iny
    cpy #$06
    bne jmprainbowtable
    ldy #$00
jmprainbowtable:
    jmp printatloop    
printexit:
}
rainbowtable:
.byte YELLOW,GREEN,BLUE,PURPLE,RED,ORANGE

.macro PrintDecAtColor(xpos,ypos,var_num_mem,color) {
    ldx #$00
    lda #var_num_mem
    clc
    adc #$30
    sta SCREEN_RAM + xpos + ypos*40,x
    lda #color
    sta COLOR_RAM + xpos + ypos*40,x
}

ddl_print_num_table:
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,'a','b','c','d','e','f'
