#!/usr/bin/env python3
"""
spriteformatter-c64.py — Reformat KickAssembler C64 sprite .byte data to CityXen binary style

Reads .byte directives (hex $xx, binary %xxxxxxxx, decimal) or raw binary sprite
files and outputs the CityXen sprites.asm layout:
  - 21 rows x 3 bytes per sprite, formatted as %xxxxxxxx binary literals
  - Row-number comments (// row  N)
  - Optional sprite name / address / pointer header comments
  - Optional ASCII pixel-art preview appended to each row comment

Each C64 sprite is 24x21 pixels = 63 data bytes + 1 padding byte = 64-byte block.
Use --stride 63 if your input has no padding bytes.

Input formats (auto-detected by extension, or --format):
  kickass   .asm  .s  .ka   — KickAssembler .byte directives
  binary    .bin  .raw  .spr  .64s  — raw byte blocks

Usage:
  python spriteformatter-c64.py sprites.asm
  python spriteformatter-c64.py sprites.asm -o out.asm
  python spriteformatter-c64.py sprites.asm --names "Player Stand,Walk 1,Walk 2"
  python spriteformatter-c64.py sprites.bin --base-addr 0x3000 --base-ptr 0xC0
  python spriteformatter-c64.py sprites.asm --preview
  python spriteformatter-c64.py sprites.asm --sprites 3 --stride 63
"""

import argparse
import re
import sys
from pathlib import Path

C64_ROWS        = 21
C64_ROW_BYTES   = 3
C64_DATA_BYTES  = C64_ROWS * C64_ROW_BYTES   # 63
C64_BLOCK_BYTES = 64

KICKASS_EXTS  = {'.asm', '.s', '.ka'}
BINARY_EXTS   = {'.bin', '.raw', '.spr', '.64s'}

LINE_WIDTH    = 86   # total characters for separator lines
DIVIDER_CHAR  = '─'   # BOX DRAWINGS LIGHT HORIZONTAL (─)


# ---------------------------------------------------------------------------
# Byte parsing
# ---------------------------------------------------------------------------

def parse_byte_values(operand: str) -> list[int]:
    """Extract integer byte values from the operand part of a .byte directive.

    Handles: $xx (hex), %xxxxxxxx (binary), decimal (0-255).
    """
    values = []
    i = 0
    while i < len(operand):
        ch = operand[i]
        if ch in ' \t,':
            i += 1
        elif ch == '$':                          # hex: $xx
            j = i + 1
            while j < len(operand) and operand[j] in '0123456789abcdefABCDEF':
                j += 1
            if j > i + 1:
                values.append(int(operand[i+1:j], 16) & 0xFF)
            i = j
        elif ch == '%':                          # binary: %01010101
            j = i + 1
            while j < len(operand) and operand[j] in '01':
                j += 1
            if j > i + 1:
                values.append(int(operand[i+1:j], 2) & 0xFF)
            i = j
        elif ch.isdigit():                       # decimal
            j = i
            while j < len(operand) and operand[j].isdigit():
                j += 1
            v = int(operand[i:j])
            if 0 <= v <= 255:
                values.append(v)
            i = j
        else:
            i += 1
    return values


def strip_comment(line: str) -> str:
    """Remove // or ; comment from a line."""
    for sep in ('//', ';'):
        idx = line.find(sep)
        if idx >= 0:
            return line[:idx]
    return line


# ---------------------------------------------------------------------------
# Input loading
# ---------------------------------------------------------------------------

def load_kickass(path: Path) -> list[int]:
    """Parse .byte directives from a KickAssembler source file."""
    all_bytes: list[int] = []
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        clean = strip_comment(line)
        m = re.match(r'\s*\.byte\s+(.+)', clean, re.IGNORECASE)
        if m:
            all_bytes.extend(parse_byte_values(m.group(1)))
    return all_bytes


def load_binary(path: Path) -> list[int]:
    """Load raw bytes from a binary sprite file."""
    return list(path.read_bytes())


# ---------------------------------------------------------------------------
# Sprite grouping
# ---------------------------------------------------------------------------

def group_sprites(all_bytes: list[int], stride: int, num_sprites: int | None) -> list[list[int]]:
    """Split flat byte list into per-sprite data lists of C64_DATA_BYTES each.

    stride: bytes per input block (64 if padding byte present, 63 if not).
    """
    available = len(all_bytes) // stride
    if available == 0:
        needed = C64_DATA_BYTES
        sys.exit(
            f'ERROR: not enough byte data for even one sprite '
            f'(need {needed} data bytes, found {len(all_bytes)}).'
        )
    count = min(num_sprites, available) if num_sprites is not None else available
    sprites = []
    for i in range(count):
        offset = i * stride
        sprites.append(all_bytes[offset: offset + C64_DATA_BYTES])
    return sprites


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def fmt_bin(b: int) -> str:
    return f'%{b:08b}'


