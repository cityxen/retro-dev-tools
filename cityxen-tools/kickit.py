#!/usr/bin/env python3
"""
kickit.py — Convert any common assembler byte-data format to KickAssembler syntax.

Supported input formats
-----------------------
  Text assembler formats (auto-detected by directive keyword):
    .byte   $xx,...      KickAssembler / CA65
    !byte   $xx,...      ACME / 64tass
    dc.b    $xx,...      DASM / Motorola
    .db     $xx,...      various
    db      $xx,...      NASM / MASM
    dfb     $xx,...      Merlin
    defb    $xx,...      Z80 assemblers
    fcb     $xx,...      Motorola 6800
    hex     xx xx ...    bare hex blocks
  C / C++ source:
    { 0x1a, 0x2b, ... }  array initializers
  Raw binary:
    .bin / .raw / .prg   read as-is (use --skip to skip PRG load address)

  Comments are preserved and converted to KickAssembler // style.

Number formats recognised in text mode
---------------------------------------
  $xx   hex (KickAssembler / 6502 standard)
  0xXX  hex (C-style)
  xxH   hex with H suffix (NASM)
  %b    binary (1-8 bits)
  ddd   decimal (0-255)

Usage
-----
  python kickit.py input.asm
  python kickit.py input.bin  -o output.asm  -l charset
  python kickit.py chars.acme -o chars.asm   -n 8
  python kickit.py game.prg   --skip 2       -l prg_data
"""

import argparse
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

# Use negative lookbehind/lookahead instead of \b so that directives starting
# with non-word chars (. and !) are correctly matched.
_DIRECTIVE_KW = re.compile(
    r'(?<![A-Za-z0-9_])(\.byte|!byte|dc\.b|\.db|db|dfb|defb|fcb|hex)(?![A-Za-z0-9_])',
    re.IGNORECASE,
)

# All numeric token formats
_TOKEN_RE = re.compile(
    r'\$[0-9a-fA-F]+'       # $xx  hex
    r'|0[xX][0-9a-fA-F]+'   # 0x.. C-style hex
    r'|%[01]+'               # %b.. binary
    r'|[0-9a-fA-F]+[hH]\b'  # xxH  NASM hex suffix
    r'|\b\d+\b'              # ddd  decimal
)

_C_HEX_RE = re.compile(r'0[xX][0-9a-fA-F]+')

_LABEL_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*):?\s*$')

_BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.DOTALL)


# ---------------------------------------------------------------------------
# Number parsing
# ---------------------------------------------------------------------------

def parse_number(token: str) -> int | None:
    t = token.strip()
    if not t:
        return None
    try:
        if t.startswith('$'):
            return int(t[1:], 16)
        if t.lower().startswith('0x'):
            return int(t[2:], 16)
        if t.startswith('%'):
            return int(t[1:], 2)
        if t.lower().endswith('h') and all(c in '0123456789abcdefABCDEF' for c in t[:-1]):
            return int(t[:-1], 16)
        v = int(t, 10)
        if 0 <= v <= 255:
            return v
        return None
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Line-level helpers
# ---------------------------------------------------------------------------

def split_inline_comment(text: str) -> tuple[str, str]:
    """Split 'data ; comment' or 'data // comment' into (data, comment).
    Returns (text, '') if no inline comment found."""
    for sep in (';', '//'):
        idx = text.find(sep)
        if idx >= 0:
            return text[:idx].rstrip(), text[idx + len(sep):].strip()
    return text, ''


def bytes_to_kickass(raw: str) -> str | None:
    """Parse numeric tokens from raw and return a comma-separated $xx string,
    or None if no bytes were found."""
    vals = []
    for tok in _TOKEN_RE.findall(raw):
        v = parse_number(tok)
        if v is not None:
            vals.append(v)
    if not vals:
        return None
    return ','.join(f'${b:02x}' for b in vals)


def to_kickass_comment(text: str) -> str:
    """Return text as a // comment line."""
    return f'// {text}' if text.strip() else '//'


# ---------------------------------------------------------------------------
# Text conversion (line-by-line, preserving structure and comments)
# ---------------------------------------------------------------------------

