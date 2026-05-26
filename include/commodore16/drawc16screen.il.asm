//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — C16 Screen Blitter
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// Draws a pre-built C16/Plus-4 screen from a data block.
//
// Data block layout (2002 bytes total for 40×25):
//   Byte 0:      border TED color byte  (written to $FF19)
//   Byte 1:      background TED color byte (written to $FF15)
//   Bytes 2-1001:     screen characters (40×25 = 1000 bytes, row-major)
//   Bytes 1002-2001:  color attributes (1000 bytes; TED color per cell)
//
// Usage:
//   DrawC16Screen(my_screen_data)
//
// This mirrors the PetMate / DrawVICScreen concept from the C64/VIC-20
// libraries, sized for the C16/Plus-4's 40-column display.
//////////////////////////////////////////////////////////////////

#importonce

.const C16_SCR_PTR  = $fb    // zero-page pointer for screen data (2 bytes)

.macro DrawC16Screen(screen_name) {
    lda #<screen_name
    sta C16_SCR_PTR
    lda #>screen_name
    sta C16_SCR_PTR+1
    jsr draw_c16_screen
}

draw_c16_screen:
    ldy #$00

    // Set border color ($FF19)
    lda (C16_SCR_PTR),y         // byte 0 = border TED color
    sta TED_BORDER_COLOR
    iny

    // Set background color ($FF15)
    lda (C16_SCR_PTR),y         // byte 1 = background TED color
    sta TED_COLOR_BG

    // Calculate pointer to character data: screen_name + 2
    lda C16_SCR_PTR
    clc
    adc #<2
    sta dc16_char_ptr
    lda C16_SCR_PTR+1
    adc #>2
    sta dc16_char_ptr+1

    // Calculate pointer to color data: screen_name + 1002
    lda C16_SCR_PTR
    clc
    adc #<1002
    sta dc16_color_ptr
    lda C16_SCR_PTR+1
    adc #>1002
    sta dc16_color_ptr+1

    // Copy first 256 bytes of character + color data
    ldy #$00
dc16_char_loop1:
    lda (dc16_char_ptr),y
    sta SCREEN_RAM,y
    lda (dc16_color_ptr),y
    sta COLOR_RAM,y
    iny
    bne dc16_char_loop1

    // Advance pointers by 256
    inc dc16_char_ptr+1
    inc dc16_color_ptr+1

    // Copy next 256 bytes (offset 256)
    ldy #$00
dc16_char_loop2:
    lda (dc16_char_ptr),y
    sta SCREEN_RAM+256,y
    lda (dc16_color_ptr),y
    sta COLOR_RAM+256,y
    iny
    bne dc16_char_loop2

    // Advance pointers by 256
    inc dc16_char_ptr+1
    inc dc16_color_ptr+1

    // Copy next 256 bytes (offset 512)
    ldy #$00
dc16_char_loop3:
    lda (dc16_char_ptr),y
    sta SCREEN_RAM+512,y
    lda (dc16_color_ptr),y
    sta COLOR_RAM+512,y
    iny
    bne dc16_char_loop3

    // Advance pointers by 256
    inc dc16_char_ptr+1
    inc dc16_color_ptr+1

    // Copy final 232 bytes (1000 - 768 = 232) (offset 768)
    ldy #$00
dc16_char_loop4:
    lda (dc16_char_ptr),y
    sta SCREEN_RAM+768,y
    lda (dc16_color_ptr),y
    sta COLOR_RAM+768,y
    iny
    cpy #232
    bne dc16_char_loop4

    rts

dc16_char_ptr:  .byte $00, $00
dc16_color_ptr: .byte $00, $00
