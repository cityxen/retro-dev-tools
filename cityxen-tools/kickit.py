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
  Prog8 (.p8) — full structural translation:
    %asm {{ }}            raw 6502 assembly extracted and passed through
    sub / asmsub          → KickAssembler label + body + rts
    ubyte[] name = [...]  → label: .byte
    uword[] name = [...]  → label: .word
    ubyte[N] name         → label: .fill N,0
    ubyte name = val      → label: .byte val
    const ubyte NAME = v  → .const NAME = v
    DASM anon labels - +  → !_bwd: / !_fwd:
    high-level statements → // [Prog8] ... for manual review
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
  python kickit.py sprites.p8 -o sprites.asm
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
    r'(?<![A-Za-z0-9_$])(\.byte|!byte|dc\.b|\.db|db|dfb|defb|fcb|hex)(?![A-Za-z0-9_])',
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

# 6502 mnemonics — used to tell "label opcode" apart from a bare instruction.
_MNEMONICS = frozenset(
    'lda ldx ldy sta stx sty adc sbc and ora eor asl lsr rol ror inc dec '
    'inx iny dex dey cmp cpx cpy bcc bcs beq bne bmi bpl bvc bvs jmp jsr '
    'rts rti brk nop clc sec cld sed cli sei clv tax tay txa tya tsx txs '
    'pha pla php plp bit'.split()
)

# Shift/rotate ops whose accumulator form takes no operand in KickAssembler
_ACCU_MNEMONICS = frozenset({'asl', 'lsr', 'rol', 'ror'})

# Constant definitions:  NAME = value  |  NAME EQU value  |  NAME .equ value
_CONST_EQ_RE  = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$')
_CONST_EQU_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s+\.?equ\s+(.+)$', re.IGNORECASE)

# Label followed by an instruction on the same line:  NAME opcode ...
_LABEL_INSTR_RE = re.compile(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z]{3})(?![A-Za-z0-9_])(.*)$')

# Label followed by an assembler directive on the same line:  NAME .text ...
_LABEL_DIRECTIVE_RE = re.compile(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s+(\.[A-Za-z]\w*\b.*)$')

# Anonymous label definition (64tass/DASM):  - / + / -- / ++  (optionally + code)
_ANON_LABEL_RE = re.compile(r'^(-+|\++)(?:\s+(.*))?$')

# An operand that is a bare run of - or + (anonymous label reference)
_ANON_OPERAND_RE = re.compile(r'-+|\++')

_BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.DOTALL)

# ---------------------------------------------------------------------------
# Prog8 patterns (.p8 source files)
# ---------------------------------------------------------------------------

# ubyte[] [@attr ...] name = [  or  uword[] name = [
_P8_ARRAY_START = re.compile(
    r'^(u?byte|u?word|bool)\s*\[\s*\]\s*(?:@\w+\s*)*(\w+)\s*=\s*\[(.*)$',
    re.IGNORECASE,
)

# const ubyte/uword/byte/word NAME = value
_P8_CONST = re.compile(
    r'^const\s+(u?byte|u?word)\s+(\w+)\s*=\s*(.+)',
    re.IGNORECASE,
)

# .byte or .char directive inside %asm blocks
_P8_BYTE_DIR = re.compile(r'\.(?:byte|char)\s+(.+)', re.IGNORECASE)

# Matches only comma-separated plain numeric literals (hex/binary/decimal) — no expressions.
_P8_SIMPLE_LIST = re.compile(
    r'^[\s,]*'
    r'(?:(?:\$[0-9a-fA-F]+|%[01]+|0[xX][0-9a-fA-F]+|[0-9a-fA-F]+[hH]|\d+)'
    r'[\s,]*)*$'
)

# %asm {{ block opener
_P8_ASM_OPEN = re.compile(r'%asm\s*\{\{')

# sub / asmsub declaration start
_P8_SUB = re.compile(r'^(?:inline\s+)?(?:asmsub|sub)\s+(\w+)\s*[\(\{]')


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


_TEXT_DIR_RE = re.compile(r"^\s*\.(?:text|char)\b", re.IGNORECASE)


