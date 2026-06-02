#!/usr/bin/env python3
"""
diskimage-mac.py — Macintosh disk image handler.

Stubs (not yet implemented): dc42 toast image cpt sea sit
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
    'dc42':  {'desc': 'Disk Copy 4.2 (Mac floppy)',         'exts': ['.dc42'],          'cls': _stub('dc42',  'Disk Copy 4.2')},
    'toast': {'desc': 'Toast CD Image',                      'exts': ['.toast'],         'cls': _stub('toast', 'Toast CD Image')},
    'image': {'desc': 'Apple Disk Image',                    'exts': ['.image'],         'cls': _stub('image', 'Apple Disk Image')},
    'img':   {'desc': 'Raw Disk Image (Mac)',                'exts': ['.img'],           'cls': _stub('img',   'Raw Disk Image (Mac)')},
    'cpt':   {'desc': 'Compact Pro Archive',                 'exts': ['.cpt'],           'cls': _stub('cpt',   'Compact Pro Archive')},
    'sea':   {'desc': 'Self-Extracting Archive (Mac)',       'exts': ['.sea'],           'cls': _stub('sea',   'Self-Extracting Archive (Mac)')},
    'sit':   {'desc': 'StuffIt Archive',                     'exts': ['.sit'],           'cls': _stub('sit',   'StuffIt Archive')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown Mac format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect Mac format from: {path.name}')


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
    ap = argparse.ArgumentParser(description='Manage Macintosh disk images.',
                                 epilog='Formats: ' + ', '.join(FORMATS))
    ap.add_argument('--format', dest='fmt', help='Format key (dc42, toast, sit, ...)')
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
