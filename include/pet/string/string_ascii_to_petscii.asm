//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// ASCII to PETSCII Conversion
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// ascii_to_petscii — convert A (ASCII) to PETSCII, return in A
ascii_to_petscii:
    cmp #$41
    bcc a2p_done
    cmp #$7F
    bcs a2p_done
    sec
    sbc #$5F
a2p_done:
    rts

// ascii_to_petscii_kp — version for KERNAL_CHROUT (kernel print)
ascii_to_petscii_kp:
    cmp #$41
    bcc a2pkp_done
    cmp #$7F
    bcs a2pkp_done
    sec
    sbc #$1f
a2pkp_done:
    rts