def _split_directive_comment(arg: str) -> tuple[str, str]:
    """Split a trailing ; or // comment (outside any quoted string) off arg."""
    in_q = None
    cut = len(arg)
    for i, c in enumerate(arg):
        if in_q:
            if c == in_q:
                in_q = None
        elif c in "'\"":
            in_q = c
        elif c == ';' or arg[i:i + 2] == '//':
            cut = i
            break
    return arg[:cut].rstrip(), arg[cut:].lstrip(';/ ').rstrip()


def _split_top_commas(arg: str) -> list[str]:
    """Split a comma list into items, ignoring commas inside quoted strings."""
    items, cur, in_q = [], '', None
    for c in arg:
        if in_q:
            cur += c
            if c == in_q:
                in_q = None
        elif c in "'\"":
            in_q = c
            cur += c
        elif c == ',':
            items.append(cur)
            cur = ''
        else:
            cur += c
    items.append(cur)
    return items


def _is_instruction(stripped: str) -> bool:
    """True if the line begins with a 6502 mnemonic."""
    head = stripped.split(None, 1)
    return bool(head) and head[0].lower() in _MNEMONICS


def _format_instruction(stripped: str) -> str:
    """Indent an instruction 4 spaces, convert a -/+ anonymous-label operand to
    KickAssembler !-/!+ form, and convert a trailing ; comment to //."""
    body, comment = split_inline_comment(stripped)
    body = body.rstrip()
    parts = body.split(None, 1)
    if len(parts) == 2:
        mnem, operand = parts[0], parts[1].strip()
        if _ANON_OPERAND_RE.fullmatch(operand):
            body = f'{mnem} !{operand}'
        elif mnem.lower() in _ACCU_MNEMONICS and operand.lower() == 'a':
            body = mnem            # KickAssembler accumulator mode takes no operand
    line = '    ' + body
    if comment:
        line += f'  // {comment}'
    return line


