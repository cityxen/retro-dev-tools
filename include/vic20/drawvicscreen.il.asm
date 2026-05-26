//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — VIC Screen Blitter
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// Draws a pre-built VIC-20 screen from a data block.
//
// Data block layout (1014 bytes total for 22×23):
//   Byte 0:     border color  (0-7, packed into $900F bits 3-1)
//   Byte 1:     background color (0-7, packed into $900F bits 7-4)
//   Bytes 2-507:     screen characters (22×23 = 506 bytes, row-major)
//   Bytes 508-1013:  color nibbles (506 bytes; lower 4 bits = color)
//
// Usage:
//   DrawVICScreen(my_screen_data)
//
// This mirrors the PetMate screen concept from the C64 library but
// sized for the VIC-20's 22-column, 23-row display.
//////////////////////////////////////////////////////////////////

#importonce

.const VIC_SCR_PTR  = $fb    // zero-page pointer for screen data

.macro DrawVICScreen(screen_name) {
    lda #<screen_name
    sta VIC_SCR_PTR
    lda #>screen_name
    sta VIC_SCR_PTR+1
    jsr draw_vic_screen
}

draw_vic_screen:
    ldy #$00

    // Set border color (bits 3-1 of $900F)
    lda (VIC_SCR_PTR),y         // byte 0 = border color (0-7)
    and #$07
    asl                          // shift to bits 3-1
    sta zp_temp3                 // save border bits
    iny

    // Set background color (bits 7-4 of $900F)
    lda (VIC_SCR_PTR),y         // byte 1 = background color (0-7)
    and #$07
    asl
    asl
    asl
    asl                          // shift to bits 7-4
    ora zp_temp3
    sta VIC_SCREEN_COLOR

    // Calculate pointer to character data: screen_name + 2
    lda VIC_SCR_PTR
    clc
    adc #<2
    sta dvs_char_ptr
    lda VIC_SCR_PTR+1
    adc #>2
    sta dvs_char_ptr+1

    // Calculate pointer to color data: screen_name + 508
    lda VIC_SCR_PTR
    clc
    adc #<508
    sta dvs_color_ptr
    lda VIC_SCR_PTR+1
    adc #>508
    sta dvs_color_ptr+1

    // Copy 256 bytes of character data (page 0)
    ldy #$00
dvs_char_loop1:
    lda (dvs_char_ptr),y
    sta SCREEN_RAM,y
    lda (dvs_color_ptr),y
    sta COLOR_RAM,y
    iny
    bne dvs_char_loop1

    // Advance pointers by 256
    inc dvs_char_ptr+1
    inc dvs_color_ptr+1

    // Copy remaining 250 bytes (506 - 256 = 250)
    ldy #$00
dvs_char_loop2:
    lda (dvs_char_ptr),y
    sta SCREEN_RAM+256,y
    lda (dvs_color_ptr),y
    sta COLOR_RAM+256,y
    iny
    cpy #250
    bne dvs_char_loop2

    rts

dvs_char_ptr:  .byte $00, $00
dvs_color_ptr: .byte $00, $00
