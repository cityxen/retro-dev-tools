#!/usr/bin/env python3
"""
diskimage-other.py — Miscellaneous/preservation/cross-platform disk image handler.

Covers flux images, CP/M, universal preservation formats, and anything else
that doesn't belong to a specific platform module.
Stubs (not yet implemented): scp raw hfe mfi ufi dfi kfraw mfm gcr wav cdt
  cpm slt sav dup a2r
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
    'scp':    {'desc': 'SuperCard Pro Flux Image',            'exts': ['.scp'],     'cls': _stub('scp',    'SuperCard Pro Flux Image')},
    'raw':    {'desc': 'Raw Flux / Bitstream Image',          'exts': ['.raw'],     'cls': _stub('raw',    'Raw Flux / Bitstream Image')},
    'hfe':    {'desc': 'HxC Floppy Emulator Format',          'exts': ['.hfe'],     'cls': _stub('hfe',    'HxC Floppy Emulator Format')},
    'mfi':    {'desc': 'MAME Floppy Image',                   'exts': ['.mfi'],     'cls': _stub('mfi',    'MAME Floppy Image')},
    'ufi':    {'desc': 'Universal Floppy Image',              'exts': ['.ufi'],     'cls': _stub('ufi',    'Universal Floppy Image')},
    'dfi':    {'desc': 'DiscFerret / Digital Floppy Image',   'exts': ['.dfi'],     'cls': _stub('dfi',    'DiscFerret / Digital Floppy Image')},
    'kfraw':  {'desc': 'KryoFlux Stream Files',               'exts': ['.kfraw'],   'cls': _stub('kfraw',  'KryoFlux Stream Files')},
    'mfm':    {'desc': 'MFM Bitstream Image',                 'exts': ['.mfm'],     'cls': _stub('mfm',    'MFM Bitstream Image')},
    'gcr':    {'desc': 'GCR Bitstream Image',                 'exts': ['.gcr'],     'cls': _stub('gcr',    'GCR Bitstream Image')},
    'a2r':    {'desc': 'Applesauce Flux Image',               'exts': ['.a2r'],     'cls': _stub('a2r',    'Applesauce Flux Image')},
    'cpm':    {'desc': 'CP/M Disk Image',                     'exts': ['.cpm'],     'cls': _stub('cpm',    'CP/M Disk Image')},
    'wav':    {'desc': 'Cassette Audio Image',                'exts': ['.wav'],     'cls': _stub('wav',    'Cassette Audio Image')},
    'cdt':    {'desc': 'Amstrad CPC CDT Tape Image',          'exts': ['.cdt'],     'cls': _stub('cdt',    'Amstrad CPC CDT Tape Image')},
    'rom':    {'desc': 'ROM Cartridge Image',                 'exts': ['.rom'],     'cls': _stub('rom',    'ROM Cartridge Image')},
    'slt':    {'desc': 'Emulator Snapshot / Save State',      'exts': ['.slt'],     'cls': _stub('slt',    'Emulator Snapshot')},
    'sav':    {'desc': 'Save State / Battery Save',           'exts': ['.sav'],     'cls': _stub('sav',    'Save State / Battery Save')},
    'dup':    {'desc': 'DiskDupe Image File',                 'exts': ['.dup'],     'cls': _stub('dup',    'DiskDupe Image File')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown format in "other" module: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect format from: {path.name}')


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
    ap = argparse.ArgumentParser(
        description='Manage miscellaneous and preservation disk images.',
        epilog='Formats: ' + ', '.join(FORMATS),
    )
    ap.add_argument('--format', dest='fmt', help='Format key (scp, raw, hfe, cpm, ...)')
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
