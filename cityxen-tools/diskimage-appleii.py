#!/usr/bin/env python3
"""
diskimage-appleii.py — Apple II disk image handler.

Fully implemented: dsk / do (Apple DOS 3.3)
                   po / hdv (ProDOS)
                   2mg (container wrapping dsk or po)
                   nib (nibblized, read-only listing)
Stubs: woz a2r edd sdk
"""

import struct
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# DSK — Apple DOS 3.3 disk image  (DOS-ordered, 143360 bytes)
# ---------------------------------------------------------------------------

_DSK_TRACKS      = 35
_DSK_SECTORS     = 16
_DSK_SEC_SIZE    = 256
_DSK_SIZE        = _DSK_TRACKS * _DSK_SECTORS * _DSK_SEC_SIZE  # 143360
_DSK_VTOC_TRACK  = 17
_DSK_VTOC_SEC    = 0
_DSK_DIR_TRACK   = 17
_DSK_DIR_FIRST_S = 15

# DOS-sector to ProDOS-sector interleave conversion (within each track).
# Derived from physical sector interleave tables for DOS 3.3 and ProDOS:
#   DOS logical → physical (inverse of PHYS_TO_DOS) → ProDOS logical.
_DO_TO_PO = [0, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 15]


def _dsk_offset(track: int, sector: int) -> int:
    return (track * _DSK_SECTORS + sector) * _DSK_SEC_SIZE


