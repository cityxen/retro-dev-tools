//////////////////////////////////////////////////////////////////
// CITYXEN COMMODORE VIC-20 LIBRARY — User Port
//
// https://github.com/cityxen/CommodoreVIC20_Programming
// https://linktr.ee/cityxen
//
// The VIC-20 user port connects to VIA 1 Port A ($9110).
// Data direction register at $9112 (1 = output, 0 = input per bit).
//
// USER_PORT_DATA     = $9110  (VIA1 Port A)
// USER_PORT_DATA_DIR = $9112  (VIA1 Port A DDR)
//
// Usage example:
//   lda #$FF         ; all bits = output
//   sta USER_PORT_DATA_DIR
//   lda #$AA
//   sta USER_PORT_DATA
//////////////////////////////////////////////////////////////////

#importonce

// (USER_PORT_DATA and USER_PORT_DATA_DIR are defined in Constants.asm)

// SetUserPortOutput(): configure all user port pins as output.
.macro SetUserPortOutput() {
    lda #$FF
    sta USER_PORT_DATA_DIR
}

// SetUserPortInput(): configure all user port pins as input.
.macro SetUserPortInput() {
    lda #$00
    sta USER_PORT_DATA_DIR
}

// WriteUserPort(val): write byte to user port.
.macro WriteUserPort(val) {
    lda #val
    sta USER_PORT_DATA
}

// ReadUserPort(): read user port into A.
.macro ReadUserPort() {
    lda USER_PORT_DATA
}
