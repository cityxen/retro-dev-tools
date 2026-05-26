#importonce
//===========================================================================
// CityXen Apple IIe Library - Random Number Generation
//
// The Apple IIe has no SID chip oscillator for noise-based randomness.
// Two methods are provided:
//   1. LFSR (Linear Feedback Shift Register) - fast, deterministic
//   2. Free-running counter seeded by user input timing - non-deterministic
//
// Method 1 is suitable for gameplay; seed with method 2 at startup for
// better unpredictability.
//===========================================================================

// LFSR state (4 bytes = 32-bit LFSR, polynomial x^32+x^22+x^2+x+1)
random_seed:    .byte $1, $2, $4, $8   // initial seed (must be non-zero)
random_num:     .byte 0                // last random byte produced

// Free-running frame counter (incremented each VBL if timers are active)
random_counter: .byte 0

//---------------------------------------------------------------------------
// random_init - Seed the LFSR from a timing-based value
//   Call this after waiting for the first keypress (so timing is variable).
//   Mixes current random_counter into the seed bytes.
//---------------------------------------------------------------------------
random_init:
    lda random_counter
    eor random_seed
    sta random_seed
    lda random_counter
    eor #$A3
    eor random_seed + 2
    sta random_seed + 2
    rts

//---------------------------------------------------------------------------
// lda_random - Generate next pseudo-random byte, return in A.
//   Also stores result in random_num.
//   Uses a Galois 32-bit LFSR; period ~4 billion before repeating.
//---------------------------------------------------------------------------
lda_random:
    // Shift right one bit with feedback from bit 0
    lsr random_seed + 3
    ror random_seed + 2
    ror random_seed + 1
    ror random_seed
    bcc lr_no_feedback
    // Apply tap polynomial: XOR bits 31, 21, 1, 0
    lda random_seed + 3
    eor #$80        // bit 31
    sta random_seed + 3
    lda random_seed + 2
    eor #$20        // bit 21
    sta random_seed + 2
    lda random_seed
    eor #$03        // bits 1, 0
    sta random_seed
lr_no_feedback:
    lda random_seed // return low byte as random value
    sta random_num
    rts

//---------------------------------------------------------------------------
// lda_random_range - Return random byte in range [0, range-1]
//   On entry: X = range (1-256; 0 = 256)
//   On exit:  A = random value 0..X-1
//   Uses modulo; slight bias for non-power-of-2 ranges.
//---------------------------------------------------------------------------
lda_random_range:
    jsr lda_random
    stx ZP_TMP0
    cpx #0
    beq lrr_done       // range=256, use full byte
    // A = A mod X using repeated subtraction (fast for small ranges)
lrr_mod:
    cmp ZP_TMP0
    bcc lrr_done
    sbc ZP_TMP0
    bra lrr_mod
lrr_done:
    rts

//===========================================================================
