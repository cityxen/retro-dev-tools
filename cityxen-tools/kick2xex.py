#!/usr/bin/env python3
"""
make_xex.py — Wrap a KickAssembler .prg output as an Atari XEX

KickAssembler emits a 2-byte load-address prefix (lo, hi) followed by the
raw binary.  This script strips the prefix, then builds a standard Atari
Executable (XEX) with:
  - Segment 1: the program data at its load address
  - Run-address segment at $02E0-$02E1 pointing to load address

Usage:
  python make_xex.py input.prg output.xex
  python make_xex.py prg_files/game.prg prg_files/game.xex
"""

import argparse
import sys
from pathlib import Path


def make_xex(in_path: Path, out_path: Path) -> None:
    raw = in_path.read_bytes()

    if len(raw) < 3:
        sys.exit(f'ERROR: {in_path} is too small to be a valid PRG.')

    load_lo, load_hi = raw[0], raw[1]
    load_addr = load_hi * 256 + load_lo
    data = raw[2:]
    end_addr = load_addr + len(data) - 1
    end_lo = end_addr & 0xFF
    end_hi = (end_addr >> 8) & 0xFF

    print(f'  Load  : ${load_addr:04X}')
    print(f'  End   : ${end_addr:04X}')
    print(f'  Size  : {len(data)} bytes')

    xex = bytearray()
    xex += bytes([0xFF, 0xFF])           # $FFFF magic
    xex += bytes([load_lo, load_hi])     # segment start
    xex += bytes([end_lo, end_hi])       # segment end
    xex += data                          # program data
    xex += bytes([0xE0, 0x02])           # run-address segment start $02E0
    xex += bytes([0xE1, 0x02])           # run-address segment end   $02E1
    xex += bytes([load_lo, load_hi])     # run address = load address

    out_path.write_bytes(xex)
    print(f'  XEX   : {out_path} ({len(xex)} bytes)')


def main() -> None:
    ap = argparse.ArgumentParser(
        description='Wrap a KickAssembler PRG output as an Atari XEX.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input',  help='Input PRG file (KickAssembler output with 2-byte load-address header)')
    ap.add_argument('output', help='Output XEX file')
    args = ap.parse_args()

    in_path = Path(args.input)
    if not in_path.exists():
        sys.exit(f'ERROR: {in_path} not found. Did the assembler step succeed?')

    make_xex(in_path, Path(args.output))


if __name__ == '__main__':
    main()
