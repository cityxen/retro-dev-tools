#!/usr/bin/env python3
"""
unkickit.py — Translate KickAssembler source to other assembler formats.

Supported output formats
------------------------
  acme     ACME cross-assembler  (!byte, !text, !src, !org, ; comments)
  dasm     DASM macro assembler  (dc.b, dc.w, include, org, EQU, ; comments)
  merlin   Merlin 32             (dfb, asc, put, org, EQU, * comments)
  ca65     ca65 / cc65 suite     (.byte, .word, .include, .org, = , ; comments)
  64tass   64tass                (.byte, .text, .include, *= , = , ; comments)

Constructs translated
---------------------
  .byte $xx,...          byte data directive
  .word $xxxx,...        word (2-byte) data directive
  .text "string"         string/text data
  .fill N, val           fill / reserve bytes
  * = $xxxx              set program counter (org)
  .org $xxxx             org (alternative KA syntax)
  .const NAME = val      named constant  → target constant syntax
  .var   name = val      named variable  → target constant syntax
  #import "file"         include file
  #importonce            commented out (no direct equivalent)
  .encoding "..."        tracked; affects .text output for ACME (!pet vs !text)
  label:                 global label
  !word:                 KickAssembler anonymous local label → renamed _word_N:
  !word- / !word+        anonymous label reference → resolved to _word_N

  // comment             → target comment character
  /* block comment */    → multiple target comment lines
  ; comment              → target comment character

  6502 instructions      passed through unchanged (mnemonics are universal)
  !name-/!name+ refs     resolved via two-pass label scan

KickAssembler-specific constructs that cannot be automatically converted
(.segment, .file, .namespace, .pseudopc, .macro, .function, .if/.else/.endif,
macro invocations) are emitted as commented lines prefixed with [KA] for
manual review.

Usage
-----
  python unkickit.py input.asm
  python unkickit.py input.asm -t acme   -o output.asm
  python unkickit.py input.asm -t dasm   -o output.asm
  python unkickit.py input.asm -t merlin -o output.s
  python unkickit.py input.asm -t ca65   -o output.s
  python unkickit.py input.asm -t 64tass -o output.asm
"""

import argparse
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Target format definitions
# ---------------------------------------------------------------------------

class _Fmt:
    def __init__(self, *, byte_kw, word_kw, text_kw, fill_tpl, org_kw,
                 include_kw, include_quoted, const_tpl, comment_char,
                 label_colon, local_prefix, local_colon, indent, desc, ext):
        self.byte_kw       = byte_kw        # '.byte' / '!byte' / 'dc.b' / 'dfb'
        self.word_kw       = word_kw        # '.word' / '!word' / 'dc.w' / 'dw'
        self.text_kw       = text_kw        # directive for ASCII text data
        self.fill_tpl      = fill_tpl       # '!fill {n},{v}' / 'ds.b {n},{v}' etc.
        self.org_kw        = org_kw         # 'org' / '!org' / '.org' / '*='
        self.include_kw    = include_kw     # '!src' / 'include' / '.include' / 'put'
        self.include_quoted = include_quoted # wrap filename in quotes
        self.const_tpl     = const_tpl      # '{name} = {value}' / '{name} EQU {value}'
        self.comment_char  = comment_char   # ';' / '*'
        self.label_colon   = label_colon    # labels end with ':'
        self.local_prefix  = local_prefix   # prefix for local labels: '@' / ':' / '_'
        self.local_colon   = local_colon    # local labels end with ':'
        self.indent        = indent         # indentation string for non-label lines
        self.desc          = desc
        self.ext           = ext

    # ---- helpers ----

    def comment_line(self, text: str) -> str:
        if self.comment_char == '*':
            return f'* {text}'.rstrip() if text else '*'
        return (f'{self.comment_char} {text}').rstrip() if text else self.comment_char

    def inline_comment(self, text: str) -> str:
        return f'  {self.comment_char} {text}'

    def label_str(self, name: str) -> str:
        return f'{name}:' if self.label_colon else name

    def local_label_str(self, name: str) -> str:
        colon = ':' if self.local_colon else ''
        return f'{self.local_prefix}{name}{colon}'

    def local_ref_str(self, name: str) -> str:
        return f'{self.local_prefix}{name}'

    def const_str(self, name: str, value: str) -> str:
        return self.const_tpl.format(name=name, value=value)

    def org_str(self, addr: str) -> str:
        if self.org_kw == '*=':
            return f'*= {addr}'
        return f'{self.indent}{self.org_kw} {addr}'

    def include_str(self, filename: str) -> str:
        fn = f'"{filename}"' if self.include_quoted else filename
        return f'{self.indent}{self.include_kw} {fn}'

    def text_str(self, string: str, petscii: bool = False) -> str:
        kw = self.text_kw
        if petscii and self.byte_kw == '!byte':  # ACME: !pet for PETSCII
            kw = '!pet'
        return f'{self.indent}{kw} "{string}"'

    def fill_str(self, n: str, v: str) -> str:
        return f'{self.indent}{self.fill_tpl.format(n=n, v=v)}'

    def byte_str(self, values: str, comment: str = '') -> str:
        line = f'{self.indent}{self.byte_kw} {values}'
        if comment:
            line += self.inline_comment(comment)
        return line

    def word_str(self, values: str, comment: str = '') -> str:
        line = f'{self.indent}{self.word_kw} {values}'
        if comment:
            line += self.inline_comment(comment)
        return line


