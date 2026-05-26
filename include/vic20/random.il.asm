//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — Random Number Generation
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// The VIC-20 has no SID oscillator, but we can derive noise from
// the VIC chip's noise channel output or use a software LFSR.
//
// random_init_vic: configure VIC noise voice for sampling.
// lda_random_vic:  read from the VIC's "noise" by toggling frequency
//                  and reading back the TV-X jitter byte ($9000).
//
// lda_random_lfsr: software 8-bit LFSR (no hardware dependency).
//                  Call random_init first to seed it.
//
// random_num: holds the last generated value.
//////////////////////////////////////////////////////////////////

#importonce

random_num:     .byte $a5   // seed
lfsr_state:     .byte $a5   // LFSR internal state (non-zero required)

//////////////////////////////////////////////////////////////////
// VIC noise-based random
// Enable the noise channel, then read back $9004 (raster), which
// varies with timing, as a cheap entropy source.

random_init_vic:
    lda #$8f            // enable noise channel, frequency = $0F
    sta VIC_SOUND_NOISE
    lda #$0f            // set master volume so noise runs
    sta VIC_SOUND_VOLUME
    rts

lda_random_vic:
    lda VIC_RASTER      // raster line varies with execution timing
    eor random_num      // mix with previous value
    eor VIC_SOUND_VOLUME
    sta random_num
    rts

//////////////////////////////////////////////////////////////////
// Software LFSR random (hardware-independent)
// 8-bit maximal-length LFSR (polynomial x^8 + x^6 + x^5 + x^4 + 1)

random_init:
    lda #$a5            // non-zero seed
    sta lfsr_state
    sta random_num
    rts

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
