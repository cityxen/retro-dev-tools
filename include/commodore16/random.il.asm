//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — Random Number Generation
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// The C16/Plus-4 TED chip has no dedicated random/noise source like
// the SID. We use a software LFSR as the primary generator, with an
// optional TED-raster entropy mix for seeding.
//
// lda_random_lfsr: software 8-bit LFSR (no hardware dependency).
//                  Call random_init first to seed it.
//
// lda_random_ted:  mix raster counter into the LFSR for extra entropy.
//
// random_num: holds the last generated value.
//////////////////////////////////////////////////////////////////

#importonce

random_num:     .byte $a5   // seed
lfsr_state:     .byte $a5   // LFSR internal state (non-zero required)

//////////////////////////////////////////////////////////////////
// random_init: seed the LFSR with a default value.
// For better randomness, seed from a raster-read before calling.

random_init:
    lda #$a5            // non-zero seed
    sta lfsr_state
    sta random_num
    rts

//////////////////////////////////////////////////////////////////
// lda_random / lda_random_lfsr: 8-bit maximal-length LFSR
// Polynomial: x^8 + x^6 + x^5 + x^4 + 1  (taps = $B8)
// Result in A and random_num.

lda_random:
lda_random_lfsr:
    lda lfsr_state
    lsr                 // shift right; carry = outgoing bit
    bcc lfsr_no_tap
    eor #$b8            // feedback polynomial
lfsr_no_tap:
    sta lfsr_state
    sta random_num
    rts

//////////////////////////////////////////////////////////////////
// lda_random_ted: mix TED raster line into the LFSR for entropy.
// Call from unpredictable timing points (e.g. between user inputs).

lda_random_ted:
    lda TED_RASTER_LO   // raster varies with execution timing
    eor random_num
    eor lfsr_state
    sta lfsr_state
    sta random_num
    rts

//////////////////////////////////////////////////////////////////
// get_random_range
//   In:  A = range (e.g. 5 for values 0-4)
//   Out: A = random value in [0, range-1]

get_random_range:
    sta zp_tmp
    jsr lda_random_lfsr
grr_mod:
    cmp zp_tmp
    bcc grr_done
    sbc zp_tmp
    jmp grr_mod
grr_done:
    sta random_num
    rts