FORMATS: dict[str, _Fmt] = {
    'acme': _Fmt(
        byte_kw='!byte', word_kw='!word', text_kw='!text',
        fill_tpl='!fill {n},{v}', org_kw='!org',
        include_kw='!src', include_quoted=True,
        const_tpl='{name} = {value}',
        comment_char=';', label_colon=True,
        local_prefix='@', local_colon=True,
        indent='    ',
        desc='ACME cross-assembler', ext='.asm',
    ),
    'dasm': _Fmt(
        byte_kw='dc.b', word_kw='dc.w', text_kw='dc.b',
        fill_tpl='ds.b {n},{v}', org_kw='org',
        include_kw='include', include_quoted=True,
        const_tpl='{name} EQU {value}',
        comment_char=';', label_colon=True,
        local_prefix='.', local_colon=True,
        indent='        ',
        desc='DASM macro assembler', ext='.asm',
    ),
    'merlin': _Fmt(
        byte_kw='dfb', word_kw='dw', text_kw='asc',
        fill_tpl='ds {n}', org_kw='org',
        include_kw='put', include_quoted=False,
        const_tpl='{name} EQU {value}',
        comment_char='*', label_colon=False,
        local_prefix=':', local_colon=False,
        indent=' ',
        desc='Merlin 32 assembler', ext='.s',
    ),
    'ca65': _Fmt(
        byte_kw='.byte', word_kw='.word', text_kw='.byte',
        fill_tpl='.res {n},{v}', org_kw='.org',
        include_kw='.include', include_quoted=True,
        const_tpl='{name} = {value}',
        comment_char=';', label_colon=True,
        local_prefix='@', local_colon=True,
        indent='    ',
        desc='ca65 assembler (cc65 suite)', ext='.s',
    ),
    '64tass': _Fmt(
        byte_kw='.byte', word_kw='.word', text_kw='.text',
        fill_tpl='.fill {n},{v}', org_kw='*=',
        include_kw='.include', include_quoted=True,
        const_tpl='{name} = {value}',
        comment_char=';', label_colon=True,
        local_prefix='_', local_colon=True,
        indent='    ',
        desc='64tass cross-assembler', ext='.asm',
    ),
}


# ---------------------------------------------------------------------------
# KickAssembler regex patterns
# ---------------------------------------------------------------------------

_RE_COMMENT_FULL  = re.compile(r'^//\s*(.*)')
_RE_COMMENT_SEMI  = re.compile(r'^;\s*(.*)')
_RE_IMPORTONCE    = re.compile(r'^#importonce\b', re.I)
_RE_IMPORT        = re.compile(r'^#import\s+"([^"]+)"', re.I)
_RE_ENCODING      = re.compile(r'^\.encoding\s+"([^"]+)"', re.I)
_RE_ORG_STAR      = re.compile(r'^\*\s*=\s*(.+)')
_RE_ORG_DOT       = re.compile(r'^\.org\s+(.+)', re.I)
_RE_CONST         = re.compile(r'^\.(?:const|var)\s+(\w+)\s*=\s*(.+)', re.I)
_RE_BYTE          = re.compile(r'^\.byte\s+(.+)', re.I)
_RE_WORD          = re.compile(r'^\.word\s+(.+)', re.I)
_RE_TEXT          = re.compile(r'^\.text\s+"((?:[^"\\]|\\.)*)"', re.I)
_RE_FILL          = re.compile(r'^\.fill\s+(.+?)\s*,\s*(.+)', re.I)
_RE_LABEL         = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$')
_RE_LABEL_INLINE  = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s+(.+)')
_RE_ANON_DEF      = re.compile(r'^!([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$')
_RE_ANON_REF      = re.compile(r'!([A-Za-z_][A-Za-z0-9_]*)([+-])')
_RE_KA_BLOCK      = re.compile(
    r'^\.(?:segment|file|namespace|pseudopc|macro|function|if|else|endif|for|while|return|define)\b',
    re.I,
)
_RE_BLOCK_CMT     = re.compile(r'/\*.*?\*/', re.DOTALL)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _split_comment(text: str) -> tuple[str, str]:
    """Split 'code // comment' or 'code ; comment' respecting string literals."""
    in_str = False
    i = 0
    while i < len(text):
        c = text[i]
        if c == '"':
            in_str = not in_str
        elif not in_str:
            if text[i:i+2] == '//':
                return text[:i].rstrip(), text[i+2:].strip()
            if c == ';':
                return text[:i].rstrip(), text[i+1:].strip()
        i += 1
    return text, ''


