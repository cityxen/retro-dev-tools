#!/usr/bin/env python3
"""
prog8tokick.py — Translate Prog8 (.p8) source to KickAssembler 6502 assembly.

Code generation patterns are derived directly from the Prog8 compiler source:
  codeGenCpu6502/src/prog8/codegen/cpu6502/
    AsmGen.kt               — repeat loops, repeat/return/call dispatch
    ForLoopsAsmGen.kt       — for loop patterns
    IfElseAsmGen.kt         — if/else (while is desugared to if+jump)
    AssignmentAsmGen.kt     — assignment, array access
    AugmentableAssignmentAsmGen.kt — ++/--, +=/-=, &=, etc.
    FunctionCallAsmGen.kt   — call convention (A/Y registers, then vars)

Constructs translated
---------------------
  const ubyte/uword NAME = v   → .const NAME = v
  ubyte[] name = [...]         → label: .byte ...
  uword[] name = [...]         → label: .word ...
  ubyte[N] name                → label: .fill N,0
  ubyte name = val             → name: .byte val
  uword name = val             → name: .word val
  x = literal                  → lda #v / sta x
  x = y                        → lda y / sta x
  x = y + v                    → lda y / clc / adc #v / sta x
  x = y - v / & / | / ^        → similar patterns
  x = arr[i]                   → ldy i / lda arr,y / sta x
  x = arr[N]                   → lda arr+N / sta x
  arr[i] = v                   → lda #v / ldy i / sta arr,y
  x++                          → inc x
  x--                          → dec x
  x += N                       → lda x / clc / adc #N / sta x
  x -= N                       → lda x / sec / sbc #N / sta x
  x &= N / |= N / ^= N         → lda x / and/ora/eor #N / sta x
  x <<= N                      → N × asl x
  x >>= N                      → N × lsr x
  if cond { } else { }         → condition branches + labels
  while cond { }               → desugared: _loop: cond-check / body / jmp _loop
  for i in S to E { }          → init + cmp + inc/dec loop
  for i in S downto E { }      → init + cmp + dec loop
  repeat N { }                 → lda #N / sta _cnt / loop: body / dec / bne
  repeat { }                   → _loop: body / jmp _loop
  return                       → rts
  return x                     → lda x / rts
  foo()                        → jsr foo
  foo(a)                       → lda a / jsr foo
  foo(a, b)                    → lda a / ldy b / jsr foo
  void foo(...)                → same (discard return value)
  sub name() { }               → name: / body / rts
  asmsub name() { %asm {{ }} } → name: / raw asm / rts
  %asm {{ ... }}               → raw asm passthrough
  DASM anon labels - / +       → !_bwd: / !_fwd:

Usage
-----
  python prog8tokick.py input.p8
  python prog8tokick.py input.p8 -o output.asm
"""

import argparse
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

_P8_ARRAY_START = re.compile(
    r'^(u?byte|u?word|bool)\s*\[\s*\]\s*(?:@\w+\s*)*(\w+)\s*=\s*\[(.*)$', re.I)
_P8_FIXARR      = re.compile(
    r'^(u?byte|u?word|bool)\s*\[(\w+)\]\s*(?:@\w+\s*)*(\w+)\s*(?:=\s*(.+))?$', re.I)
_P8_CONST       = re.compile(r'^const\s+(u?byte|u?word)\s+(\w+)\s*=\s*(.+)', re.I)
_P8_VAR         = re.compile(
    r'^(?:@@)?(u?byte|u?word|bool|float)\s+(?:@\w+\s+)*(\w+)\s*(?:=\s*(.+))?$', re.I)
_P8_SUB         = re.compile(r'^(?:inline\s+)?(?:asmsub|sub)\s+(\w+)\s*[\(\{]')
_P8_ASM_OPEN    = re.compile(r'%asm\s*\{\{')
_P8_BYTE_DIR    = re.compile(r'\.(?:byte|char)\s+(.+)', re.I)
_P8_SIMPLE_LIST = re.compile(
    r'^[\s,]*(?:(?:\$[0-9a-fA-F]+|%[01]+|0[xX][0-9a-fA-F]+|\d+)[\s,]*)*$')

_FOR_RE   = re.compile(
    r'^for\s+(\w+)\s+in\s+(.+?)\s+(to|downto)\s+(.+?)(?:\s+step\s+(.+))?\s*$', re.I)
_WHILE_RE = re.compile(r'^while\s+(.+)$', re.I)
_REPEAT_RE = re.compile(r'^repeat(?:\s+(.+))?$', re.I)
_IF_RE    = re.compile(r'^if\s+(.+)$', re.I)
_ELSE_RE  = re.compile(r'^else(?:\s+if\s+(.+?))?(?:\s*\{)?\s*$', re.I)
_IMPORT_RE = re.compile(r'^%import\s+(\S+)', re.I)
_ADDR_RE  = re.compile(r'^%address\s+(\S+)', re.I)

# Augmented assignment: x += v, x |= v, etc.
_AUGMENT_RE = re.compile(
    r'^(\w+(?:\.\w+)?(?:\[\w+\])?)\s*(\+=|-=|&=|\|=|\^=|<<=|>>=)\s*(.+)$')
_INCR_RE = re.compile(r'^(\w+(?:\.\w+)?(?:\[\w+\])?)\+\+$')
_DECR_RE = re.compile(r'^(\w+(?:\.\w+)?(?:\[\w+\])?)\s*--$')
# Simple assignment: x = expr
_ASSIGN_RE = re.compile(r'^(\w+(?:\.\w+)?(?:\s*\[\s*\w+\s*\])?)\s*=\s*(.+)$')

