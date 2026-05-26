#!/usr/bin/env python3
"""
c64sprites2apple.py — Convert C64 sprite data to Apple IIe HGR KickAssembler data

C64 sprites are 24x21 pixels stored as 3 bytes per row x 21 rows = 63 bytes,
padded to 64 bytes per sprite block. Bit 7 of each byte is the leftmost pixel.

Apple IIe HGR bytes pack 7 pixels per byte. Bit 0 = leftmost pixel, bit 6 =
rightmost, bit 7 = palette select (0=violet/green, 1=blue/orange). For
monochrome sprites use 0 (default) or 1.

Single-color (default):
  24 C64 pixels per row -> 4 HGR bytes (28 pixels; last 4 zero-padded)

Multi-color (--multicolor):
  Each bit-pair in the C64 sprite = one visual pixel (00=off, else on).
  --stretch (default): doubles each pixel to preserve visual width -> 24px -> 4 HGR bytes
  no --stretch: 12 pixels -> 2 HGR bytes

Input formats (auto-detected by extension, or set with --format):
  binary    .bin  .raw  .spr  .64s  — raw 64-byte blocks
  kickass   .asm  .s    .ka        — KickAssembler .byte directives

Usage:
  python c64sprites2apple.py sprites.bin -o sprites.asm
  python c64sprites2apple.py sprites.asm -o sprites.asm --label spr_player
  python c64sprites2apple.py sprites.bin --multicolor --sprites 4
  python c64sprites2apple.py sprites.bin --palette 1 --label enemy
"""

import argparse
import re
import sys
from pathlib import Path

C64_ROWS        = 21
C64_ROW_BYTES   = 3
C64_SPRITE_BYTES = C64_ROWS * C64_ROW_BYTES   # 63
C64_SPRITE_BLOCK = 64
HGR_BITS        = 7   # pixels per HGR byte

BINARY_EXTS  = {'.bin', '.raw', '.spr', '.64s'}
KICKASS_EXTS = {'.asm', '.s', '.ka'}


# ---------------------------------------------------------------------------
# Pixel extraction
# ---------------------------------------------------------------------------

def extract_pixels_single(row_bytes: bytes) -> list[int]:
    """Extract 24 pixels from 3 C64 single-color sprite bytes (MSB = leftmost)."""
    pixels = []
    for b in row_bytes:
        for bit in range(7, -1, -1):
            pixels.append((b >> bit) & 1)
    return pixels  # 24 pixels


def extract_pixels_multi(row_bytes: bytes, stretch: bool) -> list[int]:
    """Extract pixels from 3 C64 multi-color sprite bytes.
    Each bit-pair: 00=transparent/off, 01/10/11=on.
    stretch=True doubles each pixel to preserve visual width (12->24 pixels)."""
    pixels = []
    for b in row_bytes:
        for pair in range(3, -1, -1):   # 4 pairs per byte, MSB first
            val = (b >> (pair * 2)) & 0b11
            px = 0 if val == 0 else 1
            if stretch:
                pixels.extend([px, px])
            else:
                pixels.append(px)
    return pixels  # 24 if stretch, 12 if not


# ---------------------------------------------------------------------------
# HGR packing
# ---------------------------------------------------------------------------

def pixels_to_hgr(pixels: list[int], palette: int = 0) -> list[int]:
    """Pack pixels into Apple HGR bytes (7 pixels/byte, bit0=leftmost, bit7=palette)."""
    result = []
    for i in range(0, len(pixels), HGR_BITS):
        chunk = pixels[i:i + HGR_BITS]
        while len(chunk) < HGR_BITS:
            chunk.append(0)
        byte = 0
        for bit_idx, px in enumerate(chunk):
            if px:
                byte |= (1 << bit_idx)
        if palette:
            byte |= 0x80
        result.append(byte)
    return result


# ---------------------------------------------------------------------------
# Input parsing
# ---------------------------------------------------------------------------

def load_binary(path: Path, num_sprites: int) -> list[bytes]:
    data = path.read_bytes()
    available = len(data) // C64_SPRITE_BLOCK
    count = min(num_sprites, available) if num_sprites else available
    if count == 0:
        sys.exit(f'ERROR: {path} contains no complete 64-byte sprite blocks.')
    sprites = []
    for i in range(count):
        block = data[i * C64_SPRITE_BLOCK: i * C64_SPRITE_BLOCK + C64_SPRITE_BYTES]
        sprites.append(block)
    return sprites


