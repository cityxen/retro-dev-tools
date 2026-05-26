#!/usr/bin/env python3
"""
kick2apple.py — Strip KickAssembler PRG header and generate Apple IIe ProDOS files

KickAssembler emits a 2-byte load-address prefix (lo, hi) followed by the
raw binary.  This script:
  1. Strips the 2-byte header and writes a raw .bin file
  2. Generates a tokenized Applesoft BASIC STARTUP program that BRUNs the binary

Applesoft STARTUP program:
  10 PRINT CHR$(4)"BRUN <name>"

Usage:
  python kick2apple.py input.prg output.bin
  python kick2apple.py prg_files/game.prg prg_files/game.bin --brun GAME
  python kick2apple.py input.prg output.bin --startup prg_files/startup.bin
  python kick2apple.py input.prg output.bin --no-startup
"""

import argparse
import sys
from pathlib import Path


def make_startup(brun_name: str) -> bytes:
    # Applesoft tokenized: 10 PRINT CHR$(4)"BRUN <brun_name>"
    # Loads at $0801. next_ptr = $0801 + line_length
    # Line: [next_ptr(2)] [line_num(2)] [PRINT] [CHR$(4)] ["] [BRUN ] [name] ["] [EOL]
    name_bytes = brun_name.upper().encode('ascii')
    line_len = 2 + 2 + 1 + 4 + 1 + 5 + len(name_bytes) + 1 + 1  # incl. next_ptr field
    next_ptr = 0x0801 + line_len
    startup = bytearray()
    startup += bytes([next_ptr & 0xFF, (next_ptr >> 8) & 0xFF])  # next line ptr
    startup += bytes([0x0A, 0x00])                                # line number 10
    startup += bytes([0xBA])                                      # PRINT
    startup += bytes([0xC7, 0x28, 0x34, 0x29])                   # CHR$(4)
    startup += bytes([0x22])                                      # "
    startup += b'BRUN '
    startup += name_bytes
    startup += bytes([0x22])                                      # "
    startup += bytes([0x00])                                      # EOL
    startup += bytes([0x00, 0x00])                                # end of program
    return bytes(startup)


def main() -> None:
    ap = argparse.ArgumentParser(
        description='Strip KickAssembler PRG header and generate Apple IIe ProDOS files.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input',  help='Input PRG file (KickAssembler output with 2-byte load-address header)')
    ap.add_argument('output', help='Output raw binary .bin file')
    ap.add_argument('--brun', default='',
                    help='Filename for the BRUN command in STARTUP (default: stem of output file, uppercased)')
    ap.add_argument('--startup', default='',
                    help='Path for the generated STARTUP binary (default: startup.bin alongside output)')
    ap.add_argument('--no-startup', action='store_true',
                    help='Skip generating the STARTUP binary')
    args = ap.parse_args()

    in_path  = Path(args.input)
    out_path = Path(args.output)

    if not in_path.exists():
        sys.exit(f'ERROR: {in_path} not found. Did the assembler step succeed?')

    prg = in_path.read_bytes()
    if len(prg) < 3:
        sys.exit(f'ERROR: {in_path} is too small to be a valid PRG.')

    load_lo, load_hi = prg[0], prg[1]
    load_addr = load_hi * 256 + load_lo
    if load_lo != 0x00 or load_hi != 0x08:
        print(f'  WARNING: unexpected load address ${load_addr:04X} (expected $0800) -- stripping anyway')

    data = prg[2:]
    out_path.write_bytes(data)
    print(f'  BIN   : {out_path} ({len(data)} bytes at ${load_addr:04X})')

    if not args.no_startup:
        brun_name = args.brun or out_path.stem.upper()
        startup_path = Path(args.startup) if args.startup else out_path.parent / 'startup.bin'
        startup = make_startup(brun_name)
        startup_path.write_bytes(startup)
        print(f'  STARTUP: {startup_path} ({len(startup)} bytes) — BRUN {brun_name}')


if __name__ == '__main__':
    main()
