//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// ScreenCode to PETSCII Conversion
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// StrScreenCodeToPetscii(string, len) — convert string in-place
.macro StrScreenCodeToPetscii(string, len) {
    ldx #$00
ssc2p_loop:
    lda string, x
    jsr screencode_to_petscii
    sta string, x
    inx
    cpx #len
    bne ssc2p_loop
}

// screencode_to_petscii — convert A (screencode) to PETSCII
screencode_to_petscii:
    beq sc2p_done
    cmp #32
    bcc sc2p_add64
    cmp #64
    bcc sc2p_add0
    cmp #96
    bcc sc2p_add128
    cmp #128
    bcc sc2p_add64
    cmp #160
    bcc sc2p_sub128
    cmp #224
    bcc sc2p_sub64
    cmp #254
    bcc sc2p_add0
sc2p_done:
    rts

sc2p_sub128:
    sec
    sbc #64
sc2p_sub64:
    sec
    sbc #64
    rts
sc2p_add128:
    clc
    adc #64
sc2p_add64:
    clc
    adc #64
sc2p_add0:
    rts