class DSKImage:
    def __init__(self, data: bytearray):
        self.data = data

    @classmethod
    def create(cls, disk_name: str = 'NEW DISK', volume: int = 254, **kw) -> 'DSKImage':
        data = bytearray(_DSK_SIZE)
        img = cls(data)
        img._init_vtoc(volume)
        return img

    @classmethod
    def load(cls, path: Path) -> 'DSKImage':
        data = bytearray(path.read_bytes())
        if len(data) != _DSK_SIZE:
            raise ValueError(f'Expected {_DSK_SIZE} bytes for DSK, got {len(data)}.')
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def _read_sec(self, track: int, sector: int) -> bytearray:
        off = _dsk_offset(track, sector)
        return bytearray(self.data[off:off + _DSK_SEC_SIZE])

    def _write_sec(self, track: int, sector: int, buf: bytearray) -> None:
        off = _dsk_offset(track, sector)
        self.data[off:off + _DSK_SEC_SIZE] = buf[:_DSK_SEC_SIZE]

    def _init_vtoc(self, volume: int) -> None:
        vtoc = bytearray(_DSK_SEC_SIZE)
        vtoc[0x01] = _DSK_DIR_TRACK
        vtoc[0x02] = _DSK_DIR_FIRST_S
        vtoc[0x03] = 3
        vtoc[0x06] = volume
        vtoc[0x27] = 122                             # max T/S pairs per sector
        vtoc[0x34] = _DSK_TRACKS                     # tracks per disk (35)
        vtoc[0x35] = _DSK_SECTORS                    # sectors per track (16)
        vtoc[0x36] = _DSK_SEC_SIZE & 0xFF            # bytes per sector lo
        vtoc[0x37] = (_DSK_SEC_SIZE >> 8) & 0xFF     # bytes per sector hi
        for t in range(_DSK_TRACKS):
            free_bits = 0xFFFF
            if t == _DSK_DIR_TRACK:
                for s in range(_DSK_DIR_FIRST_S + 1):
                    free_bits &= ~(1 << s)
            base = 0x38 + t * 4
            vtoc[base]   = (free_bits >> 8) & 0xFF
            vtoc[base+1] = free_bits & 0xFF
        dir_sec = bytearray(_DSK_SEC_SIZE)
        self._write_sec(_DSK_DIR_TRACK, _DSK_DIR_FIRST_S, dir_sec)
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _vtoc_is_free(self, track: int, sector: int) -> bool:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base + 1]
        return bool(bits & (1 << sector))

    def _vtoc_alloc(self, track: int, sector: int) -> None:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base + 1]
        bits &= ~(1 << sector)
        vtoc[base]   = (bits >> 8) & 0xFF
        vtoc[base+1] = bits & 0xFF
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _vtoc_free_sec(self, track: int, sector: int) -> None:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base + 1]
        bits |= (1 << sector)
        vtoc[base]   = (bits >> 8) & 0xFF
        vtoc[base+1] = bits & 0xFF
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _find_free_sector(self) -> tuple:
        # Match AppleCommander: lowest track first (skip catalog track 17),
        # sectors ascending 0->15 within each track.
        for t in range(1, _DSK_TRACKS):
            if t == _DSK_DIR_TRACK:
                continue
            for s in range(_DSK_SECTORS):
                if self._vtoc_is_free(t, s):
                    return t, s
        raise RuntimeError('Disk full.')

    def _iter_dir_entries(self):
        t, s = _DSK_DIR_TRACK, _DSK_DIR_FIRST_S
        visited = set()
        while t:
            if t >= _DSK_TRACKS or s >= _DSK_SECTORS or (t, s) in visited:
                break
            visited.add((t, s))
            sec = self._read_sec(t, s)
            if len(sec) < 3:
                break
            next_t, next_s = sec[0x01], sec[0x02]
            for i in range(7):
                off = 0x0B + i * 0x23
                yield t, s, off, bytes(sec[off:off + 0x23])
            t = next_t if next_t else 0
            s = next_s

    def list_files(self) -> list:
        files = []
        type_names = {0x00: 'T', 0x01: 'I', 0x02: 'A', 0x04: 'B',
                      0x08: 'S', 0x10: 'R', 0x20: 'A', 0x40: 'B'}
        for _, _, _, entry in self._iter_dir_entries():
            track = entry[0x00]
            if track in (0x00, 0xFF):
                continue
            ftype = entry[0x02]
            name = ''.join(chr(b & 0x7F) for b in entry[0x03:0x21]).rstrip()
            sectors = entry[0x21] | (entry[0x22] << 8)
            tname = type_names.get(ftype & 0x7F, f'${ftype:02X}')
            locked = '*' if ftype & 0x80 else ' '
            files.append((tname + locked, name, sectors))
        return files

    def add_file(self, file_data: bytes, apple_name: str, file_type: str = 'bin', addr: int = 0) -> None:
        type_codes = {'t': 0x00, 'i': 0x01, 'a': 0x02, 'b': 0x04, 's': 0x08, 'bin': 0x04}
        ftype_byte = type_codes.get(file_type.lower(), 0x04)
        # Prepend the type-specific on-disk header, matching AppleCommander:
        if ftype_byte == 0x04:
            # Binary (B): 4-byte [load_addr_lo, load_addr_hi, len_lo, len_hi]
            hdr = bytes([addr & 0xFF, (addr >> 8) & 0xFF,
                         len(file_data) & 0xFF, (len(file_data) >> 8) & 0xFF])
            file_data = hdr + file_data
        elif ftype_byte in (0x01, 0x02):
            # Integer (I) / Applesoft (A): 2-byte little-endian length header
            hdr = bytes([len(file_data) & 0xFF, (len(file_data) >> 8) & 0xFF])
            file_data = hdr + file_data
        elif ftype_byte == 0x00:
            # Text (T): set the high bit on every byte (ASCII -> Apple II text)
            file_data = bytes((b | 0x80) for b in file_data)
        # Sequential (S, 0x08) and anything else: stored raw, no header
        dir_t = dir_s = dir_off = None
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0x00] in (0x00, 0xFF):
                dir_t, dir_s, dir_off = dt, ds, doff
                break
        if dir_t is None:
            raise RuntimeError('Directory full.')
        tsl_t, tsl_s = self._find_free_sector()
        self._vtoc_alloc(tsl_t, tsl_s)
        tsl = bytearray(_DSK_SEC_SIZE)
        chunks = [file_data[i:i + _DSK_SEC_SIZE] for i in range(0, max(1, len(file_data)), _DSK_SEC_SIZE)]
        tsl_entries = []
        for chunk in chunks:
            ft, fs = self._find_free_sector()
            self._vtoc_alloc(ft, fs)
            sec = bytearray(_DSK_SEC_SIZE)
            sec[:len(chunk)] = chunk
            self._write_sec(ft, fs, sec)
            tsl_entries.append((ft, fs))
        # TSL bytes 0x05-0x06 = file-relative sector offset of the first
        # sector in this list.  For the single TSL we emit, that is 0
        # (matches AppleCommander).
        tsl[0x05] = 0
        tsl[0x06] = 0
        for i, (ft, fs) in enumerate(tsl_entries):
            base = 0x0C + i * 2
            tsl[base], tsl[base+1] = ft, fs
        self._write_sec(tsl_t, tsl_s, tsl)
        dir_sec = self._read_sec(dir_t, dir_s)
        entry = bytearray(0x23)
        entry[0x00], entry[0x01] = tsl_t, tsl_s
        entry[0x02] = ftype_byte
        name_str = (apple_name + ' ' * 30)[:30]
        for i, c in enumerate(name_str):
            entry[0x03 + i] = (ord(c) | 0x80) & 0xFF
        total = len(tsl_entries) + 1
        entry[0x21], entry[0x22] = total & 0xFF, (total >> 8) & 0xFF
        dir_sec[dir_off:dir_off + 0x23] = entry
        self._write_sec(dir_t, dir_s, dir_sec)

    def remove_file(self, apple_name: str) -> bool:
        target = apple_name.upper().rstrip()
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0x00] in (0x00, 0xFF):
                continue
            name = ''.join(chr(b & 0x7F) for b in entry[0x03:0x21]).rstrip().upper()
            if name == target:
                tsl = self._read_sec(entry[0x00], entry[0x01])
                for i in range((0xFE - 0x0C) // 2):
                    base = 0x0C + i * 2
                    ft, fs = tsl[base], tsl[base+1]
                    if ft == 0 and fs == 0:
                        break
                    self._vtoc_free_sec(ft, fs)
                self._vtoc_free_sec(entry[0x00], entry[0x01])
                dir_sec = self._read_sec(dt, ds)
                # DOS 3.3 delete: copy the file's first track byte into the
                # last byte of the name field (for undelete), then mark the
                # entry deleted with $FF.  Matches AppleCommander.
                dir_sec[doff + 0x20] = entry[0x00]
                dir_sec[doff] = 0xFF
                self._write_sec(dt, ds, dir_sec)
                return True
        return False


# ---------------------------------------------------------------------------
# PO — Apple ProDOS block-ordered disk image
# ---------------------------------------------------------------------------
# Block layout:
#   0-1:  boot/loader (reserved)
#   2-5:  volume directory (4 blocks, 51 file slots)
#   6+:   volume bitmap (1 block per 4096 blocks of volume)
#   then: data blocks
#
# Block size: 512 bytes.  Standard floppy: 280 blocks = 143,360 bytes.

_PO_BLOCK_SIZE    = 512
_PO_STD_BLOCKS    = 280
_PO_STD_SIZE      = _PO_STD_BLOCKS * _PO_BLOCK_SIZE  # 143,360

_PO_VOLDIR_BLOCK  = 2
_PO_VOLDIR_BLOCKS = 4     # key block + 3 continuation → 51 file entry slots
_PO_BITMAP_BLOCK  = 6     # first (and usually only) bitmap block
_PO_DATA_START    = 7     # first usable data block for std 280-block volume

_PO_ENTRY_SIZE    = 39
_PO_ENTRIES_PER   = 13   # entries per directory block

_PO_STOR_INACTIVE = 0x0
_PO_STOR_SEED     = 0x1   # seedling: 0–512 bytes, 1 data block
_PO_STOR_SAP      = 0x2   # sapling: 513–131072 bytes, index + data blocks
_PO_STOR_TREE     = 0x3   # tree: > 128KB
_PO_STOR_SUBDIR   = 0xD
_PO_STOR_VOLHDR   = 0xF

_PO_FILE_TYPES = {
    0x00: 'UNK', 0x01: 'BAD', 0x04: 'TXT', 0x06: 'BIN',
    0x0F: 'DIR', 0x19: 'ADB', 0xFA: 'INT', 0xFC: 'BAS',
    0xFE: 'REL', 0xFF: 'SYS',
}
_PO_TYPE_CODES = {
    'bin': 0x06, 'txt': 0x04, 'bas': 0xFC,
    'sys': 0xFF, 'int': 0xFA, 'rel': 0xFE,
}


class POImage:
    def __init__(self, data: bytearray):
        self.data = data

    # --- factories ---

    @classmethod
    def create(cls, disk_name: str = 'PRODOS', total_blocks: int = _PO_STD_BLOCKS, **kw) -> 'POImage':
        data = bytearray(total_blocks * _PO_BLOCK_SIZE)
        img  = cls(data)
        img._init_voldir(disk_name, total_blocks)
        img._init_bitmap(total_blocks)
        return img

    @classmethod
    def load(cls, path: Path) -> 'POImage':
        data = bytearray(path.read_bytes())
        if len(data) % _PO_BLOCK_SIZE != 0:
            raise ValueError(f'{path.name}: size {len(data)} not a multiple of 512.')
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    # --- block I/O ---

    def _read_blk(self, blk: int) -> bytearray:
        off = blk * _PO_BLOCK_SIZE
        return bytearray(self.data[off:off + _PO_BLOCK_SIZE])

    def _write_blk(self, blk: int, buf: bytearray) -> None:
        off = blk * _PO_BLOCK_SIZE
        self.data[off:off + _PO_BLOCK_SIZE] = buf[:_PO_BLOCK_SIZE]

    def _total_blocks(self) -> int:
        return len(self.data) // _PO_BLOCK_SIZE

    # --- bitmap ---

    def _bitmap_blocks(self) -> int:
        return max(1, (self._total_blocks() + 4095) // 4096)

    def _data_start(self) -> int:
        return _PO_BITMAP_BLOCK + self._bitmap_blocks()

    def _bm_read(self) -> bytearray:
        # Concatenate all bitmap blocks into one buffer
        bm = bytearray()
        for i in range(self._bitmap_blocks()):
            bm += self._read_blk(_PO_BITMAP_BLOCK + i)
        return bm

    def _bm_write(self, bm: bytearray) -> None:
        for i in range(self._bitmap_blocks()):
            off = i * _PO_BLOCK_SIZE
            self._write_blk(_PO_BITMAP_BLOCK + i, bytearray(bm[off:off + _PO_BLOCK_SIZE]))

    def _bm_is_free(self, bm: bytearray, blk: int) -> bool:
        return bool(bm[blk >> 3] & (0x80 >> (blk & 7)))

    def _bm_set_used(self, bm: bytearray, blk: int) -> None:
        bm[blk >> 3] &= ~(0x80 >> (blk & 7))

    def _bm_set_free(self, bm: bytearray, blk: int) -> None:
        bm[blk >> 3] |= (0x80 >> (blk & 7))

    def _find_free_block(self, bm: bytearray, start: int = None) -> int:
        if start is None:
            start = self._data_start()
        total = self._total_blocks()
        for b in range(start, total):
            if self._bm_is_free(bm, b):
                return b
        raise RuntimeError('Disk full — no free ProDOS blocks.')

    def free_blocks(self) -> int:
        bm    = self._bm_read()
        total = self._total_blocks()
        return sum(1 for b in range(total) if self._bm_is_free(bm, b))

    # --- init ---

    def _init_bitmap(self, total_blocks: int) -> None:
        bm_bytes = (total_blocks + 7) // 8
        bm = bytearray(self._bitmap_blocks() * _PO_BLOCK_SIZE)
        # Mark all blocks as free (bit=1)
        for b in range(total_blocks):
            bm[b >> 3] |= (0x80 >> (b & 7))
        # Mark reserved/system blocks as used
        reserved = (list(range(_PO_VOLDIR_BLOCK + _PO_VOLDIR_BLOCKS)) +
                    list(range(_PO_BITMAP_BLOCK, self._data_start())))
        for b in reserved:
            if b < total_blocks:
                bm[b >> 3] &= ~(0x80 >> (b & 7))
        self._bm_write(bm)

    def _init_voldir(self, vol_name: str, total_blocks: int) -> None:
        name = vol_name.upper()[:15]
        # Key block
        key = bytearray(_PO_BLOCK_SIZE)
        key[2] = (_PO_VOLDIR_BLOCK + 1) & 0xFF
        key[3] = ((_PO_VOLDIR_BLOCK + 1) >> 8) & 0xFF
        # Volume header entry at offset 4
        hdr = bytearray(_PO_ENTRY_SIZE)
        hdr[0]     = (_PO_STOR_VOLHDR << 4) | len(name)
        for i, c in enumerate(name):
            hdr[1 + i] = ord(c)
        hdr[28] = 0x00                             # version
        hdr[29] = 0x00                             # min_version
        hdr[30] = 0xC3                             # access: read/write/destroy/rename/backup
        hdr[31] = _PO_ENTRY_SIZE                   # entry_length = 39
        hdr[32] = _PO_ENTRIES_PER                  # entries_per_block = 13
        hdr[33] = 0; hdr[34] = 0                   # file_count = 0
        hdr[35] = _PO_BITMAP_BLOCK & 0xFF          # bit_map_pointer lo
        hdr[36] = (_PO_BITMAP_BLOCK >> 8) & 0xFF   # bit_map_pointer hi
        hdr[37] = total_blocks & 0xFF              # total_blocks lo
        hdr[38] = (total_blocks >> 8) & 0xFF       # total_blocks hi
        key[4:4 + _PO_ENTRY_SIZE] = hdr
        self._write_blk(_PO_VOLDIR_BLOCK, key)
        # Continuation directory blocks
        for i in range(1, _PO_VOLDIR_BLOCKS):
            blk = _PO_VOLDIR_BLOCK + i
            buf = bytearray(_PO_BLOCK_SIZE)
            prev_blk = blk - 1
            next_blk = blk + 1 if i < _PO_VOLDIR_BLOCKS - 1 else 0
            buf[0] = prev_blk & 0xFF; buf[1] = (prev_blk >> 8) & 0xFF
            buf[2] = next_blk & 0xFF; buf[3] = (next_blk >> 8) & 0xFF
            self._write_blk(blk, buf)

    # --- directory iteration ---

    def _iter_dir(self):
        blk = _PO_VOLDIR_BLOCK
        while blk:
            buf = self._read_blk(blk)
            if len(buf) < 4:
                break
            next_blk = buf[2] | (buf[3] << 8)
            for i in range(_PO_ENTRIES_PER):
                off = 4 + i * _PO_ENTRY_SIZE
                yield blk, off, bytes(buf[off:off + _PO_ENTRY_SIZE])
            blk = next_blk

    # --- volume header helpers ---

    def _read_volhdr(self) -> bytearray:
        return bytearray(self._read_blk(_PO_VOLDIR_BLOCK)[4:4 + _PO_ENTRY_SIZE])

    def _write_volhdr(self, hdr: bytearray) -> None:
        buf = bytearray(self._read_blk(_PO_VOLDIR_BLOCK))
        buf[4:4 + _PO_ENTRY_SIZE] = hdr[:_PO_ENTRY_SIZE]
        self._write_blk(_PO_VOLDIR_BLOCK, buf)

    def _incr_file_count(self, delta: int) -> None:
        hdr   = self._read_volhdr()
        count = (hdr[33] | (hdr[34] << 8)) + delta
        hdr[33] = max(0, count) & 0xFF
        hdr[34] = (max(0, count) >> 8) & 0xFF
        self._write_volhdr(hdr)

    # --- public interface ---

    def list_files(self) -> list:
        hdr      = self._read_volhdr()
        name_len = hdr[0] & 0x0F
        vol_name = hdr[1:1 + name_len].decode('ascii', 'replace')
        files    = [('HEADER', vol_name, self.free_blocks())]
        for _, _, entry in self._iter_dir():
            stor = (entry[0] >> 4) & 0xF
            if stor in (_PO_STOR_INACTIVE, _PO_STOR_VOLHDR):
                continue
            name_len = entry[0] & 0x0F
            name     = entry[1:1 + name_len].decode('ascii', 'replace')
            ftype    = _PO_FILE_TYPES.get(entry[16], f'${entry[16]:02X}')
            blocks   = entry[19] | (entry[20] << 8)
            files.append((ftype, name, blocks))
        return files

    def add_file(self, file_data: bytes, prodos_name: str, file_type: str = 'bin') -> None:
        name = prodos_name.upper()[:15]
        if not name:
            raise ValueError('ProDOS name cannot be empty.')
        ftype_byte = _PO_TYPE_CODES.get(file_type.lower(), 0x06)

        # Find a free directory slot
        dir_blk = dir_off = None
        for blk, off, entry in self._iter_dir():
            if (entry[0] >> 4) == _PO_STOR_INACTIVE:
                dir_blk, dir_off = blk, off
                break
        if dir_blk is None:
            raise RuntimeError('ProDOS directory full.')

        bm           = self._bm_read()
        n_data       = (len(file_data) + _PO_BLOCK_SIZE - 1) // _PO_BLOCK_SIZE
        storage_type = _PO_STOR_SEED if n_data <= 1 else _PO_STOR_SAP
        if n_data > 256:
            raise RuntimeError('File too large for sapling (max 131072 bytes).')

        if storage_type == _PO_STOR_SEED:
            key_blk = self._find_free_block(bm)
            self._bm_set_used(bm, key_blk)
            sec = bytearray(_PO_BLOCK_SIZE)
            sec[:len(file_data)] = file_data
            self._write_blk(key_blk, sec)
            blocks_used = max(1, n_data)
        else:
            # Allocate index block
            idx_blk = self._find_free_block(bm)
            self._bm_set_used(bm, idx_blk)
            idx = bytearray(_PO_BLOCK_SIZE)
            data_blocks = []
            for i in range(n_data):
                db = self._find_free_block(bm)
                self._bm_set_used(bm, db)
                chunk = file_data[i * _PO_BLOCK_SIZE:(i + 1) * _PO_BLOCK_SIZE]
                sec = bytearray(_PO_BLOCK_SIZE)
                sec[:len(chunk)] = chunk
                self._write_blk(db, sec)
                data_blocks.append(db)
                idx[i]       = db & 0xFF
                idx[i + 256] = (db >> 8) & 0xFF
            self._write_blk(idx_blk, idx)
            key_blk     = idx_blk
            blocks_used = n_data + 1

        self._bm_write(bm)

        # Write directory entry
        e = bytearray(_PO_ENTRY_SIZE)
        e[0]  = (storage_type << 4) | len(name)
        for i, c in enumerate(name):
            e[1 + i] = ord(c)
        e[16] = ftype_byte
        e[17] = key_blk & 0xFF;      e[18] = (key_blk >> 8) & 0xFF
        e[19] = blocks_used & 0xFF;  e[20] = (blocks_used >> 8) & 0xFF
        eof   = len(file_data)
        e[21] = eof & 0xFF;   e[22] = (eof >> 8) & 0xFF;  e[23] = (eof >> 16) & 0xFF
        e[28] = 0x00;         e[30] = 0xC3
        e[37] = _PO_VOLDIR_BLOCK & 0xFF
        e[38] = (_PO_VOLDIR_BLOCK >> 8) & 0xFF
        buf = bytearray(self._read_blk(dir_blk))
        buf[dir_off:dir_off + _PO_ENTRY_SIZE] = e
        self._write_blk(dir_blk, buf)
        self._incr_file_count(+1)

    def remove_file(self, prodos_name: str) -> bool:
        target = prodos_name.upper()[:15]
        for blk, off, entry in self._iter_dir():
            stor = (entry[0] >> 4) & 0xF
            if stor in (_PO_STOR_INACTIVE, _PO_STOR_VOLHDR):
                continue
            name_len = entry[0] & 0x0F
            fname    = entry[1:1 + name_len].decode('ascii', 'replace').upper()
            if fname != target:
                continue
            key_blk  = entry[17] | (entry[18] << 8)
            blocks   = entry[19] | (entry[20] << 8)
            bm = self._bm_read()
            if stor == _PO_STOR_SEED:
                if key_blk:
                    self._bm_set_free(bm, key_blk)
            elif stor == _PO_STOR_SAP:
                idx = self._read_blk(key_blk)
                n_data = max(0, blocks - 1)
                for i in range(min(n_data, 256)):
                    db = idx[i] | (idx[i + 256] << 8)
                    if db:
                        self._bm_set_free(bm, db)
                self._bm_set_free(bm, key_blk)
            self._bm_write(bm)
            # Mark entry inactive
            buf     = bytearray(self._read_blk(blk))
            buf[off] = 0x00
            self._write_blk(blk, buf)
            self._incr_file_count(-1)
            return True
        return False


# ---------------------------------------------------------------------------
# HDV — Apple IIgs ProDOS hard disk volume (same as PO, larger default)
# ---------------------------------------------------------------------------

_HDV_DEFAULT_BLOCKS = 65535   # ~32MB (ProDOS max)
_HDV_DEFAULT_SIZE   = _HDV_DEFAULT_BLOCKS * _PO_BLOCK_SIZE


class HDVImage(POImage):
    @classmethod
    def create(cls, disk_name: str = 'HARDDISK', total_blocks: int = _HDV_DEFAULT_BLOCKS, **kw) -> 'HDVImage':
        data = bytearray(total_blocks * _PO_BLOCK_SIZE)
        img  = cls(data)
        img._init_voldir(disk_name, total_blocks)
        img._init_bitmap(total_blocks)
        return img

    @classmethod
    def load(cls, path: Path) -> 'HDVImage':
        data = bytearray(path.read_bytes())
        if len(data) % _PO_BLOCK_SIZE != 0:
            raise ValueError(f'{path.name}: size not a multiple of 512.')
        return cls(data)


# ---------------------------------------------------------------------------
# DO-PO — DOS-sector-ordered disk image containing a ProDOS filesystem
# ---------------------------------------------------------------------------
# Apple II disk images with a .dsk extension are usually DOS-sector-ordered,
# but the ProDOS filesystem uses a different physical interleave.  Many tools
# (including ip65) ship ProDOS disks in DOS order with a .dsk extension.
# This class converts sector ordering in memory so POImage logic works.

def _dsk_to_po(data: bytes) -> bytearray:
    """Convert a DOS-sector-ordered image to ProDOS-block-ordered in memory."""
    out = bytearray(len(data))
    for t in range(_DSK_TRACKS):
        for s in range(_DSK_SECTORS):
            src = (t * _DSK_SECTORS + s) * _DSK_SEC_SIZE
            dst = (t * _DSK_SECTORS + _DO_TO_PO[s]) * _DSK_SEC_SIZE
            out[dst:dst + _DSK_SEC_SIZE] = data[src:src + _DSK_SEC_SIZE]
    return out


def _po_to_dsk(data: bytes) -> bytearray:
    """Convert a ProDOS-block-ordered image to DOS-sector-ordered in memory."""
    _PO_TO_DO = [_DO_TO_PO.index(i) for i in range(16)]
    out = bytearray(len(data))
    for t in range(_DSK_TRACKS):
        for po_s in range(_DSK_SECTORS):
            src = (t * _DSK_SECTORS + po_s) * _DSK_SEC_SIZE
            dst = (t * _DSK_SECTORS + _PO_TO_DO[po_s]) * _DSK_SEC_SIZE
            out[dst:dst + _DSK_SEC_SIZE] = data[src:src + _DSK_SEC_SIZE]
    return out


class PODOSImage(DSKImage):
    """DOS 3.3 disk stored in ProDOS sector ordering.

    The file bytes are in ProDOS block order (so .po-aware emulators like AppleWin
    apply the correct sector interleave and read the DOS 3.3 content correctly).
    Internally all DSKImage operations work on DOS-ordered data as usual; sector
    reordering happens only on load and save.
    """

    @classmethod
    def create(cls, disk_name: str = 'NEW DISK', volume: int = 254, **kw) -> 'PODOSImage':
        img = DSKImage.create(disk_name, volume)
        return cls(img.data)

    @classmethod
    def load(cls, path: Path) -> 'PODOSImage':
        raw = path.read_bytes()
        if len(raw) != _DSK_SIZE:
            raise ValueError(f'Expected {_DSK_SIZE} bytes for DOS 3.3 image, got {len(raw)}.')
        # The .po file always stores sectors in ProDOS block order (even for DOS 3.3 content).
        # Convert PO→DOS for internal DSKImage operations; save() converts DOS→PO back.
        return cls(_po_to_dsk(raw))

    def save(self, path: Path) -> None:
        # Convert from DOS ordering (internal) to PO sector ordering (as stored)
        path.write_bytes(_dsk_to_po(self.data))


class DOPOImage(POImage):
    """DOS-sector-ordered 143360-byte image containing a ProDOS filesystem."""

    @classmethod
    def create(cls, disk_name: str = 'PRODOS', **kw) -> 'DOPOImage':
        po = POImage.create(disk_name)
        img = cls(_po_to_dsk(po.data))
        return img

    @classmethod
    def load(cls, path: Path) -> 'DOPOImage':
        raw = path.read_bytes()
        if len(raw) != _DSK_SIZE:
            raise ValueError(f'Expected {_DSK_SIZE} bytes for DOS-order ProDOS image, got {len(raw)}.')
        return cls(_dsk_to_po(raw))

    def save(self, path: Path) -> None:
        path.write_bytes(_po_to_dsk(self.data))


# ---------------------------------------------------------------------------
# NIB — Apple II nibblized disk image (read-only, GCR decoded to DOS 3.3)
# ---------------------------------------------------------------------------
# 35 tracks × 6656 bytes = 232,960 bytes total.
# Each track contains raw GCR nibble data.  We decode it to DSKImage format
# so the existing DOS 3.3 directory logic can do the listing.

_NIB_TRACK_SIZE    = 6656
_NIB_SIZE          = _DSK_TRACKS * _NIB_TRACK_SIZE  # 232,960

# Physical→logical sector table for DOS 3.3
_NIB_PHYS_TO_LOG = [0, 7, 14, 6, 13, 5, 12, 4, 11, 3, 10, 2, 9, 1, 8, 15]

# 6-and-2 GCR decode table: maps disk byte → 6-bit value (-1 = invalid)
_NIB_GCR_DEC = [-1] * 256
for _i, _v in enumerate([
    0x96,0x97,0x9A,0x9B,0x9D,0x9E,0x9F,0xA6,
    0xA7,0xAB,0xAC,0xAD,0xAE,0xAF,0xB2,0xB3,
    0xB4,0xB5,0xB6,0xB7,0xB9,0xBA,0xBB,0xBC,
    0xBD,0xBE,0xBF,0xCB,0xCD,0xCE,0xCF,0xD3,
    0xD6,0xD7,0xD9,0xDA,0xDB,0xDC,0xDD,0xDE,
    0xDF,0xE5,0xE6,0xE7,0xE9,0xEA,0xEB,0xEC,
    0xED,0xEE,0xEF,0xF2,0xF3,0xF4,0xF5,0xF6,
    0xF7,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFF,
]):
    _NIB_GCR_DEC[_v] = _i


def _nib_decode_odd_even(b1: int, b2: int) -> int:
    return ((b1 & 0x55) << 1) | (b2 & 0x55)


def _nib_decode_track(track_num: int, nibbles: bytes) -> dict:
    """Decode one NIB track; return {phys_sector: 256-byte bytearray}."""
    sectors = {}
    n = len(nibbles)
    pos = 0
    max_iter = n * 2  # allow wrap-around once

    for _ in range(max_iter):
        if len(sectors) == _DSK_SECTORS:
            break

        # Find address prologue D5 AA 96
        prolog_found = False
        for _ in range(n):
            if (nibbles[pos % n] == 0xD5 and
                    nibbles[(pos + 1) % n] == 0xAA and
                    nibbles[(pos + 2) % n] == 0x96):
                pos = (pos + 3) % n
                prolog_found = True
                break
            pos = (pos + 1) % n
        if not prolog_found:
            break

        # Decode address field: volume, track, sector, checksum (8 nibbles)
        addr = [nibbles[(pos + i) % n] for i in range(8)]
        pos = (pos + 10) % n  # 8 address nibbles + 2 epilogue (DE AA)
        trk  = _nib_decode_odd_even(addr[2], addr[3])
        phys = _nib_decode_odd_even(addr[4], addr[5])
        if trk != track_num or phys >= _DSK_SECTORS or phys in sectors:
            continue

        # Find data prologue D5 AA AD (within next 40 nibbles)
        data_found = False
        for _ in range(40):
            if (nibbles[pos % n] == 0xD5 and
                    nibbles[(pos + 1) % n] == 0xAA and
                    nibbles[(pos + 2) % n] == 0xAD):
                pos = (pos + 3) % n
                data_found = True
                break
            pos = (pos + 1) % n
        if not data_found:
            continue

        # Read and GCR-decode 342 nibbles, XOR-unchain
        try:
            buf  = bytearray(342)
            prev = 0
            for i in range(342):
                v = _NIB_GCR_DEC[nibbles[(pos + i) % n]]
                if v < 0:
                    raise ValueError
                val    = v ^ prev
                buf[i] = val
                prev   = val
            pos = (pos + 343) % n  # 342 data + 1 checksum nibble
        except (ValueError, IndexError):
            continue

        # Reconstruct 256-byte sector from secondary (buf[0..85]) + primary (buf[86..341])
        sec_data = bytearray(256)
        for i in range(256):
            j     = i % 86
            shift = (i // 86) * 2
            low2  = (buf[j] >> shift) & 3
            sec_data[i] = (buf[86 + i] << 2) | low2

        sectors[phys] = sec_data

    return sectors


class NIBImage:
    def __init__(self, raw: bytes, dsk: DSKImage):
        self._raw = raw
        self._dsk = dsk

    @classmethod
    def create(cls, **kw) -> 'NIBImage':
        raise NotImplementedError('NIB: creating nibblized images is not supported.')

    @classmethod
    def load(cls, path: Path) -> 'NIBImage':
        raw = path.read_bytes()
        if len(raw) != _NIB_SIZE:
            raise ValueError(
                f'{path.name}: invalid NIB size {len(raw)} (expected {_NIB_SIZE})'
            )
        dsk_data = bytearray(_DSK_SIZE)
        for track in range(_DSK_TRACKS):
            nibbles  = raw[track * _NIB_TRACK_SIZE:(track + 1) * _NIB_TRACK_SIZE]
            sectors  = _nib_decode_track(track, nibbles)
            for phys, sec_data in sectors.items():
                log = _NIB_PHYS_TO_LOG[phys]
                off = (track * _DSK_SECTORS + log) * _DSK_SEC_SIZE
                dsk_data[off:off + _DSK_SEC_SIZE] = sec_data
        return cls(raw, DSKImage(dsk_data))

    def save(self, path: Path) -> None:
        raise NotImplementedError('NIB: writing nibblized images is not supported.')

    def list_files(self) -> list:
        return self._dsk.list_files()

    def add_file(self, *a, **kw) -> None:
        raise NotImplementedError('NIB: writing nibblized images is not supported.')

    def remove_file(self, *a, **kw) -> bool:
        raise NotImplementedError('NIB: writing nibblized images is not supported.')


# ---------------------------------------------------------------------------
# 2MG — Universal Apple II Image container
# ---------------------------------------------------------------------------
# 64-byte header + inner image (DOS 3.3, ProDOS, or NIB).
# image_type field: 0=DOS 3.3 order, 1=ProDOS block order, 2=NIB.

_TMG_MAGIC    = b'2IMG'
_TMG_HDR_SIZE = 64
_TMG_TYPE_DOS = 0
_TMG_TYPE_PO  = 1
_TMG_TYPE_NIB = 2


class TMGImage:
    def __init__(self, inner, img_type: int):
        self._inner    = inner
        self._img_type = img_type

    @classmethod
    def create(cls, disk_name: str = 'PRODOS', **kw) -> 'TMGImage':
        return cls(POImage.create(disk_name), _TMG_TYPE_PO)

    @classmethod
    def load(cls, path: Path) -> 'TMGImage':
        raw = path.read_bytes()
        if len(raw) < _TMG_HDR_SIZE or raw[:4] != _TMG_MAGIC:
            raise ValueError(f'{path.name}: not a valid 2MG file (bad magic).')
        img_type = struct.unpack_from('<I', raw, 12)[0]
        data_off = struct.unpack_from('<I', raw, 24)[0]
        data_len = struct.unpack_from('<I', raw, 28)[0]
        inner_data = bytearray(raw[data_off:data_off + data_len])
        if img_type == _TMG_TYPE_DOS:
            inner = DSKImage(inner_data)
        elif img_type == _TMG_TYPE_PO:
            inner = POImage(inner_data)
        elif img_type == _TMG_TYPE_NIB:
            if len(inner_data) != _NIB_SIZE:
                raise ValueError(f'{path.name}: embedded NIB has wrong size.')
            dsk_data = bytearray(_DSK_SIZE)
            for track in range(_DSK_TRACKS):
                nibs = inner_data[track * _NIB_TRACK_SIZE:(track + 1) * _NIB_TRACK_SIZE]
                for phys, sec in _nib_decode_track(track, nibs).items():
                    log = _NIB_PHYS_TO_LOG[phys]
                    off = (track * _DSK_SECTORS + log) * _DSK_SEC_SIZE
                    dsk_data[off:off + _DSK_SEC_SIZE] = sec
            inner = NIBImage(bytes(inner_data), DSKImage(dsk_data))
        else:
            raise ValueError(f'{path.name}: unknown 2MG image type {img_type}.')
        return cls(inner, img_type)

    def save(self, path: Path) -> None:
        inner_data = bytes(self._inner.data if hasattr(self._inner, 'data')
                           else self._inner._raw)
        num_blocks = len(inner_data) // _PO_BLOCK_SIZE
        hdr = bytearray(_TMG_HDR_SIZE)
        hdr[0:4]  = _TMG_MAGIC
        hdr[4:8]  = b'CXEN'
        struct.pack_into('<H', hdr, 8,  _TMG_HDR_SIZE)
        struct.pack_into('<H', hdr, 10, 1)
        struct.pack_into('<I', hdr, 12, self._img_type)
        struct.pack_into('<I', hdr, 20, num_blocks)
        struct.pack_into('<I', hdr, 24, _TMG_HDR_SIZE)
        struct.pack_into('<I', hdr, 28, len(inner_data))
        path.write_bytes(bytes(hdr) + inner_data)

    def list_files(self) -> list:     return self._inner.list_files()
    def add_file(self, d, n, t='bin'): self._inner.add_file(d, n, t)
    def remove_file(self, n) -> bool:  return self._inner.remove_file(n)


# ---------------------------------------------------------------------------
# Stubs for flux and compressed formats
# ---------------------------------------------------------------------------

def _make_stub(key, desc):
    class _Stub:
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
    _Stub.__name__ = key.upper().replace('.', '_') + 'Image'
    return _Stub


WOZImage = _make_stub('woz', 'Apple II WOZ Flux Image')
A2RImage = _make_stub('a2r', 'Applesauce Flux Image')
EDDImage = _make_stub('edd', 'Apple II EDD Flux Image')
SDKImage = _make_stub('sdk', 'ShrinkIt Disk Archive')


# ---------------------------------------------------------------------------
# Format registry
# ---------------------------------------------------------------------------

FORMATS = {
    'dsk':   {'desc': 'Apple DOS 3.3 Disk Image',              'exts': ['.dsk'],          'cls': DSKImage},
    'do':    {'desc': 'Apple DOS-Order Disk Image',             'exts': ['.do'],           'cls': DSKImage},
    'do-po': {'desc': 'Apple DOS-Order image with ProDOS FS',   'exts': [],                'cls': DOPOImage},
    'po':    {'desc': 'Apple ProDOS-Order Disk Image',          'exts': ['.po'],           'cls': POImage},
    'po-dos': {'desc': 'DOS 3.3 disk in ProDOS sector ordering', 'exts': [],               'cls': PODOSImage},
    'hdv':  {'desc': 'Apple IIgs ProDOS Hard Disk',       'exts': ['.hdv'],        'cls': HDVImage},
    'nib':  {'desc': 'Apple II Nibblized Disk Image',     'exts': ['.nib'],        'cls': NIBImage},
    '2mg':  {'desc': 'Universal Apple II Image (2MG)',    'exts': ['.2mg', '.2img'], 'cls': TMGImage},
    'woz':  {'desc': 'WOZ Flux Image',                   'exts': ['.woz'],        'cls': WOZImage},
    'a2r':  {'desc': 'Applesauce Flux Image',             'exts': ['.a2r'],        'cls': A2RImage},
    'edd':  {'desc': 'EDD Flux Image',                    'exts': ['.edd'],        'cls': EDDImage},
    'sdk':  {'desc': 'ShrinkIt Disk Archive',             'exts': ['.sdk', '.shk'], 'cls': SDKImage},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def _looks_like_po_dos33(data: bytes) -> bool:
    """True if a PO-sector-ordered file contains a DOS 3.3 filesystem (previously saved by PODOSImage)."""
    if len(data) != _DSK_SIZE:
        return False
    return _looks_like_dos33(_po_to_dsk(data))


def _looks_like_dos33(data: bytes) -> bool:
    if len(data) != _DSK_SIZE:
        return False
    off = _dsk_offset(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
    vtoc = data[off:off + _DSK_SEC_SIZE]
    if len(vtoc) < 0x36:
        return False
    return (vtoc[0x01] == _DSK_DIR_TRACK and
            vtoc[0x03] == 3 and
            vtoc[0x35] == _DSK_SECTORS)   # sectors/track at 0x35, not 0x27


def _looks_like_prodos(data: bytes) -> bool:
    if len(data) % _PO_BLOCK_SIZE != 0 or len(data) < _PO_BLOCK_SIZE * 7:
        return False
    off = _PO_VOLDIR_BLOCK * _PO_BLOCK_SIZE
    buf = data[off:off + _PO_BLOCK_SIZE]
    if len(buf) < 4 + _PO_ENTRY_SIZE:
        return False
    stor = (buf[4] >> 4) & 0xF
    name_len = buf[4] & 0xF
    return stor == _PO_STOR_VOLHDR and 1 <= name_len <= 15


def _looks_like_dos_prodos(data: bytes) -> bool:
    """Return True if a 143360-byte DOS-ordered image contains a ProDOS filesystem."""
    if len(data) != _DSK_SIZE:
        return False
    return _looks_like_prodos(_dsk_to_po(data))


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown Apple II format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in ('.dsk', '.do', '.po') and path.exists():
        data = path.read_bytes()
        # Check DOS 3.3 first: a .po file with DOS 3.3 content (either ordering) needs
        # PODOSImage so AppleWin's ProDOS sector interleave correctly reconstructs the data.
        if _looks_like_dos33(data):
            return 'po-dos' if ext == '.po' else 'dsk'
        if ext == '.po' and _looks_like_po_dos33(data):
            return 'po-dos'   # already PO-ordered (saved by a previous PODOSImage.save())
        if _looks_like_dos_prodos(data):
            return 'do-po'   # DOS-sector-ordered image with ProDOS filesystem
        if _looks_like_prodos(data):
            return 'po'      # ProDOS block-ordered image
        return _EXT_MAP.get(ext, 'dsk')   # unknown content: trust extension
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect Apple II format from: {path.name}')


def load(path: Path, fmt: str):
    return FORMATS[fmt]['cls'].load(path)


def create(fmt: str, name: str = 'NEW DISK'):
    return FORMATS[fmt]['cls'].create(disk_name=name)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _print_listing(files):
    if not files:
        print('(empty disk)')
        return
    for ftype, name, size in files:
        if ftype == 'HEADER':
            print(f'  0  "{name}"')
            print()
        else:
            print(f'  {size:4d}  {ftype:<4}  "{name}"')
    data = [(t, n, s) for t, n, s in files if t != 'HEADER']
    if data:
        print(f'\n  {sum(s for _, _, s in data)} BLOCKS/SECTORS USED')


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(
        description='Manage Apple II disk images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Formats: ' + ', '.join(FORMATS),
    )
    ap.add_argument('--format', dest='fmt', help='Format key (dsk, do, po, hdv, nib, 2mg, ...)')
    sub = ap.add_subparsers(dest='command', required=True)

    pc = sub.add_parser('create'); pc.add_argument('image'); pc.add_argument('--name', default='NEW DISK')
    pl = sub.add_parser('list');   pl.add_argument('image')
    pa = sub.add_parser('add');    pa.add_argument('image'); pa.add_argument('file')
    pa.add_argument('--name');     pa.add_argument('--type', default='bin')
    pa.add_argument('--addr', type=lambda x: int(x, 0), default=0,
                    help='Load address for DOS 3.3 binary files (e.g. 0x0800)')
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
            addr = getattr(a, 'addr', 0)
            img = load(p, fmt); img.add_file(Path(a.file).read_bytes(), name, a.type, addr)
            img.save(p); print(f'Added "{name}" to {p}')
        elif a.command == 'remove':
            img = load(p, fmt)
            if not img.remove_file(a.name.upper()):
                sys.exit(f'File not found: {a.name}')
            img.save(p); print(f'Removed "{a.name}" from {p}')
    except (ValueError, NotImplementedError, RuntimeError, OSError) as e:
        sys.exit(f'Error: {e}')


if __name__ == '__main__':
    main()
