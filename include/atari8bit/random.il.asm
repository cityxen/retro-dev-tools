#importonce
//////////////////////////////////////////////////////////////////
// CITYXEN ATARI 800XL LIBRARY — Random Number Generation
//
// https://github.com/cityxen/Atari_8Bit_Programming
// https://linktr.ee/cityxen
//
// Uses POKEY hardware RANDOM register ($D20A), which produces a
// new pseudo-random byte on every read.  No initialisation needed.
//
// Provides:
//   random_num           — last value returned by lda_random
//   random_init          — no-op (POKEY runs freely at power-on)
//   lda_random           — read RANDOM into A and random_num
//   get_random_range     — return A mod (limit in ZP_TMP); A = result
//////////////////////////////////////////////////////////////////

random_num: .byte 0

// random_init: no-op on Atari (POKEY free-runs at power-on).
random_init:
    rts

// lda_random: read POKEY RANDOM into A and store in random_num.
lda_random:
    lda RANDOM
    sta random_num
    rts

// get_random_range:
//   In:  A = range  (e.g. 5 for 0-4)
//   Out: A = random value in [0, range-1]
//   Trashes: ZP_TMP
get_random_range:
    sta ZP_TMP
    lda RANDOM
grr_mod:
    cmp ZP_TMP
    bcc grr_done
    sbc ZP_TMP
    jmp grr_mod
grr_done:
    sta random_num
    rts

//////////////////////////////////////////////////////////////////
