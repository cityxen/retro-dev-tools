#!/usr/bin/env python3
"""
diskimage-dos.py — DOS/PC disk image handler.

Covers IBM PC, DOS, and Windows-compatible floppy/HDD formats.
Stubs (not yet implemented): ima img td0 imd vfd psi xdf cqm vhd hdi d88 88d
  hdm 2hd 86f nhd cp2 cfi dxp dim dmk fdi hfe dup apridisk
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
    'ima':      {'desc': 'IBM Raw Floppy Image',              'exts': ['.ima'],            'cls': _stub('ima',      'IBM Raw Floppy Image')},
    'img':      {'desc': 'Generic DOS Disk Image',            'exts': ['.img'],            'cls': _stub('img',      'Generic DOS Disk Image')},
    'dsk':      {'desc': 'CPCEMU / Amstrad DSK Format',       'exts': ['.dsk'],            'cls': _stub('dsk',      'CPCEMU/Amstrad DSK Format')},
    'td0':      {'desc': 'TeleDisk Compressed Floppy',        'exts': ['.td0'],            'cls': _stub('td0',      'TeleDisk Compressed Floppy')},
    'imd':      {'desc': 'ImageDisk Format',                  'exts': ['.imd'],            'cls': _stub('imd',      'ImageDisk Format')},
    'vfd':      {'desc': 'Virtual Floppy Disk',               'exts': ['.vfd'],            'cls': _stub('vfd',      'Virtual Floppy Disk')},
    'psi':      {'desc': 'PCE Sector Image',                  'exts': ['.psi'],            'cls': _stub('psi',      'PCE Sector Image')},
    'xdf':      {'desc': 'Extended Density Format (IBM)',     'exts': ['.xdf'],            'cls': _stub('xdf',      'Extended Density Format')},
    'cqm':      {'desc': 'CopyQM Sector Archive',             'exts': ['.cqm'],            'cls': _stub('cqm',      'CopyQM Sector Archive')},
    '360':      {'desc': '360KB DOS Floppy',                  'exts': ['.360'],            'cls': _stub('360',      '360KB DOS Floppy')},
    '720':      {'desc': '720KB DOS Floppy',                  'exts': ['.720'],            'cls': _stub('720',      '720KB DOS Floppy')},
    '144':      {'desc': '1.44MB DOS Floppy',                 'exts': ['.144'],            'cls': _stub('144',      '1.44MB DOS Floppy')},
    'vhd':      {'desc': 'Virtual Hard Disk',                 'exts': ['.vhd'],            'cls': _stub('vhd',      'Virtual Hard Disk')},
    'hdi':      {'desc': 'Hard Disk Image (PC-98/Anex86)',    'exts': ['.hdi'],            'cls': _stub('hdi',      'Hard Disk Image (PC-98/Anex86)')},
    'fdd':      {'desc': 'Floppy Disk Dump (Japanese PCs)',   'exts': ['.fdd'],            'cls': _stub('fdd',      'Floppy Disk Dump')},
    'd88':      {'desc': 'D88 Disk Image (NEC PC-88/98)',     'exts': ['.d88'],            'cls': _stub('d88',      'D88 Disk Image')},
    '88d':      {'desc': 'Alternate D88 Format',              'exts': ['.88d'],            'cls': _stub('88d',      'Alternate D88 Format')},
    'hdm':      {'desc': 'HDM High-Density Floppy (PC-98)',   'exts': ['.hdm'],            'cls': _stub('hdm',      'HDM High-Density Floppy')},
    '2hd':      {'desc': '2HD 1.2MB Japanese Floppy',         'exts': ['.2hd'],            'cls': _stub('2hd',      '2HD 1.2MB Floppy')},
    '86f':      {'desc': '86Box Emulator Floppy Format',      'exts': ['.86f'],            'cls': _stub('86f',      '86Box Emulator Floppy')},
    'nhd':      {'desc': 'T98-Next HDD Image (PC-98)',        'exts': ['.nhd'],            'cls': _stub('nhd',      'T98-Next HDD Image')},
    'cp2':      {'desc': 'Snatch-It / Copy-II-PC Format',     'exts': ['.cp2'],            'cls': _stub('cp2',      'Copy-II-PC Format')},
    'cfi':      {'desc': 'CopyQM Format',                     'exts': ['.cfi'],            'cls': _stub('cfi',      'CopyQM Format')},
    'dxp':      {'desc': 'Disk Express Format',               'exts': ['.dxp'],            'cls': _stub('dxp',      'Disk Express Format')},
    'dim':      {'desc': 'Disk IMage Archiver (DOS)',         'exts': ['.dim'],            'cls': _stub('dim',      'Disk IMage Archiver (DOS)')},
    'dmk':      {'desc': 'Dave Keil Disk Image (TRS/CP/M)',   'exts': ['.dmk'],            'cls': _stub('dmk',      'Dave Keil Disk Image')},
    'fdi':      {'desc': 'Formatted Disk Image (DOS/PC-98)',  'exts': ['.fdi'],            'cls': _stub('fdi',      'Formatted Disk Image (DOS)')},
    'hfe':      {'desc': 'HxC Floppy Emulator Format',        'exts': ['.hfe'],            'cls': _stub('hfe',      'HxC Floppy Emulator Format')},
    'dup':      {'desc': 'DiskDupe Image File',               'exts': ['.dup'],            'cls': _stub('dup',      'DiskDupe Image File')},
    'apridisk': {'desc': 'ApriDisk Format',                   'exts': ['.apridisk'],       'cls': _stub('apridisk', 'ApriDisk Format')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown DOS/PC format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect DOS/PC format from: {path.name}')


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
    ap = argparse.ArgumentParser(description='Manage DOS/PC disk images.',
                                 epilog='Formats: ' + ', '.join(FORMATS))
    ap.add_argument('--format', dest='fmt', help='Format key (ima, img, td0, imd, ...)')
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