def convert_text_directive(line: str) -> list[str]:
    """Translate a (64tass-style) .text/.char line to KickAssembler line(s).

    The argument list may mix numeric byte values and quoted strings, e.g.
        .text 13,13,5,'new pUNTER ',00
    which KickAssembler can't express in one .text, so it is split:
        .byte 13,13,5
        .text "new pUNTER "
        .byte 0
    Consecutive numeric values collapse into one .byte (kept in decimal); each
    quoted string becomes its own .text with double quotes. An embedded " can't
    be escaped in KickAssembler, so the string is split around it and the quote
    emitted as .byte '"'. Returns the resulting line(s), without a leading label."""
    m = re.match(r"^\s*\.(?:text|char)\s+(.*)$", line, re.IGNORECASE)
    if not m:
        return [line]
    arg, comment = _split_directive_comment(m.group(1))

    out: list[str] = []
    byte_run: list[str] = []

    def flush() -> None:
        if byte_run:
            out.append(f'.byte {",".join(byte_run)}')
            byte_run.clear()

    for item in _split_top_commas(arg):
        s = item.strip()
        if not s:
            continue
        if s[0] in "'\"":
            flush()
            quote = s[0]
            inner = s[1:-1] if len(s) >= 2 and s[-1] == quote else s[1:]
            # KickAssembler .text needs double quotes and can't escape an embedded
            # ", so split the string around each " and emit it as its own .byte.
            segments = inner.split('"')
            for j, seg in enumerate(segments):
                if seg:
                    out.append(f'.text "{seg}"')
                if j < len(segments) - 1:
                    out.append('.byte \'"\'')
        else:
            v = parse_number(s)
            if v is not None:
                byte_run.append(str(v))
            else:                       # unknown expression — keep verbatim
                flush()
                out.append(f'.byte {s}')
    flush()

    if comment:
        if out:
            out[-1] += f'  // {comment}'
        else:
            out.append(f'// {comment}')
    return out or [line]


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

        # KickAssembler has no .end directive — comment it out
        if re.match(r'^\.end\b', stripped, re.IGNORECASE):
            out_lines.append(to_kickass_comment(stripped))
            continue

        # Anonymous label definition (64tass - / + / -- / ++) → KickAssembler !:
        anon_m = _ANON_LABEL_RE.match(stripped)
        if anon_m:
            found_label = True
            out_lines.append('!:')
            tail = (anon_m.group(2) or '').strip()
            if tail:
                out_lines.append(_format_instruction(tail))
            continue

        # Label on its own line (but not a bare implied-mode instruction: rts, nop, clc, …)
        lm = _LABEL_RE.match(stripped)
        if lm and lm.group(1).lower() not in _MNEMONICS:
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

        # Constant definition: NAME = val | NAME EQU val | NAME .equ val
        cm = _CONST_EQ_RE.match(stripped) or _CONST_EQU_RE.match(stripped)
        if cm:
            value, comment = split_inline_comment(cm.group(2))
            line_out = f'.const {cm.group(1)} = {value.rstrip()}'
            if comment:
                line_out += f'  // {comment}'
            out_lines.append(line_out)
            continue

        # Label + instruction on one line: "NAME opcode ..." → label then code
        im = _LABEL_INSTR_RE.match(stripped)
        if im and im.group(1).lower() not in _MNEMONICS and im.group(2).lower() in _MNEMONICS:
            found_label = True
            out_lines.append(f'{im.group(1)}:')
            out_lines.append(_format_instruction((im.group(2) + im.group(3)).strip()))
            continue

        # Label + directive on one line: "NAME .text ..." → label then directive
        dlm = _LABEL_DIRECTIVE_RE.match(stripped)
        if dlm and dlm.group(1).lower() not in _MNEMONICS:
            found_label = True
            out_lines.append(f'{dlm.group(1)}:')
            rest = dlm.group(2).rstrip()
            if _TEXT_DIR_RE.match(rest):
                out_lines.extend(convert_text_directive(rest))
                continue
            # Don't comment-split a quoted string (e.g. .text 'a;b'); convert comments otherwise.
            if "'" not in rest and '"' not in rest:
                data_part, comment = split_inline_comment(rest)
                rest = data_part.rstrip() + (f'  // {comment}' if comment else '')
            out_lines.append(rest)
            continue

        # Standalone .text / .char directive — convert quotes, keep string intact
        if _TEXT_DIR_RE.match(stripped):
            out_lines.extend(convert_text_directive(stripped.rstrip()))
            continue

        # Other lines (org, etc.) — pass through with comment conversion
        data_part, comment = split_inline_comment(stripped)
        data_part = data_part.rstrip()
        # Bare identifier with only a trailing comment → label
        if comment and _LABEL_RE.match(data_part) and data_part.rstrip(':').lower() not in _MNEMONICS:
            found_label = True
            out_lines.append(f'{data_part.rstrip(":")}:  // {comment}')
            continue
        # Instruction line → indent 4 spaces, convert -/+ anonymous-label operands
        if _is_instruction(data_part):
            out_lines.append(_format_instruction(stripped))
            continue
        line_out = data_part
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


def read_source_text(path: Path) -> str:
    """Read a text source, honoring a UTF-16/UTF-8 BOM instead of assuming UTF-8.

    Reading a UTF-16 file as UTF-8 leaves a NUL byte after every character and
    turns the BOM into replacement chars, which then pass straight through into
    the output and make the assembler reject every line."""
    raw = path.read_bytes()
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16')            # UTF-16 LE/BE with BOM
    if raw[:3] == b'\xef\xbb\xbf':
        return raw.decode('utf-8-sig')         # strip UTF-8 BOM
    # No BOM but heavy NULs → UTF-16 without a BOM
    if raw.count(b'\x00') > len(raw) // 4:
        return raw.decode('utf-16-le', errors='replace')
    return raw.decode('utf-8', errors='replace')


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
# Prog8 (.p8) full-file translation
# ---------------------------------------------------------------------------

