//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE 16 / PLUS-4 LIBRARY — User Port stub
//
// https://github.com/cityxen/Commodore16_Programming
// https://linktr.ee/cityxen
//
// The Commodore 16 does NOT have a user port.
// The Plus-4 has a limited user port via TED pins.
//
// For Plus-4 user port access, use the TED registers directly;
// there is no dedicated VIA-style DDR register as on the C64/VIC-20.
//
// This file is a stub for source-level compatibility with C64/VIC-20
// projects that reference the user port API.
//////////////////////////////////////////////////////////////////

#importonce

// No hardware user port on C16.
// On Plus-4, user port I/O is available via TED $FF12 and $FF08.
// Implement custom routines for Plus-4 user port access if needed.