def load_kickass(path: Path, num_sprites: int) -> list[bytes]:
    text = path.read_text(encoding='utf-8', errors='replace')
    all_bytes: list[int] = []
    for line in text.splitlines():
        # Strip comments
        for sep in ('//', ';'):
            idx = line.find(sep)
            if idx >= 0:
                line = line[:idx]
        m = re.match(r'\s*\.byte\s+(.+)', line, re.IGNORECASE)
        if not m:
            continue
        for tok in re.findall(r'\$([0-9a-fA-F]+)|\b([0-9]+)\b', m.group(1)):
            hex_v, dec_v = tok
            if hex_v:
                all_bytes.append(int(hex_v, 16) & 0xFF)
            elif dec_v:
                v = int(dec_v)
                if 0 <= v <= 255:
                    all_bytes.append(v)

    available = len(all_bytes) // C64_SPRITE_BLOCK
    if available == 0:
        # Try treating all bytes as one sprite even without a full 64-byte block
        if len(all_bytes) >= C64_SPRITE_BYTES:
            available = 1
        else:
            sys.exit(f'ERROR: not enough .byte data in {path} for even one sprite (need {C64_SPRITE_BYTES} bytes).')

    count = min(num_sprites, available) if num_sprites else available
    sprites = []
    for i in range(count):
        offset = i * C64_SPRITE_BLOCK
        sprites.append(bytes(all_bytes[offset: offset + C64_SPRITE_BYTES]))
    return sprites


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert_sprite(sprite_bytes: bytes, multicolor: bool, stretch: bool, palette: int) -> list[list[int]]:
    """Convert one 63-byte C64 sprite to a list of 21 HGR rows."""
    rows = []
    for row in range(C64_ROWS):
        rb = sprite_bytes[row * C64_ROW_BYTES: row * C64_ROW_BYTES + C64_ROW_BYTES]
        if multicolor:
            pixels = extract_pixels_multi(rb, stretch)
        else:
            pixels = extract_pixels_single(rb)
        rows.append(pixels_to_hgr(pixels, palette))
    return rows


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def pixel_preview(hgr_row: list[int]) -> str:
    """ASCII preview of a HGR row (X=set, .=clear)."""
    chars = []
    for byte in hgr_row:
        for bit in range(7):
            chars.append('X' if (byte >> bit) & 1 else '.')
    return ''.join(chars).rstrip('.')


def format_output(sprites_hgr: list[list[list[int]]], label_prefix: str) -> str:
    lines = [
        f'// Generated by c64sprites2apple.py',
        f'// {len(sprites_hgr)} sprite(s), {C64_ROWS} rows each',
        f'// Data format: Apple IIe HGR bytes (7 pixels/byte, bit0=leftmost)',
        '',
    ]
    for idx, rows in enumerate(sprites_hgr):
        label = f'{label_prefix}{idx}' if len(sprites_hgr) > 1 else label_prefix
        width = len(rows[0]) if rows else 0
        lines.append(f'{label}:  // {width} bytes wide x {C64_ROWS} rows')
        for row_idx, hgr_row in enumerate(rows):
            hex_vals = ','.join(f'${b:02x}' for b in hgr_row)
            preview = pixel_preview(hgr_row)
            lines.append(f'.byte {hex_vals}  // {row_idx:02d}: {preview}')
        lines.append('')
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description='Convert C64 sprite data to Apple IIe HGR KickAssembler data.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input', help='Input file (binary sprite data or KickAssembler .asm)')
    ap.add_argument('-o', '--output', default='', help='Output file (default: stdout)')
    ap.add_argument('-f', '--format', choices=['binary', 'kickass'], default='',
                    help='Input format (default: auto-detect by extension)')
    ap.add_argument('-n', '--sprites', type=int, default=0,
                    help='Number of sprites to convert (default: all found in file)')
    ap.add_argument('-l', '--label', default='spr_data',
                    help='Label prefix for output data blocks (default: spr_data)')
    ap.add_argument('-m', '--multicolor', action='store_true',
                    help='Treat input as multi-color C64 sprites (2 bits per pixel)')
    ap.add_argument('--no-stretch', action='store_true',
                    help='Multi-color: do not double pixels (outputs 12px/2 HGR bytes wide instead of 24px/4)')
    ap.add_argument('-p', '--palette', type=int, choices=[0, 1], default=0,
                    help='HGR palette bit (0=violet/green, 1=blue/orange, default: 0)')
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        sys.exit(f'ERROR: {src} not found.')

    # Detect format
    fmt = args.format
    if not fmt:
        ext = src.suffix.lower()
        if ext in BINARY_EXTS:
            fmt = 'binary'
        elif ext in KICKASS_EXTS:
            fmt = 'kickass'
        else:
            sys.exit(f'ERROR: cannot auto-detect format for "{src.suffix}". Use --format.')

    stretch = not args.no_stretch

    if fmt == 'binary':
        sprites_raw = load_binary(src, args.sprites)
    else:
        sprites_raw = load_kickass(src, args.sprites)

    sprites_hgr = [
        convert_sprite(s, args.multicolor, stretch, args.palette)
        for s in sprites_raw
    ]

    width = len(sprites_hgr[0][0]) if sprites_hgr else 0
    mode = 'multi-color' + (' stretched' if stretch else '') if args.multicolor else 'single-color'
    print(f'  Sprites : {len(sprites_hgr)}', file=sys.stderr)
    print(f'  Mode    : {mode}', file=sys.stderr)
    print(f'  HGR size: {width} bytes wide x {C64_ROWS} rows', file=sys.stderr)

    output = format_output(sprites_hgr, args.label)

    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        print(f'  Output  : {args.output}', file=sys.stderr)
    else:
        sys.stdout.write(output)


if __name__ == '__main__':
    main()
