//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// Random Number Generator
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// 32-bit Galois LFSR (polynomial x^32 + x^22 + x^2 + x + 1).
// No SID chip on PET, so hardware noise source is not available.
// Seed random_seed with any non-zero value before use.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

random_seed:
    .byte $01, $02, $04, $08    // 32-bit seed (must be non-zero)

random_num:    .byte 0
random_counter:.byte 0

//////////////////////////////////////////////////////////////////////////////////////
// random_init — call once at startup to scramble the seed

random_init:
    ldx #64
ri_loop:
    jsr lda_random
    dex
    bne ri_loop
    rts

//////////////////////////////////////////////////////////////////////////////////////
// lda_random — generate next 8-bit pseudo-random value into A
// Also stored in random_num.

lda_random:
    ldx #8
lr_bit_loop:
    lsr random_seed+3
    ror random_seed+2
    ror random_seed+1
    ror random_seed
    bcc lr_no_feedback
    // XOR with feedback polynomial ($00840001)
    lda random_seed+3
    eor #$00
    sta random_seed+3
    lda random_seed+2
    eor #$84
    sta random_seed+2
    lda random_seed+1
    eor #$00
    sta random_seed+1
    lda random_seed
    eor #$01
    sta random_seed
lr_no_feedback:
    dex
    bne lr_bit_loop
    lda random_seed
    sta random_num
    rts

//////////////////////////////////////////////////////////////////////////////////////
// lda_random_range — generate random value 0..(range-1) into A
// Entry: A = range (1-256, where 0 = 256)

lda_random_range:
    sta random_counter          // save range
    jsr lda_random
lrr_mod:
    cmp random_counter
    bcc lrr_done                // A < range → done
    sec
    sbc random_counter
    jmp lrr_mod
lrr_done:
    sta random_num
    rts

//////////////////////////////////////////////////////////////////////////////////////
// RandomRange macro — result 0..(range-1) in A

.macro RandomRange(range) {
    lda #range
    jsr lda_random_range
}
