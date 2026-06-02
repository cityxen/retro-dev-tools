#!/usr/bin/env python3
"""
diskimage-trs80.py — TRS-80 disk image handler.

Covers TRS-80 Model I/III/IV, Color Computer (CoCo), Dragon 32/64.
Stubs (not yet implemented): jv1 jv3 dmk jvc vdk dsk imd td0 cmd tpdd scp sdf h8d
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
    'jv1':  {'desc': 'JV1 Single-Density TRS-80 Disk',       'exts': ['.jv1'],   'cls': _stub('jv1',  'JV1 Single-Density TRS-80 Disk')},
    'jv3':  {'desc': 'JV3 Variable-Geometry TRS-80 Disk',    'exts': ['.jv3'],   'cls': _stub('jv3',  'JV3 Variable-Geometry TRS-80 Disk')},
    'dmk':  {'desc': 'DMK Track-Image Format (TRS-80)',       'exts': ['.dmk'],   'cls': _stub('dmk',  'DMK Track-Image Format')},
    'jvc':  {'desc': 'JVC CoCo Standard Disk Image',          'exts': ['.jvc'],   'cls': _stub('jvc',  'JVC CoCo Standard Disk Image')},
    'vdk':  {'desc': 'VDK Virtual Disk (Dragon 32/64)',       'exts': ['.vdk'],   'cls': _stub('vdk',  'VDK Virtual Disk (Dragon 32/64)')},
    'dsk':  {'desc': 'Generic TRS-80 Disk Image',             'exts': ['.dsk'],   'cls': _stub('dsk',  'Generic TRS-80 Disk Image')},
    'imd':  {'desc': 'ImageDisk Format (TRS-80)',             'exts': ['.imd'],   'cls': _stub('imd',  'ImageDisk Format (TRS-80)')},
    'td0':  {'desc': 'TeleDisk Compressed Format (TRS-80)',   'exts': ['.td0'],   'cls': _stub('td0',  'TeleDisk Compressed (TRS-80)')},
    'cmd':  {'desc': 'CoCo DOS Disk Image',                   'exts': ['.cmd'],   'cls': _stub('cmd',  'CoCo DOS Disk Image')},
    'tpdd': {'desc': 'TPDD Disk Image (Model 100)',           'exts': ['.tpdd'],  'cls': _stub('tpdd', 'TPDD Disk Image (Model 100)')},
    'scp':  {'desc': 'SuperCard Pro Flux Image',              'exts': ['.scp'],   'cls': _stub('scp',  'SuperCard Pro Flux Image')},
    'sdf':  {'desc': 'CoCo SDC Disk Image',                   'exts': ['.sdf'],   'cls': _stub('sdf',  'CoCo SDC Disk Image')},
    'h8d':  {'desc': 'Heathkit/TRS-80 H8D Disk Image',       'exts': ['.h8d'],   'cls': _stub('h8d',  'Heathkit/TRS-80 H8D Disk Image')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown TRS-80 format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect TRS-80 format from: {path.name}')


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
    ap = argparse.ArgumentParser(description='Manage TRS-80 disk images.',
                                 epilog='Formats: ' + ', '.join(FORMATS))
    ap.add_argument('--format', dest='fmt', help='Format key (jv1, jv3, dmk, jvc, vdk, ...)')
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