def convert_prog8(text: str, default_label: str, per_line: int = 16) -> tuple[str, int]:
    """Translate a Prog8 (.p8) source file to KickAssembler.

    Translation rules
    -----------------
    %asm {{ ... }}      raw 6502 assembly extracted and passed through
    sub / asmsub        → label: + body + rts
    ubyte[] name = [...] → name: .byte  (source-line layout preserved)
    uword[] name = [...] → name: .word
    ubyte[N] name        → name: .fill N,0
    ubyte name = val     → name: .byte val
    const ubyte/uword    → .const
    %import lib          → // TODO: #import "lib.asm"
    %address $xxxx       → * = $xxxx
    Named blocks         → // ---- name ---- section header
    DASM anon labels - + → !_bwd: / !_fwd:  (KickAssembler anonymous labels)
    .byte complex_expr   → // [complex expr — translate manually]
    High-level stmts     → // [Prog8] ...  for manual review
    """
    lines = text.splitlines()
    total = len(lines)
    out: list[str] = []
    idx = [0]    # mutable parse position (list so nested fns can mutate)
    bc  = [0]    # mutable byte counter

    # ---- core helpers -------------------------------------------------------

    def take() -> str:
        if idx[0] < total:
            line = lines[idx[0]].strip()
            idx[0] += 1
            return line
        return ''

    def emit(line: str = '') -> None:
        out.append(line)

    def emit_cmt(text: str) -> None:
        emit((f'// {text}').rstrip() if text else '//')

    # ---- anonymous label conversion (DASM → KickAssembler) -----------------

    def conv_anon(line: str) -> str:
        if line == '-':
            return '!_bwd:'
        if line == '+':
            return '!_fwd:'
        # "+  instruction" or "-  instruction" — label + code on same line
        m = re.match(r'^-\s+(.+)', line)
        if m:
            return f'!_bwd: {m.group(1)}'
        m = re.match(r'^\+\s+(.+)', line)
        if m:
            return f'!_fwd: {m.group(1)}'
        # bne - / bcs + style branch references
        line = re.sub(r'\b(b(?:ne|eq|cs|cc|pl|mi|vs|vc))\s+-$', r'\1 !_bwd-', line)
        line = re.sub(r'\b(b(?:ne|eq|cs|cc|pl|mi|vs|vc))\s+\+$', r'\1 !_fwd+', line)
        return line

    # ---- %asm block emission ------------------------------------------------

    def emit_asm_line(line: str) -> None:
        """Emit one raw assembly line from inside a %asm block."""
        if not line:
            emit('')
            return
        if line.startswith(';') or line.startswith('//'):
            emit_cmt(line.lstrip(';/').strip())
            return
        line = conv_anon(line)
        # .byte / .char: pass simple literals, comment complex expressions
        m = _P8_BYTE_DIR.search(line)
        if m:
            rest, cmt = split_inline_comment(m.group(1))
            if _P8_SIMPLE_LIST.match(rest):
                converted = bytes_to_kickass(rest)
                if converted:
                    bc[0] += converted.count(',') + 1
                    lo = f'    .byte {converted}'
                    if cmt:
                        lo += f'  // {cmt}'
                    emit(lo)
                    return
            emit_cmt(f'.byte {rest.strip()}  [complex expr — translate manually]')
            return
        # Labels go at column 0.
        # In DASM/Prog8 %asm blocks, local labels start with '_'.
        # Also accept any identifier that already has an explicit ':'.
        if (re.match(r'^_[A-Za-z0-9_]*:?\s*$', line) or
                re.match(r'^[A-Za-z_][A-Za-z0-9_]+:\s*$', line)):
            label = line.rstrip().rstrip(':') + ':'
            emit(label)
            return
        # !_bwd: or !_fwd: with code → label at col 0 then indented code
        m = re.match(r'^(!_\w+:)\s+(.+)', line)
        if m:
            emit(m.group(1))
            emit(f'    {m.group(2)}')
            return
        emit(f'    {line}')

    def parse_asm_block(after_open: str) -> None:
        """Consume lines until '}}' and emit each as raw assembly."""
        content = after_open
        while True:
            if '}}' in content:
                before = content[:content.index('}}')].strip()
                if before:
                    emit_asm_line(before)
                break
            emit_asm_line(content)
            if idx[0] >= total:
                break
            content = take()

    # ---- data declarations --------------------------------------------------

    def parse_array(m: re.Match) -> None:
        """ubyte[] / uword[] name = [...] → label: .byte/.word lines."""
        is_word   = m.group(1).lower() in ('uword', 'word')
        name      = m.group(2)
        rest      = m.group(3)
        directive = '.word' if is_word else '.byte'
        bpv       = 2 if is_word else 1
        emit(f'{name}:')
        parts: list[tuple[str, str]] = []
        while True:
            if ']' in rest:
                rest = rest[:rest.index(']')]
                d, c = split_inline_comment(rest.strip().rstrip(','))
                parts.append((d, c))
                break
            d, c = split_inline_comment(rest.strip().rstrip(','))
            parts.append((d, c))
            if idx[0] >= total:
                break
            rest = take()
        for d, c in parts:
            if not d:
                if c:
                    emit_cmt(c)
                continue
            converted = bytes_to_kickass(d)
            if converted is not None:
                bc[0] += (converted.count(',') + 1) * bpv
                lo = f'    {directive} {converted}'
                if c:
                    lo += f'  // {c}'
                emit(lo)
            elif c:
                emit_cmt(c)

    def parse_const(stripped: str) -> None:
        m = _P8_CONST.match(stripped)
        if not m:
            return
        name = m.group(2)
        val, cmt = split_inline_comment(m.group(3).strip().rstrip(';'))
        lo = f'.const {name} = {val.strip()}'
        if cmt:
            lo += f'  // {cmt}'
        emit(lo)

    def parse_var(stripped: str) -> None:
        """Single-value variable: ubyte/uword/bool name [= val]."""
        m = re.match(
            r'^(?:u?byte|u?word|bool|float)\s+(?:@\w+\s+)*(\w+)\s*(?:=\s*(.+))?$',
            stripped, re.I,
        )
        if not m:
            emit_cmt(f'[Prog8] {stripped}')
            return
        name      = m.group(1)
        val_expr  = (m.group(2) or '').strip().rstrip(';')
        is_word   = stripped.lower().startswith(('uword', 'word', 'float'))
        directive = '.word' if is_word else '.byte'
        if val_expr:
            val, cmt = split_inline_comment(val_expr)
            val = val.strip()
            if val.lower() == 'false': val = '0'
            if val.lower() == 'true':  val = '1'
            lo = f'{name}: {directive} {val}'
            if cmt:
                lo += f'  // {cmt}'
        else:
            lo = f'{name}: {directive} 0'
        emit(lo)

    def parse_fixed_array(stripped: str) -> None:
        """ubyte[N] name  →  name: .fill N,0."""
        m = re.match(
            r'^(?:u?byte|u?word|bool)\s*\[(\w+)\]\s*(?:@\w+\s*)*(\w+)\s*(?:=\s*(.+))?$',
            stripped, re.I,
        )
        if not m:
            emit_cmt(f'[Prog8] {stripped}')
            return
        size     = m.group(1)
        name     = m.group(2)
        val_expr = (m.group(3) or '0').strip().rstrip(';')
        is_word  = stripped.lower().startswith(('uword', 'word'))
        emit(f'{name}:')
        if is_word:
            emit(f'    .fill {size}*2, 0  // uword[{size}]')
        else:
            val, _ = split_inline_comment(val_expr)
            emit(f'    .fill {size}, {val.strip()}')

    # ---- block body parser --------------------------------------------------

    def parse_block_body(depth_in: int = 1) -> None:
        """Parse inside { ... }, translating data, subs, asm, and stmts."""
        depth = depth_in
        while idx[0] < total and depth > 0:
            stripped = take()
            if not stripped:
                emit('')
                continue
            if stripped.startswith(';'):
                emit_cmt(stripped[1:].strip())
                continue
            # %asm {{ ... }}
            if _P8_ASM_OPEN.search(stripped):
                after = _P8_ASM_OPEN.sub('', stripped).strip()
                parse_asm_block(after)
                continue
            # const
            if _P8_CONST.match(stripped):
                parse_const(stripped)
                continue
            # ubyte[] / uword[] with initializer list
            am = _P8_ARRAY_START.match(stripped)
            if am:
                parse_array(am)
                continue
            # ubyte[N] fixed-size storage
            if re.match(r'^(?:u?byte|u?word|bool)\s*\[\w+\]', stripped, re.I):
                parse_fixed_array(stripped)
                continue
            # nested sub / asmsub
            sm = _P8_SUB.match(stripped)
            if sm:
                parse_sub(sm.group(1), stripped)
                continue
            # Brace depth accounting (strip {{ }} so %asm delimiters don't count)
            clean  = stripped.replace('{{', '').replace('}}', '')
            opens  = clean.count('{')
            closes = clean.count('}')
            depth += opens - closes
            if depth <= 0:
                break
            if stripped in ('{', '}'):
                continue
            # Single-variable declaration
            if re.match(r'^(?:u?byte|u?word|bool|float)\s+(?:@\w+\s+)*\w+\s*(?:=|$)', stripped, re.I):
                parse_var(stripped)
                continue
            # High-level Prog8 statement → comment for manual review
            emit_cmt(f'[Prog8] {stripped}')

    # ---- sub / asmsub -------------------------------------------------------

    def parse_sub(name: str, header: str) -> None:
        """Translate sub or asmsub to KickAssembler label + body + rts."""
        emit('')
        emit(f'{name}:')
        # Count net opening braces on header (ignoring {{ and }})
        clean = header.replace('{{', '').replace('}}', '')
        depth = clean.count('{') - clean.count('}')
        # If header didn't open the brace, find it on subsequent lines
        while depth <= 0 and idx[0] < total:
            line  = take()
            clean = line.replace('{{', '').replace('}}', '')
            depth += clean.count('{') - clean.count('}')
        parse_block_body(depth_in=depth)
        # Append rts unless the body already ends with one
        last = next((l.strip() for l in reversed(out) if l.strip()), '')
        if last not in ('rts', 'rti') and not last.startswith('jmp '):
            emit('    rts')

    # ---- top-level parsing loop ---------------------------------------------

    while idx[0] < total:
        stripped = take()

        if not stripped:
            emit('')
            continue

        if stripped.startswith(';'):
            emit_cmt(stripped[1:].strip())
            continue

        # %import lib  →  suggest #import
        m = re.match(r'^%import\s+(\S+)', stripped)
        if m:
            emit_cmt(f'TODO: #import "{m.group(1)}.asm"')
            continue

        # %address $xxxx  →  org
        m = re.match(r'^%address\s+(\S+)', stripped, re.I)
        if m:
            emit(f'* = {m.group(1)}')
            continue

        # Other % meta-directives
        if stripped.startswith('%') and not _P8_ASM_OPEN.match(stripped):
            emit_cmt(stripped)
            continue

        # Top-level const
        if _P8_CONST.match(stripped):
            parse_const(stripped)
            continue

        # Top-level ubyte[] / uword[] array
        am = _P8_ARRAY_START.match(stripped)
        if am:
            parse_array(am)
            continue

        # Named block:  name {
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\{$', stripped)
        if m:
            emit('')
            emit(f'// ---- {m.group(1)} ----')
            parse_block_body(depth_in=1)
            emit('')
            continue

        # Top-level sub / asmsub
        sm = _P8_SUB.match(stripped)
        if sm:
            parse_sub(sm.group(1), stripped)
            continue

        # Top-level %asm {{ }}
        if _P8_ASM_OPEN.search(stripped):
            after = _P8_ASM_OPEN.sub('', stripped).strip()
            parse_asm_block(after)
            continue

        # Everything else at top level
        emit_cmt(f'[Prog8] {stripped}')

    return '\n'.join(out).rstrip() + '\n', bc[0]


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

    ext = src.suffix.lower()
    is_binary = ext in BINARY_EXTENSIONS
    is_prog8  = ext == '.p8'

    if is_prog8:
        raw_text = read_source_text(src)
        label = args.label or src.stem
        output, byte_count = convert_prog8(raw_text, label, args.per_line)
    elif is_binary:
        if args.per_line < 1:
            sys.exit('Error: --per-line must be at least 1')
        data = load_binary(src, args.skip)
        label = args.label or 'data'
        output = format_kickass(data, label, args.per_line)
        byte_count = len(data)
    else:
        raw_text = read_source_text(src)
        label = args.label  # may be empty; convert_text will auto-detect from source
        output, byte_count = convert_text(raw_text, label)

        # Only fall back to a raw byte scan when convert_text recognized no
        # structure at all (labels, directives, indented instructions). A file
        # full of labels/code/strings legitimately has byte_count == 0 and must
        # keep its converted output rather than being re-scanned as raw hex.
        structured = any(
            ln.endswith(':') or ln.startswith(('.', '!', '    '))
            for ln in output.splitlines()
        )
        if byte_count == 0 and not structured:
            # No recognized structure — fall back to raw byte scan
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
        sys.stdout.buffer.write(output.encode('utf-8', errors='replace'))


if __name__ == '__main__':
    main()