# call: [void] name(args)
_CALL_RE = re.compile(r'^(?:void\s+,?\s*\w+\s*=\s*)?(?:void\s+)?(\w+(?:\.\w+)*)\s*\(([^)]*)\)$')


# ---------------------------------------------------------------------------
# Translator class
# ---------------------------------------------------------------------------

class Translator:
    def __init__(self):
        self.out: list[str]  = []
        self.types: dict[str, str] = {}   # name → 'byte' | 'word' | 'bool'
        self._n = 0            # unique label counter
        self.bc = 0            # byte count

    # ---- output helpers ----

    def L(self, label: str):           self.out.append(f'{label}:')
    def I(self, asm: str):             self.out.append(f'    {asm}')
    def C(self, text: str = ''):       self.out.append((f'// {text}').rstrip() if text else '//')
    def E(self):                       self.out.append('')
    def TODO(self, stmt: str):         self.out.append(f'    // [TODO] {stmt}')

    def fresh(self, hint: str = '') -> str:
        self._n += 1
        return f'_p8_{hint}_{self._n}' if hint else f'_p8_{self._n}'

    # ---- type registry ----

    def reg(self, name: str, typ: str):
        """Register a variable type. typ is 'byte', 'word', or 'bool'."""
        self.types[name] = typ

    def typeof(self, name: str) -> str:
        return self.types.get(name, 'byte')  # default byte; word only when explicitly declared

    # ---- number parsing ----

    def parse_int(self, s: str):
        s = s.strip()
        try:
            if s.startswith('$'):   return int(s[1:], 16)
            if s.lower().startswith('0x'): return int(s[2:], 16)
            if s.startswith('%'):   return int(s[1:], 2)
            return int(s)
        except (ValueError, IndexError):
            return None

    def fmt(self, n: int) -> str:
        if n == 0:   return '0'
        if n <= 255: return f'${n:02x}'
        return f'${n:04x}'

    # ---- load / store byte ----

    def _load_a(self, val: str):
        """Emit instructions to load a byte value into A."""
        val = val.strip().rstrip(';')
        n = self.parse_int(val)
        if n is not None:
            self.I(f'lda #{self.fmt(n)}')
            return
        if val.lower() == 'true':   self.I('lda #1');  return
        if val.lower() == 'false':  self.I('lda #0');  return
        # lsb(x) / msb(x)
        m = re.match(r'^lsb\((\w+(?:\.\w+)?)\)$', val, re.I)
        if m: self.I(f'lda {m.group(1)}');     return
        m = re.match(r'^msb\((\w+(?:\.\w+)?)\)$', val, re.I)
        if m: self.I(f'lda {m.group(1)}+1');   return
        # arr[N] constant index
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\d+)\]$', val)
        if m:  self.I(f'lda {m.group(1)}+{m.group(2)}'); return
        # arr[var] variable index
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\w+)\]$', val)
        if m:  self.I(f'ldy {m.group(2)}'); self.I(f'lda {m.group(1)},y'); return
        # plain variable or dotted name
        if re.match(r'^\w+(?:\.\w+)?$', val): self.I(f'lda {val}'); return
        self.TODO(f'load {val}')

    def _store_a(self, target: str):
        """Emit store-A into target (variable, array element)."""
        target = target.strip()
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\d+)\]$', target)
        if m:  self.I(f'sta {m.group(1)}+{m.group(2)}'); return
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\w+)\]$', target)
        if m:  self.I(f'ldy {m.group(2)}'); self.I(f'sta {m.group(1)},y'); return
        self.I(f'sta {target}')

    # ---- assignment ----

    def _assign(self, target: str, source: str):
        """Translate target = source."""
        source = source.strip().rstrip(';')
        target = target.strip()
        tgt_bare = re.split(r'\s*\[', target)[0].strip()
        tgt_type  = self.typeof(tgt_bare)
        tgt_is_arr = '[' in target

        src_n = self.parse_int(source)

        # Word constant to word variable
        if not tgt_is_arr and tgt_type == 'word' and src_n is not None:
            lo, hi = src_n & 0xFF, (src_n >> 8) & 0xFF
            self.I(f'lda #{self.fmt(lo)}')
            self.I(f'sta {target}')
            self.I(f'lda #{self.fmt(hi)}')
            self.I(f'sta {target}+1')
            return

        # Word variable to word variable
        if not tgt_is_arr and tgt_type == 'word' and re.match(r'^\w+(?:\.\w+)?$', source):
            src_type = self.typeof(source)
            self.I(f'lda {source}')
            self.I(f'sta {target}')
            if src_type == 'word':
                self.I(f'lda {source}+1')
                self.I(f'sta {target}+1')
            else:
                self.I(f'lda #0')
                self.I(f'sta {target}+1')
            return

        # Simple binary expressions: x op y or x op #N
        ops = [
            (r'^(\w+(?:\.\w+)?)\s*\+\s*(.+)$',  'clc', 'adc'),
            (r'^(\w+(?:\.\w+)?)\s*-\s*(.+)$',   'sec', 'sbc'),
            (r'^(\w+(?:\.\w+)?)\s*&\s*(.+)$',   '',    'and'),
            (r'^(\w+(?:\.\w+)?)\s*\|\s*(.+)$',  '',    'ora'),
            (r'^(\w+(?:\.\w+)?)\s*\^\s*(.+)$',  '',    'eor'),
        ]
        for pat, carry_op, alu_op in ops:
            m = re.match(pat, source)
            if m:
                lhs, rhs = m.group(1), m.group(2).strip()
                rhs_n = self.parse_int(rhs)
                self._load_a(lhs)
                if carry_op: self.I(carry_op)
                if rhs_n is not None: self.I(f'{alu_op} #{self.fmt(rhs_n)}')
                elif re.match(r'^\w+(?:\.\w+)?$', rhs): self.I(f'{alu_op} {rhs}')
                else: self.TODO(f'{alu_op} {rhs}')
                self._store_a(target)
                return

        # Shift right by N → lsr
        m = re.match(r'^(\w+(?:\.\w+)?)\s*>>\s*(\d+)$', source)
        if m:
            self._load_a(m.group(1))
            for _ in range(int(m.group(2))):  self.I('lsr a')
            self._store_a(target)
            return

        # Shift left by N → asl
        m = re.match(r'^(\w+(?:\.\w+)?)\s*<<\s*(\d+)$', source)
        if m:
            self._load_a(m.group(1))
            for _ in range(int(m.group(2))):  self.I('asl a')
            self._store_a(target)
            return

        # General: load byte into A, store
        self._load_a(source)
        self._store_a(target)

    # ---- augmented assignment ----

    def _augment(self, target: str, op: str, source: str):
        source, _ = _split_cmt(source.strip().rstrip(';'))
        source = source.strip()
        target = target.strip()
        tgt_bare = re.split(r'\s*\[', target)[0].strip()
        tgt_type  = self.typeof(tgt_bare)
        n = self.parse_int(source)
        is_arr = '[' in target

        if op == '+=':
            if not is_arr and n == 1:
                if tgt_type == 'word':
                    lbl = self.fresh('iw')
                    self.I(f'inc {target}'); self.I(f'bne {lbl}')
                    self.I(f'inc {target}+1'); self.L(lbl)
                else:
                    self.I(f'inc {target}')
            elif not is_arr and n is not None:
                self.I(f'lda {target}'); self.I('clc')
                self.I(f'adc #{self.fmt(n)}'); self.I(f'sta {target}')
            elif not is_arr and re.match(r'^\w+(?:\.\w+)?$', source):
                self.I(f'lda {target}'); self.I('clc')
                self.I(f'adc {source}');  self.I(f'sta {target}')
            else:
                self.TODO(f'{target} += {source}')

        elif op == '-=':
            if not is_arr and n == 1:
                if tgt_type == 'word':
                    lbl = self.fresh('dw')
                    self.I(f'lda {target}'); self.I(f'bne {lbl}')
                    self.I(f'dec {target}+1'); self.L(lbl)
                    self.I(f'dec {target}')
                else:
                    self.I(f'dec {target}')
            elif not is_arr and n is not None:
                self.I(f'lda {target}'); self.I('sec')
                self.I(f'sbc #{self.fmt(n)}'); self.I(f'sta {target}')
            elif not is_arr and re.match(r'^\w+(?:\.\w+)?$', source):
                self.I(f'lda {target}'); self.I('sec')
                self.I(f'sbc {source}');  self.I(f'sta {target}')
            else:
                self.TODO(f'{target} -= {source}')

        elif op in ('&=', '|=', '^='):
            alu = {'&=': 'and', '|=': 'ora', '^=': 'eor'}[op]
            self.I(f'lda {target}')
            if n is not None:   self.I(f'{alu} #{self.fmt(n)}')
            elif re.match(r'^\w+(?:\.\w+)?$', source): self.I(f'{alu} {source}')
            else:               self.TODO(f'{alu} {source}')
            self.I(f'sta {target}')

        elif op == '<<=':
            if n is not None and n >= 8:
                self.I(f'lda #0'); self.I(f'sta {target}')
            elif n is not None:
                for _ in range(n): self.I(f'asl {target}')
            else:
                self.TODO(f'{target} <<= {source}')

        elif op == '>>=':
            if n is not None and n >= 8:
                self.I(f'lda #0'); self.I(f'sta {target}')
            elif n is not None:
                for _ in range(n): self.I(f'lsr {target}')
            else:
                self.TODO(f'{target} >>= {source}')

    # ---- inc / dec ----

    def _incr(self, target: str):
        target = target.strip()
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\d+)\]$', target)
        if m:   self.I(f'inc {m.group(1)}+{m.group(2)}'); return
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\w+)\]$', target)
        if m:
            self.I(f'ldy {m.group(2)}'); self.I(f'lda {m.group(1)},y')
            self.I('clc'); self.I('adc #1'); self.I(f'sta {m.group(1)},y')
            return
        if self.typeof(target) == 'word':
            lbl = self.fresh('iw')
            self.I(f'inc {target}'); self.I(f'bne {lbl}')
            self.I(f'inc {target}+1'); self.L(lbl)
        else:
            self.I(f'inc {target}')

    def _decr(self, target: str):
        target = target.strip()
        m = re.match(r'^(\w+(?:\.\w+)?)\s*\[(\d+)\]$', target)
        if m:   self.I(f'dec {m.group(1)}+{m.group(2)}'); return
        if self.typeof(target) == 'word':
            lbl = self.fresh('dw')
            self.I(f'lda {target}'); self.I(f'bne {lbl}')
            self.I(f'dec {target}+1'); self.L(lbl)
            self.I(f'dec {target}')
        else:
            self.I(f'dec {target}')

    # ---- condition branch emission ----
    # Emits branch to `true_lbl` when condition holds, or falls through.
    # Pass `negate=True` to branch when condition does NOT hold.

    def _emit_cond(self, cond: str, true_lbl: str, negate: bool = False):
        """Emit a condition test and conditional branch.
        When negate=False: branch to true_lbl if condition is TRUE.
        When negate=True:  branch to true_lbl if condition is FALSE.
        """
        cond = cond.strip()

        # if_z / if_nz / if_cs / if_cc  (Prog8 flag shorthand)
        flag_map = {
            'if_z': ('beq', 'bne'), 'if_nz': ('bne', 'beq'),
            'if_cs': ('bcs', 'bcc'), 'if_cc': ('bcc', 'bcs'),
        }
        if cond in flag_map:
            bop = flag_map[cond][1 if negate else 0]
            self.I(f'{bop} {true_lbl}')
            return

        # NOT / not x
        m = re.match(r'^(?:not|!)\s+(.+)$', cond, re.I)
        if m:
            self._emit_cond(m.group(1), true_lbl, negate=not negate)
            return

        # Comparison: LHS op RHS
        m = re.match(r'^(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)$', cond)
        if m:
            lhs, op, rhs = m.group(1).strip(), m.group(2), m.group(3).strip()
            rhs_n = self.parse_int(rhs)

            # For > and <= with literal RHS: compare with N+1 and use >= or <
            # For > and <= with variable RHS: swap operands (x > y → lda y, cmp x, bcc)
            cmp_op   = op
            cmp_lhs  = lhs
            cmp_rhs  = rhs
            cmp_rhs_n = rhs_n

            if op == '>':
                if rhs_n is not None:
                    if rhs_n == 255:
                        if negate: self.I(f'jmp {true_lbl}')   # never true → always skip
                        return
                    cmp_rhs_n = rhs_n + 1
                    cmp_rhs   = self.fmt(cmp_rhs_n)
                    cmp_op    = '>='
                else:
                    # x > y  ≡  y < x  →  swap, use '<' branch
                    cmp_lhs, cmp_rhs, cmp_op = rhs, lhs, '<'
                    cmp_rhs_n = None
            elif op == '<=':
                if rhs_n is not None:
                    if rhs_n == 255:
                        if not negate: self.I(f'jmp {true_lbl}')  # always true
                        return
                    cmp_rhs_n = rhs_n + 1
                    cmp_rhs   = self.fmt(cmp_rhs_n)
                    cmp_op    = '<'
                else:
                    # x <= y  ≡  y >= x  →  swap, use '>=' branch
                    cmp_lhs, cmp_rhs, cmp_op = rhs, lhs, '>='
                    cmp_rhs_n = None

            # Load (possibly swapped) LHS
            self._load_a(cmp_lhs)

            # Emit CMP (skip for zero compare with == or !=)
            if not (cmp_rhs_n == 0 and cmp_op in ('==', '!=')):
                if cmp_rhs_n is not None:
                    self.I(f'cmp #{self.fmt(cmp_rhs_n)}')
                elif re.match(r'^\w+(?:\.\w+)?(?:\+1)?$', cmp_rhs):
                    self.I(f'cmp {cmp_rhs}')
                else:
                    self.TODO(f'cmp {cmp_rhs}')

            # Branch table: op → (branch_if_true, branch_if_false)
            btable = {'==': ('beq','bne'), '!=': ('bne','beq'),
                      '<':  ('bcc','bcs'), '>=': ('bcs','bcc')}
            if cmp_op in btable:
                bop = btable[cmp_op][1 if negate else 0]
                self.I(f'{bop} {true_lbl}')
            else:
                self.TODO(f'cond {cond}')
            return

        # Plain variable / bool — non-zero is true
        if re.match(r'^\w+(?:\.\w+)?$', cond):
            self._load_a(cond)
            bop = 'beq' if negate else 'bne'
            self.I(f'{bop} {true_lbl}')
            return

        self.TODO(f'cond {cond}')

    # ---- function call ----

    def _call(self, func: str, args_str: str):
        args = [a.strip() for a in args_str.split(',') if a.strip()] if args_str.strip() else []
        # Load first arg in A, second in Y (Prog8 calling convention for simple cases)
        if len(args) == 1:
            self._load_a(args[0])
        elif len(args) == 2:
            self._load_a(args[0])
            rhs_n = self.parse_int(args[1])
            if rhs_n is not None:
                self.I(f'ldy #{self.fmt(rhs_n)}')
            elif re.match(r'^\w+(?:\.\w+)?$', args[1]):
                self.I(f'ldy {args[1]}')
            else:
                self.TODO(f'arg2 {args[1]}')
        elif len(args) > 2:
            for i, arg in enumerate(args):
                n = self.parse_int(arg)
                if n is not None:
                    self.I(f'lda #{self.fmt(n)}'); self.I(f'sta {func}.param{i+1}')
                elif re.match(r'^\w+(?:\.\w+)?$', arg):
                    self.I(f'lda {arg}'); self.I(f'sta {func}.param{i+1}')
                else:
                    self.TODO(f'arg {arg}')
        self.I(f'jsr {func}')

    # ---- data declarations ----

    def _emit_array(self, m: re.Match, lines: list[str], idx: list[int]):
        is_word = m.group(1).lower() in ('uword', 'word')
        name, rest = m.group(2), m.group(3)
        directive = '.word' if is_word else '.byte'
        bpv = 2 if is_word else 1
        self.reg(name, 'word' if is_word else 'byte')
        self.out.append(f'{name}:')
        parts: list[tuple[str,str]] = []
        while True:
            if ']' in rest:
                rest = rest[:rest.index(']')]
                d, c = _split_cmt(rest.strip().rstrip(',')); parts.append((d, c)); break
            d, c = _split_cmt(rest.strip().rstrip(',')); parts.append((d, c))
            if idx[0] >= len(lines): break
            rest = lines[idx[0]].strip(); idx[0] += 1
        for d, c in parts:
            if not d:
                if c: self.C(c)
                continue
            conv = _bytes_to_hex(d)
            if conv:
                self.bc += (conv.count(',') + 1) * bpv
                lo = f'    {directive} {conv}'
                if c: lo += f'  // {c}'
                self.out.append(lo)

    # ---- statement dispatch ----

    def stmt(self, s: str, lines: list[str], idx: list[int]):
        """Translate one stripped Prog8 statement."""
        s = s.rstrip(';').strip()
        if not s: return

        if s.startswith(';'): self.C(s[1:].strip()); return
        if s.startswith('//'): self.out.append(s); return

        # return
        if s == 'return': self.I('rts'); return
        m = re.match(r'^return\s+(.+)$', s)
        if m:
            retval = m.group(1).strip()
            if self.typeof(retval) == 'word':
                self.I(f'lda {retval}'); self.I(f'ldy {retval}+1')
            else:
                self._load_a(retval)
            self.I('rts'); return

        # break (loop exit) → jmp to captured end label stored in self._break_lbl
        if s == 'break':
            lbl = getattr(self, '_break_lbl', None)
            if lbl: self.I(f'jmp {lbl}')
            else: self.TODO('break (no loop context)')
            return
        if s == 'continue':
            lbl = getattr(self, '_cont_lbl', None)
            if lbl: self.I(f'jmp {lbl}')
            else: self.TODO('continue (no loop context)')
            return

        # if_z / if_nz / if_cs / if_cc  (Prog8 post-condition shortcuts)
        if s in ('if_z', 'if_nz', 'if_cs', 'if_cc'):
            self.C(f'[Prog8 post-condition] {s}  — insert beq/bne/bcs/bcc above'); return

        # ++  --
        m = _INCR_RE.match(s)
        if m: self._incr(m.group(1)); return
        m = _DECR_RE.match(s)
        if m: self._decr(m.group(1)); return

        # augmented assignment
        m = _AUGMENT_RE.match(s)
        if m: self._augment(m.group(1), m.group(2), m.group(3)); return

        # for loop
        m = _FOR_RE.match(s)
        if m: self._for_loop(m, lines, idx); return

        # while loop
        m = _WHILE_RE.match(s)
        if m: self._while_loop(m.group(1), lines, idx); return

        # repeat loop
        m = _REPEAT_RE.match(s)
        if m: self._repeat_loop(m.group(1), lines, idx); return

        # if / if-else
        m = _IF_RE.match(s)
        if m: self._if_stmt(m.group(1), lines, idx); return

        # %asm {{
        if _P8_ASM_OPEN.search(s):
            after = _P8_ASM_OPEN.sub('', s).strip()
            self._asm_block(after, lines, idx); return

        # void call / call with return discard: void foo(args)
        # or result, status = foo(args)  → strip lhs assignment
        m = re.match(r'^void\s+(\w+(?:\.\w+)*)\s*\(([^)]*)\)$', s, re.I)
        if m: self._call(m.group(1), m.group(2)); return

        # function call (no void prefix, result discarded)
        m = re.match(r'^(\w+(?:\.\w+)*)\s*\(([^)]*)\)$', s)
        if m and not re.match(r'^(if|for|while|repeat)\b', m.group(1), re.I):
            self._call(m.group(1), m.group(2)); return

        # assignment  (must come after call detection)
        m = _ASSIGN_RE.match(s)
        if m: self._assign(m.group(1), m.group(2)); return

        # const inside sub
        m = _P8_CONST.match(s)
        if m:
            name = m.group(2); val, cmt = _split_cmt(m.group(3).strip().rstrip(';'))
            lo = f'.const {name} = {val.strip()}'
            if cmt: lo += f'  // {cmt}'
            self.out.append(lo); return

        # Variable declaration with initial value
        m = _P8_VAR.match(s)
        if m:
            typ_kw = m.group(1).lower(); name = m.group(2)
            val_expr = (m.group(3) or '').strip().rstrip(';')
            val_expr, _ = _split_cmt(val_expr)
            val_expr = val_expr.strip()
            is_word = typ_kw in ('uword', 'word', 'float')
            self.reg(name, 'word' if is_word else 'byte')
            # Normalise bool/Prog8 literals to numeric
            val_expr = {'false': '0', 'true': '1'}.get(val_expr.lower(), val_expr)
            directive = '.word' if is_word else '.byte'
            if val_expr and not val_expr.startswith('memory('):
                self.out.append(f'{name}:')
                self.out.append(f'    {directive} {val_expr}')
            else:
                self.out.append(f'{name}:')
                self.out.append(f'    {directive} 0')
            return

        self.TODO(s)

    # ---- if / else ----

    def _if_stmt(self, cond: str, lines: list[str], idx: list[int]):
        cond = cond.rstrip('{').strip()
        body = self._capture_block(lines, idx)

        # Check for else / else if (pushed back by _capture_block)
        else_body = None
        else_cond = None
        if idx[0] < len(lines):
            peek = lines[idx[0]].strip()
            m = _ELSE_RE.match(peek)
            if m:
                idx[0] += 1
                else_cond_raw = m.group(1)           # None if plain else
                else_cond = else_cond_raw.rstrip('{').strip() if else_cond_raw else None
                else_body = self._capture_block(lines, idx)

        end_lbl = self.fresh('if_end')

        if else_body is not None:
            else_lbl = self.fresh('if_else')
            self._emit_cond(cond, else_lbl, negate=True)
            self._translate_body(body, lines)
            self.I(f'jmp {end_lbl}')
            self.L(else_lbl)
            if else_cond:
                # else if — translate recursively using the captured body
                inner_end = self.fresh('elif_end')
                self._emit_cond(else_cond, inner_end, negate=True)
                self._translate_body(else_body, lines)
                self.L(inner_end)
            else:
                self._translate_body(else_body, lines)
            self.L(end_lbl)
        else:
            self._emit_cond(cond, end_lbl, negate=True)
            self._translate_body(body, lines)
            self.L(end_lbl)

    # ---- while loop ----
    # Desugared (from CodeDesugarer.kt):
    #   _while: if NOT cond goto _after / body / goto _while / _after:

    def _while_loop(self, cond: str, lines: list[str], idx: list[int]):
        cond = cond.rstrip('{').strip()
        body = self._capture_block(lines, idx)
        lbl_top  = self.fresh('while')
        lbl_end  = self.fresh('wend')
        prev_break, prev_cont = getattr(self, '_break_lbl', None), getattr(self, '_cont_lbl', None)
        self._break_lbl, self._cont_lbl = lbl_end, lbl_top
        self.L(lbl_top)
        self._emit_cond(cond, lbl_end, negate=True)   # branch to end when FALSE
        self._translate_body(body, lines)
        self.I(f'jmp {lbl_top}')
        self.L(lbl_end)
        self._break_lbl, self._cont_lbl = prev_break, prev_cont

    # ---- for loop ----
    # From ForLoopsAsmGen.kt: ascending step-1 byte range.

    def _for_loop(self, m: re.Match, lines: list[str], idx: list[int]):
        varname = m.group(1)
        start_s = m.group(2).strip()
        direction = m.group(3).lower()   # 'to' or 'downto'
        end_s = m.group(4).rstrip('{').strip()
        step_s = (m.group(5) or '1').rstrip('{').strip()
        body = self._capture_block(lines, idx)

        step_n = self.parse_int(step_s) or 1
        lbl_loop = self.fresh('for')
        lbl_end  = self.fresh('fend')
        lim_var  = self.fresh('flim')
        prev_break, prev_cont = getattr(self,'_break_lbl',None), getattr(self,'_cont_lbl',None)
        self._break_lbl, self._cont_lbl = lbl_end, lbl_loop

        if direction == 'to':
            # Ascending
            self.reg(varname, 'byte')
            # Declare temp storage for limit (before code that uses it)
            self.out.append(f'{lim_var}: .byte 0')
            # store limit
            self._load_a(end_s)
            self.I(f'sta {lim_var}')
            # init loop var
            self._load_a(start_s)
            self.I(f'sta {varname}')
            # pre-check: skip if start > end
            self.I(f'cmp {lim_var}')
            self.I(f'bcs {lbl_end}')
            self.L(lbl_loop)
            self._translate_body(body, lines)
            self.I(f'lda {varname}')
            self.I(f'cmp {lim_var}')
            self.I(f'beq {lbl_end}')
            for _ in range(step_n): self.I(f'inc {varname}')
            self.I(f'jmp {lbl_loop}')
        else:
            # Descending (downto)
            self.reg(varname, 'byte')
            self._load_a(start_s)
            self.I(f'sta {varname}')
            end_n = self.parse_int(end_s)
            self.L(lbl_loop)
            self._translate_body(body, lines)
            self.I(f'lda {varname}')
            if end_n is not None and end_n == 0:
                # downto 0: dec then check for wrap (255)
                for _ in range(step_n): self.I(f'dec {varname}')
                self.I(f'lda {varname}')
                self.I(f'cmp #$ff')
                self.I(f'bne {lbl_loop}')
            else:
                if end_n is not None:
                    self.I(f'cmp #{self.fmt(end_n)}')
                else:
                    self.I(f'cmp {end_s}')
                self.I(f'beq {lbl_end}')
                for _ in range(step_n): self.I(f'dec {varname}')
                self.I(f'jmp {lbl_loop}')

        self.L(lbl_end)
        self._break_lbl, self._cont_lbl = prev_break, prev_cont

    # ---- repeat loop ----
    # From AsmGen.kt repeatByteCount / repeatWordCount

    def _repeat_loop(self, count_s, lines: list[str], idx: list[int]):
        body = self._capture_block(lines, idx)
        lbl_loop = self.fresh('rep')
        lbl_end  = self.fresh('rend')
        prev_break, prev_cont = getattr(self,'_break_lbl',None), getattr(self,'_cont_lbl',None)
        self._break_lbl, self._cont_lbl = lbl_end, lbl_loop

        if count_s is None:
            # Infinite repeat
            self.L(lbl_loop)
            self._translate_body(body, lines)
            self.I(f'jmp {lbl_loop}')
        else:
            count_s = count_s.strip().rstrip('{').strip()
            n = self.parse_int(count_s)
            cnt_var = self.fresh('rcnt')
            if n is not None and n <= 256:
                # Byte counter (from repeatByteCount)
                self.I(f'lda #{self.fmt(n & 0xFF)}')
                self.I(f'sta {cnt_var}')
                self.out.append(f'{cnt_var}: .byte 0')
                self.L(lbl_loop)
                self._translate_body(body, lines)
                self.I(f'dec {cnt_var}')
                self.I(f'bne {lbl_loop}')
            elif n is not None:
                # Word counter (from repeatWordCount)
                lo, hi = n & 0xFF, (n >> 8) & 0xFF
                self.I(f'lda #{self.fmt(lo)}'); self.I(f'sta {cnt_var}')
                self.I(f'lda #{self.fmt(hi)}'); self.I(f'sta {cnt_var}+1')
                self.out.append(f'{cnt_var}: .word 0')
                self.L(lbl_loop)
                self._translate_body(body, lines)
                self.I(f'dec {cnt_var}')
                self.I(f'bne {lbl_loop}')
                self.I(f'dec {cnt_var}+1')
                self.I(f'bne {lbl_loop}')
            else:
                # Variable count: load into Y, use repeatCountInY pattern
                self._load_a(count_s)
                self.I(f'tay')
                self.I(f'beq {lbl_end}')
                self.I(f'sty {cnt_var}')
                self.out.append(f'{cnt_var}: .byte 0')
                self.L(lbl_loop)
                self._translate_body(body, lines)
                self.I(f'dec {cnt_var}')
                self.I(f'bne {lbl_loop}')

        self.L(lbl_end)
        self._break_lbl, self._cont_lbl = prev_break, prev_cont

    # ---- %asm block passthrough ----

    def _asm_block(self, after_open: str, lines: list[str], idx: list[int]):
        content = after_open
        while True:
            if '}}' in content:
                before = content[:content.index('}}')].strip()
                if before: self._asm_line(before)
                break
            self._asm_line(content)
            if idx[0] >= len(lines): break
            content = lines[idx[0]].strip(); idx[0] += 1

    def _asm_line(self, line: str):
        if not line: self.E(); return
        if line.startswith(';') or line.startswith('//'):
            self.C(line.lstrip(';/').strip()); return
        # DASM anon labels
        if line == '-': self.out.append('!_bwd:'); return
        if line == '+': self.out.append('!_fwd:'); return
        m = re.match(r'^-\s+(.+)', line)
        if m: self.out.append('!_bwd:'); self.I(m.group(1)); return
        m = re.match(r'^(\+)\s+(.+)', line)
        if m: self.out.append('!_fwd:'); self.I(m.group(2)); return
        # Branch references
        line = re.sub(r'\b(b(?:ne|eq|cs|cc|pl|mi|vs|vc))\s+-$', r'\1 !_bwd-', line)
        line = re.sub(r'\b(b(?:ne|eq|cs|cc|pl|mi|vs|vc))\s+\+$', r'\1 !_fwd+', line)
        # .byte / .char with complex expression → comment
        mb = _P8_BYTE_DIR.search(line)
        if mb:
            rest, cmt = _split_cmt(mb.group(1))
            if _P8_SIMPLE_LIST.match(rest):
                conv = _bytes_to_hex(rest)
                if conv:
                    self.bc += conv.count(',') + 1
                    lo = f'    .byte {conv}'
                    if cmt: lo += f'  // {cmt}'
                    self.out.append(lo); return
            self.C(f'.byte {rest.strip()}  [complex expr — translate manually]'); return
        # Underscore-prefix labels (DASM local labels)
        if re.match(r'^_[A-Za-z0-9_]*:?\s*$', line):
            lbl = line.rstrip().rstrip(':') + ':'
            self.out.append(lbl); return
        # Explicit label with colon
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]+:\s*$', line):
            self.out.append(line.rstrip()); return
        self.I(line)

    # ---- block capture and translation ----

    def _capture_block(self, lines: list[str], idx: list[int]) -> list[str]:
        """Read lines until matching '}'.
        Lines starting with '}' always close one nesting level — if they also
        have content after the '}' (e.g. '} else if cond {'), that content is
        pushed back into the lines list so the caller can process it.
        """
        depth = 1
        body: list[str] = []
        while idx[0] < len(lines) and depth > 0:
            stripped = lines[idx[0]].strip()

            if stripped.startswith('}'):
                # Closing brace first — always decrements depth
                idx[0] += 1
                depth -= 1
                after = stripped[1:].strip()   # e.g. 'else if cond {' or ''
                if depth == 0:
                    if after:
                        # Push the 'else ...' part back as the next line
                        lines.insert(idx[0], after)
                    break
                else:
                    # Still nested — the } was for an inner block
                    # Re-account for any extra braces on this line
                    rest_clean = after.replace('{{','').replace('}}','')
                    depth += rest_clean.count('{') - rest_clean.count('}')
                    body.append(stripped)
            else:
                idx[0] += 1
                clean = stripped.replace('{{', '').replace('}}', '')
                depth += clean.count('{') - clean.count('}')
                if depth > 0:
                    body.append(stripped)
                else:
                    # Closing brace somewhere mid-line (rare but possible)
                    before = stripped.rsplit('}', 1)[0].strip()
                    if before: body.append(before)
                    after = stripped.rsplit('}', 1)[-1].strip()
                    if after: lines.insert(idx[0], after)
        return body

    def _translate_body(self, body: list[str], parent_lines: list[str],
                        body_idx: list[int] | None = None):
        """Translate a list of Prog8 lines recursively."""
        if body_idx is None:
            body_idx = [0]
        while body_idx[0] < len(body):
            line = body[body_idx[0]].strip(); body_idx[0] += 1
            if not line: self.E(); continue
            if line.startswith(';'): self.C(line[1:].strip()); continue
            if line.startswith('//'): self.out.append(line); continue
            # %asm
            if _P8_ASM_OPEN.search(line):
                after = _P8_ASM_OPEN.sub('', line).strip()
                self._asm_block(after, body, body_idx); continue
            # ubyte[] array
            am = _P8_ARRAY_START.match(line)
            if am: self._emit_array(am, body, body_idx); continue
            # ubyte[N] fixed
            if _P8_FIXARR.match(line):
                mm = _P8_FIXARR.match(line)
                is_w = mm.group(1).lower() in ('uword','word')
                sz, nm = mm.group(2), mm.group(3)
                self.reg(nm, 'word' if is_w else 'byte')
                self.out.append(f'{nm}:')
                self.out.append(f'    .fill {sz}, 0')
                continue
            # const
            mc = _P8_CONST.match(line)
            if mc:
                nm = mc.group(2); val, cmt = _split_cmt(mc.group(3).strip().rstrip(';'))
                lo = f'.const {nm} = {val.strip()}'
                if cmt: lo += f'  // {cmt}'
                self.out.append(lo); continue
            # sub / asmsub
            sm = _P8_SUB.match(line)
            if sm:
                self._sub(sm.group(1), line, body, body_idx); continue
            # nested block: name { → treat as section header
            nm = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\{$', line)
            if nm:
                self.C(f'---- {nm.group(1)} ----')
                inner = self._capture_block(body, body_idx)
                self._translate_body(inner, body)
                continue
            # bare closing brace (already consumed by _capture_block, but just in case)
            if line == '}': continue
            self.stmt(line, body, body_idx)

    # ---- sub / asmsub ----

    def _sub(self, name: str, header: str, lines: list[str], idx: list[int]):
        self.E(); self.L(name)
        clean = header.replace('{{','').replace('}}','')
        depth = clean.count('{') - clean.count('}')
        while depth <= 0 and idx[0] < len(lines):
            ln = lines[idx[0]].strip(); idx[0] += 1
            cl = ln.replace('{{','').replace('}}','')
            depth += cl.count('{') - cl.count('}')
        body = self._capture_block(lines, idx)
        self._translate_body(body, lines)
        last = next((l.strip() for l in reversed(self.out) if l.strip()), '')
        if last not in ('rts','rti') and not last.startswith('jmp '):
            self.I('rts')


# ---------------------------------------------------------------------------
# Helpers (module-level so they work without a Translator instance)
# ---------------------------------------------------------------------------

def _split_cmt(text: str) -> tuple[str, str]:
    in_str = False
    for i, c in enumerate(text):
        if c == '"': in_str = not in_str
        elif not in_str:
            if text[i:i+2] == '//': return text[:i].rstrip(), text[i+2:].strip()
            if c == ';':            return text[:i].rstrip(), text[i+1:].strip()
    return text, ''

_TOKEN_RE = re.compile(
    r'\$[0-9a-fA-F]+|0[xX][0-9a-fA-F]+|%[01]+|[0-9a-fA-F]+[hH]\b|\b\d+\b')

def _bytes_to_hex(raw: str) -> str | None:
    vals = []
    for tok in _TOKEN_RE.findall(raw):
        try:
            if tok.startswith('$'):          v = int(tok[1:], 16)
            elif tok.lower().startswith('0x'): v = int(tok[2:], 16)
            elif tok.startswith('%'):        v = int(tok[1:], 2)
            elif tok.lower().endswith('h'): v = int(tok[:-1], 16)
            else:                            v = int(tok, 10)
            if 0 <= v <= 255: vals.append(v)
        except ValueError:
            pass
    return ','.join(f'${b:02x}' for b in vals) if vals else None


# ---------------------------------------------------------------------------
# Top-level file translator
# ---------------------------------------------------------------------------

def translate_file(text: str) -> str:
    lines = text.splitlines()
    total = len(lines)
    idx   = [0]
    T     = Translator()

    while idx[0] < total:
        raw = lines[idx[0]]; idx[0] += 1
        s   = raw.strip()

        if not s: T.E(); continue
        if s.startswith(';'): T.C(s[1:].strip()); continue
        if s.startswith('//'): T.out.append(s); continue

        # %import
        m = _IMPORT_RE.match(s)
        if m: T.C(f'TODO: #import "{m.group(1)}.asm"'); continue

        # %address $xxxx → org
        m = _ADDR_RE.match(s)
        if m: T.out.append(f'* = {m.group(1)}'); continue

        # Other % meta
        if s.startswith('%') and not _P8_ASM_OPEN.match(s):
            T.C(s); continue

        # Top-level const
        m = _P8_CONST.match(s)
        if m:
            nm = m.group(2); val, cmt = _split_cmt(m.group(3).strip().rstrip(';'))
            lo = f'.const {nm} = {val.strip()}'
            if cmt: lo += f'  // {cmt}'
            T.out.append(lo); continue

        # Top-level ubyte[] array
        am = _P8_ARRAY_START.match(s)
        if am: T._emit_array(am, lines, idx); continue

        # Top-level ubyte[N] fixed array
        mm = _P8_FIXARR.match(s)
        if mm:
            is_w = mm.group(1).lower() in ('uword','word')
            sz, nm = mm.group(2), mm.group(3); T.reg(nm,'word' if is_w else 'byte')
            T.out.append(f'{nm}:'); T.out.append(f'    .fill {sz}, 0'); continue

        # Named block: name {
        nm = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\{$', s)
        if nm:
            T.E(); T.C(f'---- {nm.group(1)} ----')
            body = T._capture_block(lines, idx)
            T._translate_body(body, lines)
            T.E(); continue

        # Top-level sub / asmsub
        sm = _P8_SUB.match(s)
        if sm: T._sub(sm.group(1), s, lines, idx); continue

        # Top-level %asm
        if _P8_ASM_OPEN.search(s):
            after = _P8_ASM_OPEN.sub('', s).strip()
            T._asm_block(after, lines, idx); continue

        T.C(f'[Prog8] {s}')

    return '\n'.join(T.out).rstrip() + '\n'


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description='Translate Prog8 (.p8) to KickAssembler 6502 assembly.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('input', help='Prog8 source file (.p8)')
    ap.add_argument('-o', '--output', help='Output file (default: stdout)')
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        sys.exit(f'Error: not found: {args.input}')
    if src.suffix.lower() != '.p8':
        print(f'Warning: expected .p8 extension, got {src.suffix}', file=sys.stderr)

    text   = src.read_text(encoding='utf-8', errors='replace')
    output = translate_file(text)

    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        print(f'Wrote {args.output}')
    else:
        sys.stdout.buffer.write(output.encode('utf-8', errors='replace'))


if __name__ == '__main__':
    main()
