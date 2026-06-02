#!/usr/bin/env python3
"""
diskimage.py — Retro disk image dispatcher.

Auto-detects disk format from file extension and routes to the appropriate
sub-module. Sub-modules can also be invoked directly.

Commands
--------
  create  diskimage.py create output.d64 [--name "DISK NAME"]
  add     diskimage.py add image.d64 file.prg [--name FILENAME] [--type prg]
  list    diskimage.py list image.d64
  remove  diskimage.py remove image.d64 FILENAME

Options
-------
  --format FMT   Format key (d64, atr, adf, ...) or module name
                 (commodore, atari, appleii, amiga, mac, console,
                  coleco, dos, msx, spectrum, trs80, other)

Sub-modules
-----------
  diskimage-commodore.py   D64, D71, D81, T64, G64, NIB, ...
  diskimage-atari.py       ATR, XFD, ATX, ST, MSA, ...
  diskimage-appleii.py     DSK, DO, PO, WOZ, 2MG, ...
  diskimage-amiga.py       ADF, DMS, HDF, IPF, ...
  diskimage-mac.py         DC42, TOAST, SIT, ...
  diskimage-console.py     FDS, ISO, GDI, CHD, CDI, ...
  diskimage-coleco.py      DDP, COL, ...
  diskimage-dos.py         IMA, IMG, TD0, IMD, VHD, ...
  diskimage-msx.py         D88, FDI, 1DD, 2DD, ...
  diskimage-spectrum.py    TZX, TRD, SCL, TAP, ...
  diskimage-trs80.py       JV1, JV3, DMK, JVC, VDK, ...
  diskimage-other.py       SCP, HFE, CPM, WAV, ...
"""

import argparse
import importlib.util
import sys
from pathlib import Path

_TOOLS_DIR = Path(__file__).parent

_VALID_MODULES = frozenset({
    'commodore', 'atari', 'appleii', 'amiga', 'mac',
    'console', 'coleco', 'dos', 'msx', 'spectrum', 'trs80', 'other',
})

# Unambiguous extension → module mapping
_EXT_MAP = {
    # Commodore
    '.d64': 'commodore', '.d67': 'commodore', '.d71': 'commodore',
    '.d80': 'commodore', '.d81': 'commodore', '.d82': 'commodore',
    '.d1m': 'commodore', '.g64': 'commodore', '.g71': 'commodore',
    '.nbz': 'commodore', '.t64': 'commodore', '.p00': 'commodore',
    '.crt': 'commodore', '.x64': 'commodore', '.d13': 'commodore',
    '.d90': 'commodore',
    # Atari
    '.atr': 'atari', '.xfd': 'atari', '.atx': 'atari',
    '.st':  'atari', '.msa': 'atari', '.stx': 'atari',
    '.pro': 'atari', '.jam': 'atari', '.di':  'atari',
    # Apple II
    '.do':  'appleii', '.po':  'appleii', '.woz': 'appleii',
    '.2mg': 'appleii', '.hdv': 'appleii', '.sdk': 'appleii',
    '.a2r': 'appleii', '.edd': 'appleii',
    # Amiga
    '.adf': 'amiga', '.adz': 'amiga', '.dms': 'amiga',
    '.hdf': 'amiga', '.ipf': 'amiga', '.rdsk': 'amiga', '.wrp': 'amiga',
    # Mac
    '.dc42': 'mac', '.toast': 'mac', '.image': 'mac',
    '.cpt':  'mac', '.sea':   'mac', '.sit':   'mac',
    # Console
    '.fds': 'console', '.qd':  'console', '.iso':  'console',
    '.cdi': 'console', '.gdi': 'console', '.nrg':  'console',
    '.pbp': 'console', '.ecm': 'console', '.chd':  'console',
    # Apple II — .dsk defaults to Apple DOS 3.3 (use --format to override)
    '.dsk': 'appleii',
    # Coleco
    '.ddp': 'coleco', '.col': 'coleco',
    # DOS/PC
    '.ima': 'dos', '.vfd': 'dos', '.psi': 'dos', '.cqm': 'dos',
    '.360': 'dos', '.720': 'dos', '.144': 'dos', '.vhd': 'dos',
    '.hdi': 'dos', '.fdd': 'dos', '.hdm': 'dos', '.2hd': 'dos',
    '.86f': 'dos', '.nhd': 'dos', '.cp2': 'dos', '.cfi': 'dos',
    '.dxp': 'dos', '.88d': 'dos',
    # MSX
    '.d88': 'msx', '.1dd': 'msx', '.2dd': 'msx',
    # ZX Spectrum
    '.tzx':  'spectrum', '.trd':  'spectrum', '.scl': 'spectrum',
    '.pzx':  'spectrum', '.mgt':  'spectrum', '.opd': 'spectrum',
    '.sad':  'spectrum', '.tfd':  'spectrum', '.edsk': 'spectrum',
    # TRS-80
    '.jv1': 'trs80', '.jv3':  'trs80', '.jvc':  'trs80',
    '.tpdd': 'trs80', '.h8d': 'trs80', '.cmd':  'trs80',
    # Other / flux / preservation
    '.hfe':   'other', '.mfi': 'other', '.ufi':   'other',
    '.dfi':   'other', '.mfm': 'other', '.gcr':   'other',
    '.kfraw': 'other', '.wav': 'other', '.cdt':   'other',
    '.slt':   'other', '.sav': 'other', '.dup':   'other',
    '.scp':   'other', '.raw': 'other', '.cpm':   'other',
}

