#!/usr/bin/env python3
"""
diskimage-spectrum.py — ZX Spectrum disk/tape image handler.

Stubs (not yet implemented): tzx tap pzx trd scl dsk edsk mgt opd sad tfd
"""

import sys
from pathlib import Path


def _stub(key, desc):
    class _C:
        FORMAT, DESC = key, desc
        def __init__(self, data=b'', path=None): self.data = data; self._path = path
        @classmethod
        def create(cls, disk_name='NEW DISK', **kw):
            raise NotImplementedError(f'{cls.DESC}: create not yet implemented.')
        @classmethod
        def load(cls, path):
            return cls(data=path.read_bytes(), path=path)
        def save(self, path):
            raise NotImplementedError(f'{self.DESC}: save not yet implemented.')
        def list_files(self):
            raise NotImplementedError(f'{self.DESC}: listing not yet implemented.')
        def add_file(self, d, n, t='bin'):
            raise NotImplementedError(f'{self.DESC}: add not yet implemented.')
        def remove_file(self, n):
            raise NotImplementedError(f'{self.DESC}: remove not yet implemented.')
    _C.__name__ = key.upper() + 'Image'
    return _C


FORMATS = {
    'tzx':  {'desc': 'ZX Spectrum TZX Tape Image',           'exts': ['.tzx'],   'cls': _stub('tzx',  'ZX Spectrum TZX Tape Image')},
    'tap':  {'desc': 'ZX Spectrum TAP Tape Image',            'exts': ['.tap'],   'cls': _stub('tap',  'ZX Spectrum TAP Tape Image')},
    'pzx':  {'desc': 'Precision ZX Tape Image',               'exts': ['.pzx'],   'cls': _stub('pzx',  'Precision ZX Tape Image')},
    'trd':  {'desc': 'TR-DOS Floppy Image (ZX Spectrum)',     'exts': ['.trd'],   'cls': _stub('trd',  'TR-DOS Floppy Image')},
    'scl':  {'desc': 'Sinclair Container / Spectrum Floppy',  'exts': ['.scl'],   'cls': _stub('scl',  'Sinclair Container')},
    'dsk':  {'desc': 'CPCEMU DSK (Amstrad CPC)',              'exts': ['.dsk'],   'cls': _stub('dsk',  'CPCEMU DSK (Amstrad CPC)')},
    'edsk': {'desc': 'Extended DSK (Amstrad CPC)',            'exts': ['.edsk'],  'cls': _stub('edsk', 'Extended DSK (Amstrad CPC)')},
    'mgt':  {'desc': 'DISCiPLE/+D Disk Image',               'exts': ['.mgt'],   'cls': _stub('mgt',  'DISCiPLE/+D Disk Image')},
    'opd':  {'desc': 'Opus Discovery Disk Image',             'exts': ['.opd'],   'cls': _stub('opd',  'Opus Discovery Disk Image')},
    'sad':  {'desc': 'SAM Coupé Disk Image',                  'exts': ['.sad'],   'cls': _stub('sad',  'SAM Coupé Disk Image')},
    'tfd':  {'desc': 'TR-DOS Floppy Dump',                   'exts': ['.tfd'],   'cls': _stub('tfd',  'TR-DOS Floppy Dump')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown ZX Spectrum format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect ZX Spectrum format from: {path.name}')


def load(path: Path, fmt: str):
    return FORMATS[fmt]['cls'].load(path)


def create(fmt: str, name: str = 'NEW DISK'):
    return FORMATS[fmt]['cls'].create(disk_name=name)


def _print_listing(files):
    if not files:
        print('(empty disk)')
        return
    for ftype, name, size in files:
        if ftype == 'HEADER':
            print(f'  0  "{name}"'); print()
        else:
            print(f'  {size:4d}  {ftype:<6}  "{name}"')


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description='Manage ZX Spectrum disk/tape images.',
                                 epilog='Formats: ' + ', '.join(FORMATS))
    ap.add_argument('--format', dest='fmt', help='Format key (tzx, tap, trd, scl, ...)')
    sub = ap.add_subparsers(dest='command', required=True)
    pc = sub.add_parser('create'); pc.add_argument('image'); pc.add_argument('--name', default='NEW DISK')
    pl = sub.add_parser('list');   pl.add_argument('image')
    pa = sub.add_parser('add');    pa.add_argument('image'); pa.add_argument('file')
    pa.add_argument('--name');     pa.add_argument('--type', default='bin')
    pr = sub.add_parser('remove'); pr.add_argument('image'); pr.add_argument('name')
    a = ap.parse_args(argv)
    p = Path(a.image)
    try:
        fmt = detect(p, a.fmt)
        if a.command == 'create':
            img = create(fmt, a.name); img.save(p); print(f'Created {fmt.upper()}: {p}')
        elif a.command == 'list':
            img = load(p, fmt); _print_listing(img.list_files())
        elif a.command == 'add':
            name = a.name or Path(a.file).stem.upper()
            img = load(p, fmt); img.add_file(Path(a.file).read_bytes(), name, a.type)
            img.save(p); print(f'Added "{name}" to {p}')
        elif a.command == 'remove':
            img = load(p, fmt)
            if not img.remove_file(a.name.upper()): sys.exit(f'File not found: {a.name}')
            img.save(p); print(f'Removed "{a.name}" from {p}')
    except (ValueError, NotImplementedError, RuntimeError, OSError) as e:
        sys.exit(f'Error: {e}')


if __name__ == '__main__':
    main()
