//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 64 LIBRARY
// 
// https://github.com/cityxen/Commodore64_Programming
//
// https://linktr.ee/cityxen
//
#importonce

.macro PrintP(lo,hi) {
    lda #lo
    sta zp_tmp_lo
    lda #hi
    sta zp_tmp_hi
    jsr print
}
.macro Print(string) {
    lda #< string 
    sta zp_tmp_lo
    lda #> string
    sta zp_tmp_hi 
    jsr print
}


//////////////////////////////////////////////////////////////////////////////////////
// Print macros — write direct to screen/color RAM (inlined from old PrintMacros.asm)
// Uses SCREEN_RAM/COLOR_RAM from new Constants.asm (same values: $0400/$D800).
//////////////////////////////////////////////////////////////////////////////////////
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

.macro PrintAtRainbow(x,y,string){
    PrintPlot(x,y)
    PrintRainbow(string)
}

.macro PrintRainbow(string) {
    lda #< string
    sta zp_tmp_lo
    lda #> string
    sta zp_tmp_hi 
    jsr print_rainbow
}

.macro PrintPlot(x,y) {
    ldx #y
    ldy #x
    clc
    jsr KERNAL_PLOT
}

.macro PrintColor(color) {
    lda #color
    sta 646
}

.macro PrintXY(text,x,y) {
    PrintPlot(x,y)
    Print(text)
}

.macro PrintXYColor(string,x,y,color) {
    PrintPlot(x,y)
    PrintColor(color)
    Print(string)
}

.macro PrintChr(char) {
    lda #char
    jsr KERNAL_CHROUT
}

.macro PrintLF() {
    lda #$0d
    jsr KERNAL_CHROUT
}

.macro PrintClear() {
    lda #$93
    jsr KERNAL_CHROUT
}

.macro PrintHome() {
    lda #$13
    jsr KERNAL_CHROUT
}

.macro PrintDown(num) {
    ldx #num
    lda #$11
!:
    jsr KERNAL_CHROUT
    dex
    bne !-   
}

.macro PrintUp(num) {
    ldx #num
    lda #$91
!:
    jsr KERNAL_CHROUT
    dex
    bne !-   
}

.macro PrintRight(num) {
    ldx #num
    lda #$1d
!:
    jsr KERNAL_CHROUT
    dex
    bne !-   
}

.macro PrintLeft(num) {
    ldx #num
    lda #$9d
!:
    jsr KERNAL_CHROUT
    dex
    bne !-   
}

.macro PrintReverseOn() {
    lda #$12
    jsr KERNAL_CHROUT
}

.macro PrintReverseOff() {
    lda #$92
    jsr KERNAL_CHROUT
}

.macro PrintUpperCase() {
    lda #$8e
    jsr KERNAL_CHROUT
}

.macro PrintLowerCase() {
    lda #$0e
    jsr KERNAL_CHROUT
}

.macro PrintStrLF(string) {
    Print(string)
    PrintChr($0d)
}

print:
    clc
    ldy #$00
!:
    lda (zp_tmp),y
    beq print_out
    jsr KERNAL_CHROUT
    inc zp_tmp_lo
    bne !+
    inc zp_tmp_hi
!:
    jmp !--
print_out:
    rts

print_rainbow:
    clc
    ldy #$00
pr1:
    lda (zp_tmp),y
    beq print_r_out
    sta print_r_t
    
    lda BACKGROUND_COLOR
    and #$0f
    cmp CURSOR_COLOR

    bne !+
    inc CURSOR_COLOR
    lda CURSOR_COLOR
    and #15
    sta CURSOR_COLOR
!:  
    lda print_r_t
    jsr KERNAL_CHROUT

    inc zp_tmp_lo
    bne !+
    inc zp_tmp_hi
!:
    inc CURSOR_COLOR
    lda CURSOR_COLOR
    and #15
    sta CURSOR_COLOR
    jmp pr1
print_r_out:
    rts
print_r_t:
.byte 0