def _expand_block_comments(text: str) -> str:
    """Replace /* ... */ blocks with // comment lines."""
    def _replace(m: re.Match) -> str:
        inner = m.group(0)[2:-2]
        lines = []
        for ln in inner.splitlines():
            ln = ln.strip().lstrip('*').strip()
            lines.append(f'// {ln}' if ln else '//')
        return '\n'.join(lines)
    return _RE_BLOCK_CMT.sub(_replace, text)


# ---------------------------------------------------------------------------
# Two-pass anonymous label resolver
# ---------------------------------------------------------------------------

def _scan_anon_labels(lines: list[str]) -> tuple[dict, dict]:
    """
    Pass 1: find all !name: definitions.
    Returns:
      anon_defs   — {(line_idx, name): unique_label}
      name_lines  — {name: [line_idx, ...]} (sorted ascending)
    """
    anon_defs: dict[tuple[int, str], str] = {}
    name_lines: dict[str, list[int]] = {}
    for i, line in enumerate(lines):
        m = _RE_ANON_DEF.match(line.strip())
        if m:
            name = m.group(1)
            bucket = name_lines.setdefault(name, [])
            idx = len(bucket)
            anon_defs[(i, name)] = f'_{name}_{idx}'
            bucket.append(i)
    return anon_defs, name_lines


def _resolve_anon_ref(ref_line: int, name: str, direction: str,
                      name_lines: dict) -> str:
    """Return the unique label for !name- (prev) or !name+ (next)."""
    positions = name_lines.get(name, [])
    if not positions:
        return f'_{name}_UNRESOLVED'
    if direction == '-':
        candidates = [p for p in positions if p < ref_line]
        if not candidates:
            return f'_{name}_UNRESOLVED'
        idx = positions.index(max(candidates))
    else:
        candidates = [p for p in positions if p > ref_line]
        if not candidates:
            return f'_{name}_UNRESOLVED'
        idx = positions.index(min(candidates))
    return f'_{name}_{idx}'


# ---------------------------------------------------------------------------
# Line converter
# ---------------------------------------------------------------------------

