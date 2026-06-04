#!/usr/bin/env python3
"""
kick2apple.py — Strip the KickAssembler PRG header and build the Whackadoodle
Apple IIe ProDOS files.

Direct port of Whackadoodle/appleiie/tools/make_binary.ps1.

Inputs:  prg_files/wad_a2.prg   (KickAss output, first 2 bytes = $00 $60)
Outputs: prg_files/wad_a2.bin   (raw binary at $6000, no header)
         prg_files/startup.bin  (tokenized Applesoft BASIC, loads at $0801)

Run from anywhere; paths are resolved relative to this script's parent's parent
directory (mirrors `Set-Location $PSScriptRoot\..` in the original).
"""

from pathlib import Path

# The .ps1 did `Set-Location $PSScriptRoot\..` to anchor on the appleiie folder.
# This port lives in cityxen-tools instead, so it resolves prg_files relative to
# the current working directory -- run it from Whackadoodle\appleiie\.
base = Path.cwd()

# --- strip header ---
prg_path = base / "prg_files" / "wad_a2.prg"
prg = prg_path.read_bytes()
if prg[0] != 0x00 or prg[1] != 0x60:
    print(f"WARNING: Unexpected header bytes {prg[0]:02X} {prg[1]:02X} -- stripping anyway")
bin_data = prg[2:]
(base / "prg_files" / "wad_a2.bin").write_bytes(bin_data)
print(f"wad_a2.bin: {len(bin_data)} bytes at 0x6000")

# --- generate STARTUP Applesoft tokenized binary ---
#
# Program:  10 PRINT CHR$(4)"BRUN WAD_A2"
#
# Applesoft tokenized format (program loads at $0801 in memory):
#   [next_ptr lo/hi] [line_num lo/hi] [tokens...] [00=EOL]
#   [00 00] = end of program
#
# Tokens:
#   $BA = PRINT   $C7 = CHR$   $28 = (   $34 = 4   $29 = )
#   $22 = "       literal "BRUN WAD_A2"   $22 = "   $00 = EOL
#
# Record = 2+2+19 = 23 bytes.  Starts at $0801, so next ptr = $0818.
startup = bytes([
    0x18, 0x08,                                     # next line ptr ($0818)
    0x0A, 0x00,                                     # line number 10
    0xBA,                                           # PRINT
    0xC7, 0x28, 0x34, 0x29,                         # CHR$(4)
    0x22,                                           # "
    0x42, 0x52, 0x55, 0x4E, 0x20,                   # BRUN (space)
    0x57, 0x41, 0x44, 0x5F, 0x41, 0x32,             # WAD_A2
    0x22,                                           # "
    0x00,                                           # EOL
    0x00, 0x00,                                     # end of program
])
(base / "prg_files" / "startup.bin").write_bytes(startup)
print(f"startup.bin: {len(startup)} bytes (Applesoft line 10)")
