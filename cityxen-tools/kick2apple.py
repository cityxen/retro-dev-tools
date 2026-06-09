#!/usr/bin/env python3
"""
kick2apple.py — Strip the KickAssembler PRG load-address header to produce a
raw Apple II binary, and optionally generate an Applesoft STARTUP loader.

A KickAssembler PRG begins with a 2-byte little-endian load address followed by
the program bytes.  Apple II raw binaries have no such header, so this tool
copies everything after the first two bytes to the output file.

Usage:
    kick2apple.py SOURCE.prg OUTPUT.bin [--addr ADDR]
                  [--startup STARTUP.bin] [--brun NAME]

  SOURCE.prg          KickAssembler PRG (first 2 bytes = load address lo/hi)
  OUTPUT.bin          raw binary to write (header stripped)
  --addr ADDR         expected load address, e.g. 0x6000 or 24576.
                      Default: read from the PRG header.  When given, a
                      mismatch with the header is reported as a warning.
  --startup PATH      also write an Applesoft tokenized loader to PATH that
                      runs:  10 PRINT CHR$(4)"BRUN <NAME>"
  --brun NAME         BRUN target name for the STARTUP loader.
                      Default: OUTPUT file name (stem), uppercased.
"""

import argparse
import sys
from pathlib import Path


def make_startup(name):
    """Tokenized Applesoft program:

        5  HOME : PRINT "LOADING <name>"
        10 PRINT CHR$(4)"BRUN <name>"

    Loads at $0801.  Each stored line is:
      [link lo/hi][line# lo/hi][tokens...][00 EOL]  then [00 00] end-of-program.
    The link points to the next line's link field.  DOS commands are issued as a
    printed string (CHR$(4) then "BRUN ..."), so the quoted text is literal, not
    tokens.
    """
    # (line number, token bytes excluding the trailing EOL)
    lines = [
        (5,
            bytes([0x97, 0x3A, 0xBA, 0x22])             # HOME : PRINT "
            + ("LOADING " + name).encode("ascii")
            + bytes([0x22])),                           # "
        (10,
            bytes([0xBA, 0xE7, 0x28, 0x34, 0x29, 0x22])  # PRINT CHR$(4)"
            + ("BRUN " + name).encode("ascii")
            + bytes([0x22])),                            # "
    ]

    out = bytearray()
    addr = 0x0801
    for num, tokens in lines:
        body = bytes([num & 0xFF, num >> 8]) + tokens + bytes([0x00])  # line# + tokens + EOL
        link = addr + 2 + len(body)                                    # next line's link field
        out += bytes([link & 0xFF, link >> 8]) + body
        addr = link
    out += bytes([0x00, 0x00])  # end of program
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(
        description="Strip a KickAssembler PRG header to a raw Apple II binary.",
    )
    ap.add_argument("source", help="KickAssembler PRG input")
    ap.add_argument("output", help="raw binary output (header stripped)")
    ap.add_argument(
        "--addr",
        type=lambda s: int(s, 0),
        default=None,
        help="expected load address (e.g. 0x6000); default: read from PRG header",
    )
    ap.add_argument(
        "--startup",
        metavar="PATH",
        default=None,
        help="also write an Applesoft STARTUP loader to PATH",
    )
    ap.add_argument(
        "--brun",
        metavar="NAME",
        default=None,
        help="BRUN target name for --startup (default: output stem, uppercased)",
    )
    args = ap.parse_args()

    src = Path(args.source)
    out = Path(args.output)

    prg = src.read_bytes()
    if len(prg) < 2:
        sys.exit(f"ERROR: {src} is too small to contain a PRG header")

    header_addr = prg[0] | (prg[1] << 8)
    if args.addr is not None and args.addr != header_addr:
        print(
            f"WARNING: header load address ${header_addr:04X} != "
            f"expected ${args.addr:04X} -- stripping anyway"
        )
    load_addr = args.addr if args.addr is not None else header_addr

    bin_data = prg[2:]
    out.write_bytes(bin_data)
    print(f"{out.name}: {len(bin_data)} bytes at ${load_addr:04X}")

    if args.startup is not None:
        name = args.brun if args.brun is not None else out.stem.upper()
        startup_path = Path(args.startup)
        startup = make_startup(name)
        startup_path.write_bytes(startup)
        print(f"{startup_path.name}: {len(startup)} bytes (Applesoft: BRUN {name})")


if __name__ == "__main__":
    main()