# Ambiguous extensions: multiple modules claim them
# Key → list of candidate modules (first = most common)
_AMBIGUOUS = {
    '.nib': ['commodore', 'appleii'],
    # .dsk handled unambiguously above (defaults to appleii; use --format to override)
    '.img': ['dos', 'mac'],
    '.fdi': ['amiga', 'msx', 'dos'],
    '.cas': ['atari', 'msx', 'other'],
    '.dim': ['atari', 'dos'],
    '.tap': ['commodore', 'spectrum'],
    '.dmk': ['trs80', 'dos'],
    '.vdk': ['trs80', 'other'],
    '.sdf': ['trs80', 'other'],
    '.imd': ['dos', 'trs80'],
    '.td0': ['dos', 'trs80'],
    '.bin': ['console'],
    '.cue': ['console'],
    '.mds': ['console'],
    '.rom': ['coleco', 'other'],
}


def _load_module(module_name: str):
    path = _TOOLS_DIR / f'diskimage-{module_name}.py'
    if not path.exists():
        sys.exit(f'Sub-module not found: {path}\nPlease ensure all diskimage-*.py files are present.')
    spec = importlib.util.spec_from_file_location(f'diskimage_{module_name}', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _detect_magic(path: Path) -> str | None:
    """Identify ambiguous extensions using file magic / content heuristics."""
    try:
        header = path.read_bytes()[:16]
    except OSError:
        return None
    ext = path.suffix.lower()
    # Commodore TAP: starts with "C64-TAPE-RAW"
    if ext == '.tap' and header[:12] == b'C64-TAPE-RAW':
        return 'commodore'
    if ext == '.tap':
        return 'spectrum'
    # Apple DOS 3.3 DSK: 143360 bytes, byte at 0x11203 == 3 (VTOC DOS version)
    if ext == '.dsk':
        try:
            data = path.read_bytes()
            if len(data) == 143360 and data[0x11203] == 3:
                return 'appleii'
        except Exception:
            pass
    # Amiga ADF: 901120 bytes or starts with "DOS" identifier (OFS/FFS)
    if ext == '.fdi' and len(header) >= 4 and header[:3] == b'FDI':
        return 'amiga'
    return None


def _resolve_module(path: Path, format_hint: str) -> tuple:
    """Return (module_name, format_key_hint_or_None)."""
    if format_hint:
        fh = format_hint.lower()
        # Module name given directly
        if fh in _VALID_MODULES:
            return fh, None
        # Format key given — find which module owns it
        for mod_name in _VALID_MODULES:
            mod = _load_module(mod_name)
            if hasattr(mod, 'FORMATS') and fh in mod.FORMATS:
                return mod_name, fh
        sys.exit(
            f'Unknown format or module: {format_hint!r}\n'
            f'Modules: {", ".join(sorted(_VALID_MODULES))}'
        )

    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext], None

    if ext in _AMBIGUOUS:
        candidates = _AMBIGUOUS[ext]
        guessed = _detect_magic(path)
        if guessed:
            return guessed, None
        if len(candidates) == 1:
            return candidates[0], None
        opts = '|'.join(candidates)
        sys.exit(
            f'Ambiguous extension {ext!r} — could be: {", ".join(candidates)}\n'
            f'Specify: --format {opts}\n'
            f'  Example: diskimage.py --format {candidates[0]} list {path.name}'
        )

    sys.exit(
        f'Unknown extension {ext!r}.\n'
        f'Use --format MODULE or --format FORMAT_KEY.\n'
        f'Modules: {", ".join(sorted(_VALID_MODULES))}'
    )