def pixel_preview(b0: int, b1: int, b2: int) -> str:
    """24-character ASCII pixel art: '#' = set, '-' = clear."""
    chars = []
    for b in (b0, b1, b2):
        for bit in range(7, -1, -1):
            chars.append('#' if (b >> bit) & 1 else '-')
    return ''.join(chars)


def make_header(name: str, addr: int, ptr: int) -> str:
    """Build the ── Name ($ADDR, pointer $XX) ──────── header line."""
    label = f'// {DIVIDER_CHAR}{DIVIDER_CHAR} {name} (${addr:04X}, pointer ${ptr:02X}) '
    fill = max(0, LINE_WIDTH - len(label))
    return label + DIVIDER_CHAR * fill


def format_sprite(
    data: list[int],
    name: str,
    addr: int,
    ptr: int,
    show_header: bool,
) -> list[str]:
    """Format one sprite's data as CityXen-style .byte lines."""
    lines: list[str] = []

    if show_header:
        lines.append(make_header(name, addr, ptr))

    for row in range(C64_ROWS):
        b0, b1, b2 = data[row * 3], data[row * 3 + 1], data[row * 3 + 2]
        data_part = f'.byte {fmt_bin(b0)},{fmt_bin(b1)},{fmt_bin(b2)}'
        lines.append(f'{data_part}  // {pixel_preview(b0, b1, b2)}')

    lines.append('.byte 0                              // padding')
    lines.append('')
    return lines


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description='Reformat KickAssembler C64 sprite .byte data to CityXen binary style.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input',
                    help='Input file (.asm KickAssembler source, or .bin/.spr raw binary)')
    ap.add_argument('-o', '--output', default='',
                    help='Output file (default: stdout)')
    ap.add_argument('-f', '--format', choices=['kickass', 'binary'], default='',
                    help='Input format (default: auto-detect by file extension)')
    ap.add_argument('-n', '--names', default='',
                    help='Comma-separated sprite display names, e.g. "Player Stand,Walk 1"')
    ap.add_argument('--base-addr', default='0x3000',
                    help='Base memory address of first sprite in hex (default: 0x3000)')
    ap.add_argument('--base-ptr', default='0xC0',
                    help='Base sprite pointer byte of first sprite in hex (default: 0xC0)')
    ap.add_argument('--sprites', type=int, default=None,
                    help='Number of sprites to process (default: all found)')
    ap.add_argument('--stride', type=int, choices=[63, 64], default=64,
                    help='Input bytes per sprite block: 64 (with padding, default) or 63 (data only)')
    ap.add_argument('--no-headers', action='store_true',
                    help='Omit the sprite name/address header comment lines')
    args = ap.parse_args()

    # Ensure stdout can handle UTF-8 (the ─ divider char needs it on Windows)
    sys.stdout.reconfigure(encoding='utf-8')

    src = Path(args.input)
    if not src.exists():
        sys.exit(f'ERROR: {src} not found.')

    # Detect format
    fmt = args.format
    if not fmt:
        ext = src.suffix.lower()
        if ext in KICKASS_EXTS:
            fmt = 'kickass'
        elif ext in BINARY_EXTS:
            fmt = 'binary'
        else:
            sys.exit(
                f'ERROR: cannot auto-detect format for "{src.suffix}". '
                f'Use --format kickass or --format binary.'
            )

    # Parse base address / pointer
    try:
        base_addr = int(args.base_addr, 0)
        base_ptr  = int(args.base_ptr, 0)
    except ValueError as e:
        sys.exit(f'ERROR: bad address/pointer value — {e}')

    # Load bytes
    if fmt == 'kickass':
        all_bytes = load_kickass(src)
    else:
        all_bytes = load_binary(src)

    # Group into sprites
    sprites = group_sprites(all_bytes, args.stride, args.sprites)

    # Parse names
    name_list = [n.strip() for n in args.names.split(',')] if args.names else []

    # Generate output lines
    output_lines: list[str] = [
        f'// Generated by spriteformatter-c64.py from {src.name}',
        f'// {len(sprites)} sprite(s), {C64_ROWS} rows x {C64_ROW_BYTES} bytes each',
        '',
    ]
    for idx, data in enumerate(sprites):
        name = name_list[idx] if idx < len(name_list) else f'Sprite {idx}'
        addr = base_addr + idx * C64_BLOCK_BYTES
        ptr  = base_ptr  + idx
        output_lines.extend(
            format_sprite(data, name, addr, ptr,
                          show_header=not args.no_headers)
        )

    text = '\n'.join(output_lines)

    # Write output
    if args.output:
        Path(args.output).write_text(text, encoding='utf-8')
        print(f'  Output  : {args.output}', file=sys.stderr)
    else:
        sys.stdout.write(text)
        sys.stdout.write('\n')

    # Summary to stderr
    print(f'  Sprites : {len(sprites)}', file=sys.stderr)
    print(f'  Base    : ${base_addr:04X}  pointer ${base_ptr:02X}', file=sys.stderr)
    print(f'  Stride  : {args.stride} bytes/sprite', file=sys.stderr)


if __name__ == '__main__':
    main()