def _convert_line(line_idx: int, line: str, fmt: _Fmt,
                  anon_defs: dict, name_lines: dict,
                  encoding_state: list) -> str:
    """
    Convert one stripped KickAssembler line to the target format.
    encoding_state is a 1-element list so the inner call can mutate it.
    Returns '' for blank lines, or the converted string (no trailing newline).
    """
    stripped = line.strip()
    if not stripped:
        return ''

    # --- full-line comments ---
    m = _RE_COMMENT_FULL.match(stripped)
    if m:
        return fmt.comment_line(m.group(1))

    m = _RE_COMMENT_SEMI.match(stripped)
    if m:
        return fmt.comment_line(m.group(1))

    # --- #importonce ---
    if _RE_IMPORTONCE.match(stripped):
        return fmt.comment_line('[KA] #importonce — add an include guard manually if needed')

    # --- #import "file" ---
    m = _RE_IMPORT.match(stripped)
    if m:
        return fmt.include_str(m.group(1))

    # --- .encoding "..." ---
    m = _RE_ENCODING.match(stripped)
    if m:
        enc = m.group(1)
        encoding_state[0] = enc
        return fmt.comment_line(f'.encoding "{enc}"')

    # --- !name: anonymous label definition ---
    m = _RE_ANON_DEF.match(stripped)
    if m:
        name = m.group(1)
        unique = anon_defs.get((line_idx, name), f'_{name}_0')
        return fmt.local_label_str(unique)

    # --- label: (alone on line) ---
    m = _RE_LABEL.match(stripped)
    if m:
        return fmt.label_str(m.group(1))

    # --- * = addr or .org addr ---
    m = _RE_ORG_STAR.match(stripped) or _RE_ORG_DOT.match(stripped)
    if m:
        addr, cmt = _split_comment(m.group(1).strip())
        result = fmt.org_str(addr.strip())
        if cmt:
            result += fmt.inline_comment(cmt)
        return result

    # --- .const / .var ---
    m = _RE_CONST.match(stripped)
    if m:
        name = m.group(1)
        value, cmt = _split_comment(m.group(2).strip())
        result = fmt.const_str(name, value.strip())
        if cmt:
            result += fmt.inline_comment(cmt)
        return result

    # --- .fill N, val ---
    m = _RE_FILL.match(stripped)
    if m:
        n_part = m.group(1).strip()
        v_part, cmt = _split_comment(m.group(2).strip())
        # .fill with i: expr (loop expression) can't be translated — warn
        if ':' in v_part:
            result = fmt.comment_line(f'[KA] .fill {n_part}, {v_part} — translate manually')
            if cmt:
                result += fmt.inline_comment(cmt)
            return result
        result = fmt.fill_str(n_part, v_part.strip())
        if cmt:
            result += fmt.inline_comment(cmt)
        return result

    # --- .text "string" ---
    m = _RE_TEXT.match(stripped)
    if m:
        petscii = 'petscii' in encoding_state[0].lower()
        return fmt.text_str(m.group(1), petscii=petscii)

    # --- .byte values ---
    m = _RE_BYTE.match(stripped)
    if m:
        values, cmt = _split_comment(m.group(1).strip())
        return fmt.byte_str(values.strip(), cmt)

    # --- .word values ---
    m = _RE_WORD.match(stripped)
    if m:
        values, cmt = _split_comment(m.group(1).strip())
        return fmt.word_str(values.strip(), cmt)

    # --- label: code (inline) ---
    m = _RE_LABEL_INLINE.match(stripped)
    if m:
        label_out = fmt.label_str(m.group(1))
        rest_out  = _convert_line(line_idx, m.group(2), fmt, anon_defs,
                                  name_lines, encoding_state)
        # Emit label on its own line, code on the next
        return f'{label_out}\n{rest_out}'

    # --- KickAssembler-specific block directives ---
    if _RE_KA_BLOCK.match(stripped):
        return fmt.comment_line(f'[KA] {stripped}')

    # --- Everything else: 6502 instructions, expressions, macro calls ---
    # Resolve !name-/!name+ references, then convert comment style.
    def _subst_anon(mo: re.Match) -> str:
        unique = _resolve_anon_ref(line_idx, mo.group(1), mo.group(2), name_lines)
        return fmt.local_ref_str(unique)

    result = _RE_ANON_REF.sub(_subst_anon, stripped)
    code, cmt = _split_comment(result)
    code = code.rstrip()

    # Heuristic: if this looks like a macro call (UpperCase followed by '('),
    # it can't be translated — annotate it.
    if re.match(r'^[A-Z][A-Za-z0-9_]*\s*\(', code) or re.match(r'^[A-Z][A-Za-z0-9_]*\s+\S', code):
        out = fmt.comment_line(f'[KA macro] {code}')
        if cmt:
            out += fmt.inline_comment(cmt)
        return out

    out = f'{fmt.indent}{code}' if code else ''
    if cmt:
        out += fmt.inline_comment(cmt)
    return out


# ---------------------------------------------------------------------------
# File-level conversion
# ---------------------------------------------------------------------------

def convert(text: str, fmt: _Fmt) -> str:
    """Convert a full KickAssembler source text to the target format."""
    # Pre-process block comments
    text = _expand_block_comments(text)

    lines = text.splitlines()

    # Pass 1: scan anonymous labels
    anon_defs, name_lines = _scan_anon_labels(lines)

    # Pass 2: convert line by line
    encoding_state = ['ascii']
    out_lines: list[str] = []
    for i, line in enumerate(lines):
        converted = _convert_line(i, line, fmt, anon_defs, name_lines, encoding_state)
        # converted may itself contain \n (label+code split)
        out_lines.extend(converted.split('\n'))

    return '\n'.join(out_lines).rstrip() + '\n'


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description='Translate KickAssembler source to another assembler format.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input', nargs='?', help='KickAssembler source file (.asm / .s / .ka)')
    ap.add_argument('-t', '--target', default='acme',
                    choices=sorted(FORMATS),
                    help='Output format (default: acme)')
    ap.add_argument('-o', '--output', help='Output file (default: stdout)')
    ap.add_argument('--list-formats', action='store_true',
                    help='List available target formats and exit')
    args = ap.parse_args()

    if args.list_formats:
        for key, fmt in sorted(FORMATS.items()):
            print(f'  {key:<10} {fmt.desc}  (ext: {fmt.ext})')
        return

    if not args.input:
        ap.error('input file is required')

    src = Path(args.input)
    if not src.exists():
        sys.exit(f'Error: file not found: {args.input}')

    fmt = FORMATS[args.target]
    text = src.read_text(encoding='utf-8', errors='replace')
    output = convert(text, fmt)

    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        print(f'Converted {src.name} to {args.output}  ({args.target}: {fmt.desc})')
    else:
        sys.stdout.buffer.write(output.encode('utf-8', errors='replace'))


if __name__ == '__main__':
    main()
