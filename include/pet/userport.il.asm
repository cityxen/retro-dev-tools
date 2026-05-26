//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// User Port / VIA / PIA Reference
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// The PET 4032 does not have a user port connector in the same sense as
// the C64.  The VIA 6522 ($E840) and both PIA 6520 chips ($E810, $E820)
// are accessible to user programs.
//
// VIA 6522 ($E840) — IEEE-488 bus + user I/O
//   PRA  ($E840): Port A (IEEE-488 data, etc.)
//   PRB  ($E841): Port B (IEEE-488 handshake lines)
//   DDRA ($E842): Port A direction
//   DDRB ($E843): Port B direction
//   T1   ($E844-$E847): Free-running system timer (50/60 Hz IRQ)
//   T2   ($E848-$E849): One-shot timer
//   IFR  ($E84D): Interrupt flag register
//   IER  ($E84E): Interrupt enable register
//
// PIA1 6520 ($E810) — Keyboard
//   PRA  ($E810): Keyboard row data
//   PRB  ($E812): Keyboard column select (write to select row)
//
// PIA2 6520 ($E820) — Speaker (CB2), IEEE-488 control
//   CRB  ($E823): bit 3 = CB2 output → speaker
//     CB2 high: CRB = (CRB & $F7) | $0E   (PET_SPEAKER_HIGH)
//     CB2 low:  CRB = (CRB & $F7) | $0C   (PET_SPEAKER_LOW)
//
// All hardware addresses are defined in Constants.asm as PET_VIA_* and PET_PIA*.
//////////////////////////////////////////////////////////////////////////////////////

// (header-only — all constants in Constants.asm)
