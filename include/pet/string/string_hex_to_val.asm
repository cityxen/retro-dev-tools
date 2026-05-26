//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// String Hex to Value
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

string_hex:
    .text "c000"
    .byte 0

hex_val:  .byte 0, 0
hex_tmp:  .byte 0
int_acc:  .byte 0

// hexstr16_to_val — parse 4-char hex string at string_hex -> hex_val (16-bit)
hexstr16_to_val:
    lda #$00
    sta hex_tmp
    sta int_acc
    sta hex_val
    sta hex_val+1

    tax
    lda string_hex, x
    jsr screencode_to_petscii
    jsr hex_cvrt

    inx
    lda string_hex, x
    jsr screencode_to_petscii
    jsr hex_cvrt

    lda int_acc
    sta hex_val+1

    lda #$00
    sta hex_tmp
    sta int_acc

    inx
    lda string_hex, x
    jsr screencode_to_petscii
    jsr hex_cvrt

    inx
    lda string_hex, x
    jsr screencode_to_petscii
    jsr hex_cvrt

    lda int_acc
    sta hex_val
    rts

hex_cvrt:
    stx x_reg
    cmp #$30
    bcc hcvrt_end
    cmp #$39
    bcs hcvrt_hex
    sec
    sbc #$30
    jmp hcvrt_add

hcvrt_hex:
    cmp #$41
    bcc hcvrt_end
    cmp #$47
    bcs hcvrt_end
    sec
    sbc #55

hcvrt_add:
    sta hex_tmp
    lda int_acc
    asl
    asl
    asl
    asl
    clc
    adc hex_tmp
    sta int_acc

hcvrt_end:
    ldx x_reg
    rts