def main() -> None:
    ap = argparse.ArgumentParser(
        description='Retro disk image tool — auto-routes to format sub-module.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('--format', dest='fmt', metavar='FMT',
                    help='Format key (d64, atr, adf, ...) or module name '
                         '(commodore, atari, appleii, amiga, mac, console, '
                         'coleco, dos, msx, spectrum, trs80, other)')
    sub = ap.add_subparsers(dest='command', required=True)

    pc = sub.add_parser('create', help='Create a new blank disk image')
    pc.add_argument('image', help='Output path (extension determines format)')
    pc.add_argument('--name', default='NEW DISK', help='Disk label / volume name')

    pl = sub.add_parser('list', help='List files in a disk image')
    pl.add_argument('image', help='Disk image path')

    pa = sub.add_parser('add', help='Add a file to a disk image')
    pa.add_argument('image', help='Disk image path')
    pa.add_argument('file',  help='Source file to add')
    pa.add_argument('--name', help='Filename on disk (default: source stem)')
    pa.add_argument('--type', default='prg',
                    help='File type: prg/seq/usr (D64), bin (others) [default: prg]')

    pr = sub.add_parser('remove', help='Remove a file from a disk image')
    pr.add_argument('image', help='Disk image path')
    pr.add_argument('name',  help='Filename to remove')

    args = ap.parse_args()
    img_path = Path(args.image)
    mod_name, fmt_key = _resolve_module(img_path, args.fmt)
    mod = _load_module(mod_name)

    try:
        fmt = mod.detect(img_path, fmt_key)
    except ValueError as e:
        sys.exit(f'Error: {e}')

    try:
        if args.command == 'create':
            img = mod.create(fmt, args.name)
            img.save(img_path)
            print(f'Created {fmt.upper()} image: {img_path}')

        elif args.command == 'list':
            img = mod.load(img_path, fmt)
            files = img.list_files()
            if not files:
                print('(empty disk)')
                return
            for ftype, name, size in files:
                if ftype == 'HEADER':
                    print(f'  0  "{name}"')
                    print()
                else:
                    print(f'  {size:4d}  {ftype:<6}  "{name}"')
            data_files = [(t, n, s) for t, n, s in files if t != 'HEADER']
            if data_files:
                print(f'\n  {sum(s for _, _, s in data_files)} BLOCKS/SECTORS USED')

        elif args.command == 'add':
            src = Path(args.file)
            if not src.exists():
                sys.exit(f'Source file not found: {src}')
            img = mod.load(img_path, fmt)
            name = args.name or src.stem.upper()
            img.add_file(src.read_bytes(), name, args.type)
            img.save(img_path)
            print(f'Added "{name}" ({src.stat().st_size} bytes) to {img_path}')

        elif args.command == 'remove':
            img = mod.load(img_path, fmt)
            if not img.remove_file(args.name.upper()):
                sys.exit(f'File not found on disk: {args.name}')
            img.save(img_path)
            print(f'Removed "{args.name.upper()}" from {img_path}')

    except NotImplementedError as e:
        sys.exit(f'Not implemented: {e}')
    except (RuntimeError, ValueError, OSError) as e:
        sys.exit(f'Error: {e}')


if __name__ == '__main__':
    main()
