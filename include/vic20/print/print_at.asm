//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Core print routines
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// VIC-20 screen: 22 columns × 23 rows.  PETSCII output via KERNAL_CHROUT.
//
// print:        print null-terminated PETSCII string via KERNAL_CHROUT.
//               ZP: zp_tmp_lo/hi → string pointer.
//
// print_rainbow: print with cycling cursor color.
//
// PrintP(lo,hi) — macro: set zp_tmp to address lo,hi and JSR print
// Print(string) — macro: set zp_tmp and JSR print
// PrintXY(text,x,y) — macro: PrintPlot then Print
// PrintXYColor(str,x,y,color) — macro: plot, set color, print
//////////////////////////////////////////////////////////////////

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

.macro PrintXY(text,x,y) {
    PrintPlot(x,y)
    Print(text)
}

.macro PrintXYColor(string,x,y,color) {
    PrintPlot(x,y)
    PrintColor(color)
    Print(string)
}

// PrintPlot(x,y): position cursor via KERNAL_PLOT.
// x = column (0-21), y = row (0-22) for VIC-20.
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

.macro PrintRainbow(string) {
    lda #< string
    sta zp_tmp_lo
    lda #> string
    sta zp_tmp_hi
    jsr print_rainbow
}

.macro PrintAtRainbow(x,y,string) {
    PrintPlot(x,y)
    PrintRainbow(string)
}

// Directly write string to screen RAM at (xpos, ypos) with color.
// VIC-20: 22 columns per row.
.macro PrintStrAtColor(xpos,ypos,var_in_string,color) {
    jmp over_psc_table
psc_string:
    .text var_in_string; .byte 0
over_psc_table:
    ldx #$00
psc_loop:
    lda psc_string,x
    beq psc_exit
    sta SCREEN_RAM + xpos + ypos*22,x
    lda #color
    sta COLOR_RAM + xpos + ypos*22,x
    inx
    jmp psc_loop
psc_exit:
}

//////////////////////////////////////////////////////////////////
// print: output null-terminated PETSCII string via KERNAL_CHROUT.
// zp_tmp_lo/hi → string.

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

//////////////////////////////////////////////////////////////////
// print_rainbow: print with cycling cursor color.

print_rainbow:
    clc
    ldy #$00
pr1:
    lda (zp_tmp),y
    beq print_r_out
    sta print_r_t

    lda VIC_SCREEN_COLOR    // use VIC background nibble as reference
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
print_r_t: .byte 0