def convert_text(text: str, default_label: str) -> tuple[str, int]:
    """Convert an assembler text file to KickAssembler format line by line.
    Comments are preserved and converted to // style.
    Returns (output_text, byte_count)."""

    # Expand block comments into // lines first
    def expand_block(m: re.Match) -> str:
        inner = m.group(0)[2:-2]
        result = []
        for ln in inner.splitlines():
            ln = ln.strip().lstrip('*').strip()
            result.append(f'// {ln}' if ln else '//')
        return '\n'.join(result)

    text = _BLOCK_COMMENT.sub(expand_block, text)

    out_lines: list[str] = []
    found_label = False
    byte_count = 0

    for line in text.splitlines():
        stripped = line.strip()

        # Blank line — preserve
        if not stripped:
            out_lines.append('')
            continue

        # Full-line * comment (only when * is first non-whitespace char)
        if stripped.startswith('*'):
            out_lines.append(to_kickass_comment(stripped[1:].strip()))
            continue

        # Full-line ; comment
        if stripped.startswith(';'):
            out_lines.append(to_kickass_comment(stripped[1:].strip()))
            continue

        # Already a // comment
        if stripped.startswith('//'):
            out_lines.append(stripped)
            continue

        # Label on its own line
        lm = _LABEL_RE.match(stripped)
        if lm:
            found_label = True
            out_lines.append(f'{lm.group(1)}:')
            continue

        # Label + data on same line: "label: !byte $xx,..." or "label !byte $xx,..." (Merlin)
        label_data_m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):?\s+', stripped)
        if label_data_m and _DIRECTIVE_KW.search(stripped[label_data_m.end():]):
            found_label = True
            out_lines.append(f'{label_data_m.group(1)}:')
            stripped = stripped[label_data_m.end():]
            # Fall through to data-line handling below

        # Data line with a byte directive
        dm = _DIRECTIVE_KW.search(stripped)
        if dm:
            rest = stripped[dm.end():]
            data_part, comment = split_inline_comment(rest)
            converted = bytes_to_kickass(data_part)
            if converted is not None:
                byte_count += converted.count(',') + 1
                line_out = f'.byte {converted}'
                if comment:
                    line_out += f'  // {comment}'
                out_lines.append(line_out)
            elif comment:
                out_lines.append(to_kickass_comment(comment))
            continue

        # Other lines (constants, org, etc.) — pass through with comment conversion
        data_part, comment = split_inline_comment(stripped)
        line_out = data_part.rstrip()
        if comment:
            line_out += f'  // {comment}'
        out_lines.append(line_out)

    if not found_label and default_label:
        out_lines.insert(0, f'{default_label}:')

    return '\n'.join(out_lines).rstrip() + '\n', byte_count


# ---------------------------------------------------------------------------
# Binary-format loading and formatting
# ---------------------------------------------------------------------------

def load_binary(path: Path, skip: int) -> bytes:
    data = path.read_bytes()
    if skip and len(data) > skip:
        data = data[skip:]
    return data


def format_kickass(data: bytes, label: str, per_line: int) -> str:
    lines = [f'{label}:']
    for i in range(0, len(data), per_line):
        chunk = data[i:i + per_line]
        vals = ','.join(f'${b:02x}' for b in chunk)
        lines.append(f'.byte {vals}')
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------------------
# Fallback: extract bytes from text when no directives found
# ---------------------------------------------------------------------------

def extract_bytes_fallback(text: str) -> bytes:
    """Last-resort byte extraction: C-style 0x.. then $xx anywhere."""
    collected: list[int] = []
    for m in _C_HEX_RE.finditer(text):
        v = int(m.group()[2:], 16)
        if 0 <= v <= 255:
            collected.append(v)
    if not collected:
        for m in re.finditer(r'\$([0-9a-fA-F]{2})', text):
            collected.append(int(m.group(1), 16))
    return bytes(collected)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

BINARY_EXTENSIONS = {'.bin', '.raw', '.prg', '.seq', '.p00', '.rom'}


def main() -> None:
    ap = argparse.ArgumentParser(
        description='Convert any assembler byte-data format to KickAssembler syntax.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input', help='Input file (binary or text assembler)')
    ap.add_argument('-o', '--output', help='Output file (default: stdout)')
    ap.add_argument('-l', '--label', default='',
                    help='ASM label for the data block (default: auto-detect or "data")')
    ap.add_argument('-n', '--per-line', type=int, default=16,
                    help='Bytes per .byte line for binary input (default: 16)')
    ap.add_argument('--skip', type=int, default=0, metavar='N',
                    help='Skip first N bytes of a binary file (e.g. 2 for PRG header)')
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        sys.exit(f'Error: file not found: {args.input}')

    is_binary = src.suffix.lower() in BINARY_EXTENSIONS

    if is_binary:
        if args.per_line < 1:
            sys.exit('Error: --per-line must be at least 1')
        data = load_binary(src, args.skip)
        label = args.label or 'data'
        output = format_kickass(data, label, args.per_line)
        byte_count = len(data)
    else:
        raw_text = src.read_text(encoding='utf-8', errors='replace')
        label = args.label  # may be empty; convert_text will auto-detect from source
        output, byte_count = convert_text(raw_text, label)

        if byte_count == 0:
            # No recognized directives — fall back to raw byte scan
            data = extract_bytes_fallback(raw_text)
            if not data:
                sys.exit(f'Error: no byte values found in {args.input}')
            label = args.label or 'data'
            if args.per_line < 1:
                sys.exit('Error: --per-line must be at least 1')
            output = format_kickass(data, label, args.per_line)
            byte_count = len(data)

    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        print(f'Wrote {byte_count} bytes to {args.output}')
    else:
        sys.stdout.write(output)


if __name__ == '__main__':
    main()
