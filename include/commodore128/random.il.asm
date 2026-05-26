//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 128 LIBRARY
//
// https://github.com/cityxen/Commodore128_Programming
//
// https://linktr.ee/cityxen
//

//////////////////////////////////////////////////////////////
// Random number stuff

random_num:             .byte 0

random_init_sid:
    // Set up SID voice 3 as noise source for random values (same as C64)
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register
    rts

lda_random_sid:
    lda $D41B // read random value from SID oscillator 3 (same on C128)
    sta random_num
    rts

// Note: lda_random_kern uses a C64 KERNAL PRNG routine at $E097.
// This address differs on C128. Verify the correct C128 address before use.
lda_random_kern:
    jsr $E097  // C64 KERNAL PRNG — verify C128 ROM address
    lda $8F
    sta random_num
    rts
