#!/usr/bin/env python3
"""
diskimage-console.py — Game console disk/optical image handler.

Covers: Sega, Nintendo, PlayStation, Dreamcast, CD/DVD/GD-ROM formats.
Stubs (not yet implemented): fds iso bin/cue cdi gdi mds nrg pbp ecm chd mfi
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
    'fds':  {'desc': 'Famicom Disk System Image',           'exts': ['.fds'],              'cls': _stub('fds',  'Famicom Disk System Image')},
    'qd':   {'desc': 'Quick Disk Image',                    'exts': ['.qd'],               'cls': _stub('qd',   'Quick Disk Image')},
    'iso':  {'desc': 'ISO-9660 CD-ROM Image',               'exts': ['.iso'],              'cls': _stub('iso',  'ISO-9660 CD-ROM Image')},
    'bin':  {'desc': 'Raw CD Image (BIN/CUE)',              'exts': ['.bin'],              'cls': _stub('bin',  'Raw CD Image (BIN/CUE)')},
    'cue':  {'desc': 'CD Cue Sheet',                        'exts': ['.cue'],              'cls': _stub('cue',  'CD Cue Sheet')},
    'mds':  {'desc': 'Alcohol 120% Image',                  'exts': ['.mds', '.mdf'],      'cls': _stub('mds',  'Alcohol 120% Image')},
    'ccd':  {'desc': 'CloneCD Image',                       'exts': ['.ccd', '.sub'],      'cls': _stub('ccd',  'CloneCD Image')},
    'cdi':  {'desc': 'DiscJuggler Dreamcast Image',         'exts': ['.cdi'],              'cls': _stub('cdi',  'DiscJuggler Dreamcast Image')},
    'gdi':  {'desc': 'GD-ROM Dump (Dreamcast)',             'exts': ['.gdi'],              'cls': _stub('gdi',  'GD-ROM Dump (Dreamcast)')},
    'nrg':  {'desc': 'Nero CD Image',                       'exts': ['.nrg'],              'cls': _stub('nrg',  'Nero CD Image')},
    'pbp':  {'desc': 'PSP EBOOT Image',                     'exts': ['.pbp'],              'cls': _stub('pbp',  'PSP EBOOT Image')},
    'ecm':  {'desc': 'Error Code Modeler Image',            'exts': ['.ecm'],              'cls': _stub('ecm',  'Error Code Modeler Image')},
    'chd':  {'desc': 'Compressed Hunks of Data (MAME)',     'exts': ['.chd'],              'cls': _stub('chd',  'Compressed Hunks of Data (MAME)')},
    'mfi':  {'desc': 'MAME/MESS Floppy Image',              'exts': ['.mfi'],              'cls': _stub('mfi',  'MAME/MESS Floppy Image')},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown console format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect console format from: {path.name}')


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
    ap = argparse.ArgumentParser(description='Manage game console disk/optical images.',
                                 epilog='Formats: ' + ', '.join(FORMATS))
    ap.add_argument('--format', dest='fmt', help='Format key (iso, bin, gdi, chd, ...)')
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
