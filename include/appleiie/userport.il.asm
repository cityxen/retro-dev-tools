#importonce
//===========================================================================
// CityXen Apple IIe Library - User Port / Auxiliary I/O (Placeholder)
//
// The Apple IIe has no direct equivalent of the C64 user port.
// Peripheral expansion is handled through the 7 peripheral slots
// ($C100-$CFFF ROM space, $C800-$CFFF shared ROM).
//
// Slot-based I/O is addressed per slot:
//   Slot 1 I/O: $C0B0-$C0BF  (printer card, etc.)
//   Slot 2 I/O: $C0C0-$C0CF
//   Slot 3 I/O: $C0D0-$C0DF
//   Slot 4 I/O: $C0E0-$C0EF  (commonly Mockingboard)
//   Slot 5 I/O: $C0F0-$C0FF
//   Slot 6 I/O: $C0E0-... (disk controller)
//   Slot 7 I/O: $C0F8-$C0FF
//
// Add slot-specific I/O routines here as needed.
//===========================================================================

//===========================================================================
