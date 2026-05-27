#!/usr/bin/env python3
"""
diskimage.py — Create and manage retro 8-bit disk images.

Supported formats
-----------------
  d64   Commodore 1541 disk image (C64, C128, C16, PET, VIC-20)
  atr   Atari DOS 2 disk image (Atari 8-bit)
  dsk   Apple DOS 3.3 disk image (Apple IIe)

Commands
--------
  create  diskimage.py create output.d64 [--name "DISK NAME"] [--format d64]
  add     diskimage.py add image.d64 file.prg [--name FILENAME] [--type prg|seq|usr]
  list    diskimage.py list image.d64
  remove  diskimage.py remove image.d64 FILENAME

Format is auto-detected from file extension when not specified.
"""

import argparse
import struct
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# D64 — Commodore 1541 disk image
# ---------------------------------------------------------------------------

# Sectors per track for a standard 35-track 1541 image (index 0 unused)
_D64_SECTORS = [0,
    21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,  # 1-17
    19,                                                    # 18 (dir track)
    18,18,18,18,18,18,                                     # 19-24
    17,17,17,17,17,                                        # 25-29
    17,17,17,17,17,17,                                     # 30-35
]
_D64_TOTAL_TRACKS = 35
_D64_DIR_TRACK    = 18
_D64_DIR_SECTOR   = 1
_D64_BAM_TRACK    = 18
_D64_BAM_SECTOR   = 0
_D64_SEC_SIZE     = 256
_D64_TOTAL_SECS   = sum(_D64_SECTORS[1:36])  # 683

_D64_FILETYPES = {'del': 0x80, 'seq': 0x81, 'prg': 0x82, 'usr': 0x83, 'rel': 0x84}


def _d64_offset(track: int, sector: int) -> int:
    off = 0
    for t in range(1, track):
        off += _D64_SECTORS[t]
    return (off + sector) * _D64_SEC_SIZE


class D64Image:
    def __init__(self, data: bytearray):
        self.data = data

    @staticmethod
    def create(disk_name: str = 'NEW DISK', disk_id: str = 'AA') -> 'D64Image':
        data = bytearray(_D64_TOTAL_SECS * _D64_SEC_SIZE)
        img = D64Image(data)
        img._init_bam(disk_name, disk_id)
        img._init_directory()
        return img

    @staticmethod
    def load(path: Path) -> 'D64Image':
        return D64Image(bytearray(path.read_bytes()))

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def _read_sec(self, track: int, sector: int) -> bytearray:
        off = _d64_offset(track, sector)
        return self.data[off:off + _D64_SEC_SIZE]

    def _write_sec(self, track: int, sector: int, buf: bytearray) -> None:
        off = _d64_offset(track, sector)
        self.data[off:off + _D64_SEC_SIZE] = buf

    # BAM helpers

    def _init_bam(self, disk_name: str, disk_id: str) -> None:
        bam = bytearray(_D64_SEC_SIZE)
        bam[0] = _D64_DIR_TRACK
        bam[1] = _D64_DIR_SECTOR
        bam[2] = 0x41   # DOS 'A'
        bam[3] = 0x00
        for t in range(1, _D64_TOTAL_TRACKS + 1):
            nsec = _D64_SECTORS[t]
            bam_off = 4 + (t - 1) * 4
            if t == _D64_DIR_TRACK:
                bam[bam_off] = 0
                bam[bam_off+1] = 0x00
                bam[bam_off+2] = 0x00
                bam[bam_off+3] = 0x00
            else:
                bam[bam_off] = nsec
                bits = (1 << nsec) - 1
                bam[bam_off+1] = bits & 0xFF
                bam[bam_off+2] = (bits >> 8) & 0xFF
                bam[bam_off+3] = (bits >> 16) & 0xFF
        # disk name (16 chars, padded $A0)
        name_bytes = (disk_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        bam[144:160] = name_bytes
        bam[160] = 0xA0
        bam[161] = 0xA0
        id_bytes = (disk_id.upper().encode('ascii', 'replace') + b'AA')[:2]
        bam[162:164] = id_bytes
        bam[164] = 0xA0
        bam[165:167] = b'2A'
        bam[167] = 0xA0
        bam[168] = 0xA0
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _init_directory(self) -> None:
        sec = bytearray(_D64_SEC_SIZE)
        sec[0] = 0x00   # no next sector
        sec[1] = 0xFF
        sec[2:] = bytearray(_D64_SEC_SIZE - 2)
        self._write_sec(_D64_DIR_TRACK, _D64_DIR_SECTOR, sec)

    def _bam_alloc(self, track: int, sector: int) -> None:
        bam = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam_off = 4 + (track - 1) * 4
        bam[bam_off] -= 1
        byte_idx = sector // 8
        bit_idx  = sector % 8
        bam[bam_off + 1 + byte_idx] &= ~(1 << bit_idx)
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _bam_free_sector(self, track: int, sector: int) -> None:
        bam = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam_off = 4 + (track - 1) * 4
        byte_idx = sector // 8
        bit_idx  = sector % 8
        if not (bam[bam_off + 1 + byte_idx] & (1 << bit_idx)):
            bam[bam_off] += 1
            bam[bam_off + 1 + byte_idx] |= (1 << bit_idx)
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _find_free_sector(self, start_track: int = 1) -> tuple:
        bam = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        for t in range(start_track, _D64_TOTAL_TRACKS + 1):
            if t == _D64_DIR_TRACK:
                continue
            bam_off = 4 + (t - 1) * 4
            if bam[bam_off] == 0:
                continue
            nsec = _D64_SECTORS[t]
            for s in range(nsec):
                byte_idx = s // 8
                bit_idx  = s % 8
                if bam[bam_off + 1 + byte_idx] & (1 << bit_idx):
                    return t, s
        raise RuntimeError('Disk full — no free sectors available.')

    def _iter_dir_entries(self):
        """Yield (dir_track, dir_sector, entry_offset, entry_bytes) for all slots."""
        t, s = _D64_DIR_TRACK, _D64_DIR_SECTOR
        while t:
            sec = self._read_sec(t, s)
            next_t = sec[0]
            next_s = sec[1]
            for i in range(8):
                off = 2 + i * 32
                yield t, s, off, bytes(sec[off:off+32])
            t = next_t
            s = next_s if next_t else 0

    def list_files(self) -> list:
        files = []
        bam = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        name_raw = bam[144:160]
        disk_name = name_raw.rstrip(b'\xa0').decode('ascii', 'replace')
        files.append(('HEADER', disk_name, 0))
        for _, _, _, entry in self._iter_dir_entries():
            ftype = entry[0]
            if ftype == 0x00:
                continue
            fname = entry[3:19].rstrip(b'\xa0').decode('ascii', 'replace')
            blocks = entry[28] | (entry[29] << 8)
            type_names = {0x80:'DEL',0x81:'SEQ',0x82:'PRG',0x83:'USR',0x84:'REL'}
            closed = 'CLOSED' if ftype & 0x80 else 'OPEN'
            tname = type_names.get(ftype & 0x0F | 0x80, f'${ftype:02X}')
            files.append((tname, fname, blocks))
        return files

    def add_file(self, file_data: bytes, petscii_name: str, file_type: str = 'prg') -> None:
        ftype_byte = _D64_FILETYPES.get(file_type.lower(), 0x82) | 0x80

        # Find a free directory slot
        dir_t, dir_s, dir_off = None, None, None
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0] == 0x00:
                dir_t, dir_s, dir_off = dt, ds, doff
                break
        if dir_t is None:
            raise RuntimeError('Directory full.')

        # Write file data in sector chains (start from track 17 downward for efficiency)
        chunks = [file_data[i:i+254] for i in range(0, len(file_data), 254)]
        if not chunks:
            chunks = [b'']
        allocated = []
        for chunk in chunks:
            t, s = self._find_free_sector(1)
            self._bam_alloc(t, s)
            allocated.append((t, s, chunk))

        # Link sectors
        for i, (t, s, chunk) in enumerate(allocated):
            sec = bytearray(_D64_SEC_SIZE)
            if i + 1 < len(allocated):
                nt, ns = allocated[i+1][0], allocated[i+1][1]
                sec[0] = nt
                sec[1] = ns
            else:
                sec[0] = 0x00
                sec[1] = len(chunk) + 1
            sec[2:2+len(chunk)] = chunk
            self._write_sec(t, s, sec)

        # Write directory entry
        sec = bytearray(self._read_sec(dir_t, dir_s))
        entry = bytearray(32)
        entry[0] = ftype_byte
        entry[1] = allocated[0][0]   # first track
        entry[2] = allocated[0][1]   # first sector
        name_bytes = (petscii_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        entry[3:19] = name_bytes
        num_blocks = len(chunks)
        entry[28] = num_blocks & 0xFF
        entry[29] = (num_blocks >> 8) & 0xFF
        sec[dir_off:dir_off+32] = entry
        self._write_sec(dir_t, dir_s, sec)

    def remove_file(self, petscii_name: str) -> bool:
        target = petscii_name.upper()
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0] == 0x00:
                continue
            fname = entry[3:19].rstrip(b'\xa0').decode('ascii', 'replace').upper()
            if fname == target:
                # Walk and free sector chain
                t, s = entry[1], entry[2]
                while t:
                    sec = self._read_sec(t, s)
                    nt, ns = sec[0], sec[1]
                    self._bam_free_sector(t, s)
                    t = nt
                    s = ns if nt else 0
                # Zero the directory entry
                sec = bytearray(self._read_sec(dt, ds))
                sec[doff:doff+32] = bytearray(32)
                self._write_sec(dt, ds, sec)
                return True
        return False


# ---------------------------------------------------------------------------
# ATR — Atari DOS 2 disk image
# ---------------------------------------------------------------------------

_ATR_MAGIC       = 0x0296
_ATR_SECTOR_SIZE = 128
_ATR_SECTORS     = 720   # single density
_ATR_VTOC_SEC    = 360   # 1-indexed
_ATR_DIR_START   = 361
_ATR_DIR_SECS    = 8
_ATR_DIR_ENTRIES = 64
_ATR_HEADER_SIZE = 16


def _atr_sec_offset(sector: int) -> int:
    """Sector is 1-indexed."""
    return _ATR_HEADER_SIZE + (sector - 1) * _ATR_SECTOR_SIZE


def _atr_make_header(sectors: int = _ATR_SECTORS, sec_size: int = _ATR_SECTOR_SIZE) -> bytes:
    paragraphs = (sectors * sec_size) // 16
    return struct.pack('<HHHH8x', _ATR_MAGIC, paragraphs & 0xFFFF, sec_size, paragraphs >> 16)


class ATRImage:
    def __init__(self, data: bytearray):
        self.data = data

    @staticmethod
    def create(disk_name: str = '') -> 'ATRImage':
        size = _ATR_HEADER_SIZE + _ATR_SECTORS * _ATR_SECTOR_SIZE
        data = bytearray(size)
        data[:_ATR_HEADER_SIZE] = _atr_make_header()
        img = ATRImage(data)
        img._init_vtoc()
        img._init_directory()
        return img

    @staticmethod
    def load(path: Path) -> 'ATRImage':
        return ATRImage(bytearray(path.read_bytes()))

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def _read_sec(self, sector: int) -> bytearray:
        off = _atr_sec_offset(sector)
        return bytearray(self.data[off:off + _ATR_SECTOR_SIZE])

    def _write_sec(self, sector: int, buf: bytearray) -> None:
        off = _atr_sec_offset(sector)
        self.data[off:off + _ATR_SECTOR_SIZE] = buf[:_ATR_SECTOR_SIZE]

    def _init_vtoc(self) -> None:
        vtoc = bytearray(_ATR_SECTOR_SIZE)
        vtoc[0] = 0x02   # DOS 2
        vtoc[1] = (_ATR_SECTORS - 1) & 0xFF
        vtoc[2] = (_ATR_SECTORS - 1) >> 8
        vtoc[3] = (_ATR_SECTORS - _ATR_DIR_SECS - 1) & 0xFF
        vtoc[4] = (_ATR_SECTORS - _ATR_DIR_SECS - 1) >> 8
        # Mark all sectors free (bitmap: 1=free, 0=used)
        # Sectors 1-719 in bits starting at byte 10
        for sec in range(1, _ATR_SECTORS + 1):
            byte_idx = 10 + (sec - 1) // 8
            bit_idx  = 7 - ((sec - 1) % 8)
            if byte_idx < _ATR_SECTOR_SIZE:
                vtoc[byte_idx] |= (1 << bit_idx)
        # Mark VTOC and directory sectors as used
        for sec in list(range(_ATR_VTOC_SEC, _ATR_VTOC_SEC + 1)) + list(range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS)):
            byte_idx = 10 + (sec - 1) // 8
            bit_idx  = 7 - ((sec - 1) % 8)
            if byte_idx < _ATR_SECTOR_SIZE:
                vtoc[byte_idx] &= ~(1 << bit_idx)
        self._write_sec(_ATR_VTOC_SEC, vtoc)

    def _init_directory(self) -> None:
        for sec in range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS):
            self._write_sec(sec, bytearray(_ATR_SECTOR_SIZE))

    def _vtoc_is_free(self, sector: int) -> bool:
        vtoc = self._read_sec(_ATR_VTOC_SEC)
        byte_idx = 10 + (sector - 1) // 8
        bit_idx  = 7 - ((sector - 1) % 8)
        return bool(vtoc[byte_idx] & (1 << bit_idx))

    def _vtoc_alloc(self, sector: int) -> None:
        vtoc = self._read_sec(_ATR_VTOC_SEC)
        byte_idx = 10 + (sector - 1) // 8
        bit_idx  = 7 - ((sector - 1) % 8)
        vtoc[byte_idx] &= ~(1 << bit_idx)
        vtoc[3] -= 1
        self._write_sec(_ATR_VTOC_SEC, vtoc)

    def _vtoc_free(self, sector: int) -> None:
        vtoc = self._read_sec(_ATR_VTOC_SEC)
        byte_idx = 10 + (sector - 1) // 8
        bit_idx  = 7 - ((sector - 1) % 8)
        if not (vtoc[byte_idx] & (1 << bit_idx)):
            vtoc[byte_idx] |= (1 << bit_idx)
            vtoc[3] += 1
        self._write_sec(_ATR_VTOC_SEC, vtoc)

    def _find_free_sector(self) -> int:
        for sec in range(1, _ATR_SECTORS + 1):
            if sec in range(_ATR_VTOC_SEC, _ATR_VTOC_SEC + 1):
                continue
            if sec in range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS):
                continue
            if self._vtoc_is_free(sec):
                return sec
        raise RuntimeError('Disk full.')

    def _iter_dir_entries(self):
        for ds in range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS):
            sec = self._read_sec(ds)
            for i in range(8):
                off = i * 16
                entry = sec[off:off+16]
                entry_num = (ds - _ATR_DIR_START) * 8 + i
                yield ds, i, off, bytes(entry), entry_num

    def list_files(self) -> list:
        files = []
        for _, _, _, entry, _ in self._iter_dir_entries():
            flags = entry[0]
            if flags == 0x00 or flags == 0x80:
                continue
            fname = entry[5:13].decode('ascii', 'replace').rstrip()
            ext   = entry[13:16].decode('ascii', 'replace').rstrip()
            size  = entry[1] | (entry[2] << 8)
            ftype = 'DEL' if flags & 0x20 else 'FILE'
            name  = f'{fname}.{ext}' if ext.strip() else fname
            files.append((ftype, name, size))
        return files

    def add_file(self, file_data: bytes, atari_name: str, file_type: str = 'bin') -> None:
        # Parse "NAME.EXT" or "NAME"
        parts = atari_name.upper().split('.')
        fname = (parts[0] + '        ')[:8]
        ext   = (parts[1] + '   ')[:3] if len(parts) > 1 else '   '

        # Find free directory entry
        dir_sec_idx, slot_idx, slot_off = None, None, None
        for ds, si, off, entry, _ in self._iter_dir_entries():
            if entry[0] in (0x00, 0x80):
                dir_sec_idx, slot_idx, slot_off = ds, si, off
                break
        if dir_sec_idx is None:
            raise RuntimeError('Directory full.')

        # Write sectors
        chunks = [file_data[i:i+125] for i in range(0, len(file_data), 125)]
        if not chunks:
            chunks = [b'']
        allocated = []
        for chunk in chunks:
            sec_num = self._find_free_sector()
            self._vtoc_alloc(sec_num)
            allocated.append((sec_num, chunk))

        entry_num = (dir_sec_idx - _ATR_DIR_START) * 8 + slot_idx
        for i, (sec_num, chunk) in enumerate(allocated):
            sec = bytearray(_ATR_SECTOR_SIZE)
            is_last = (i + 1 == len(allocated))
            # Bytes 125,126,127: file_num(6bits)|next_hi(2bits), next_lo, byte_count
            if is_last:
                sec[125] = (entry_num & 0x3F) << 2
                sec[126] = 0
                sec[127] = len(chunk)
            else:
                next_sec = allocated[i+1][0]
                sec[125] = ((entry_num & 0x3F) << 2) | ((next_sec >> 8) & 0x03)
                sec[126] = next_sec & 0xFF
                sec[127] = 125
            sec[:len(chunk)] = chunk
            self._write_sec(sec_num, sec)

        # Write directory entry
        dir_sec = self._read_sec(dir_sec_idx)
        entry = bytearray(16)
        entry[0] = 0x42   # in-use, not locked
        entry[1] = len(allocated) & 0xFF
        entry[2] = (len(allocated) >> 8) & 0xFF
        entry[3] = allocated[0][0] & 0xFF
        entry[4] = (allocated[0][0] >> 8) & 0xFF
        entry[5:13] = fname.encode('ascii')
        entry[13:16] = ext.encode('ascii')
        dir_sec[slot_off:slot_off+16] = entry
        self._write_sec(dir_sec_idx, dir_sec)

    def remove_file(self, atari_name: str) -> bool:
        target = atari_name.upper()
        for ds, si, off, entry, _ in self._iter_dir_entries():
            if entry[0] in (0x00, 0x80):
                continue
            fname = entry[5:13].decode('ascii', 'replace').rstrip()
            ext   = entry[13:16].decode('ascii', 'replace').rstrip()
            name  = f'{fname}.{ext}' if ext.strip() else fname
            if name == target or fname.rstrip() == target:
                # Free sector chain
                sec_num = entry[3] | (entry[4] << 8)
                while sec_num:
                    sec = self._read_sec(sec_num)
                    self._vtoc_free(sec_num)
                    next_hi = (sec[125] & 0x03) << 8
                    next_lo = sec[126]
                    next_sec = next_hi | next_lo
                    if sec[127] < 125:
                        next_sec = 0
                    sec_num = next_sec
                # Mark directory entry deleted
                dir_sec = self._read_sec(ds)
                dir_sec[off] = 0x80
                self._write_sec(ds, dir_sec)
                return True
        return False


# ---------------------------------------------------------------------------
# DSK — Apple DOS 3.3 disk image
# ---------------------------------------------------------------------------

_DSK_TRACKS      = 35
_DSK_SECTORS     = 16
_DSK_SEC_SIZE    = 256
_DSK_SIZE        = _DSK_TRACKS * _DSK_SECTORS * _DSK_SEC_SIZE  # 143360
_DSK_VTOC_TRACK  = 17
_DSK_VTOC_SEC    = 0
_DSK_DIR_TRACK   = 17
_DSK_DIR_FIRST_S = 15   # directory starts at sector 15, works downward


def _dsk_offset(track: int, sector: int) -> int:
    return (track * _DSK_SECTORS + sector) * _DSK_SEC_SIZE


class DSKImage:
    def __init__(self, data: bytearray):
        self.data = data

    @staticmethod
    def create(disk_name: str = 'NEW DISK', volume: int = 254) -> 'DSKImage':
        data = bytearray(_DSK_SIZE)
        img = DSKImage(data)
        img._init_vtoc(volume)
        return img

    @staticmethod
    def load(path: Path) -> 'DSKImage':
        data = bytearray(path.read_bytes())
        if len(data) != _DSK_SIZE:
            raise ValueError(f'Expected {_DSK_SIZE} bytes, got {len(data)}.')
        return DSKImage(data)

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
        vtoc[0x03] = 3    # DOS version 3.3
        vtoc[0x06] = volume
        vtoc[0x27] = _DSK_SECTORS
        vtoc[0x34] = 1
        vtoc[0x35] = 0
        vtoc[0x36] = _DSK_TRACKS
        vtoc[0x37] = _DSK_SECTORS
        vtoc[0x38] = _DSK_SEC_SIZE & 0xFF
        vtoc[0x39] = (_DSK_SEC_SIZE >> 8) & 0xFF
        # Free bitmap: bytes 0x38+ (2 bytes per track, bit=free)
        # VTOC format: tracks 0x38+t*4 for track t
        for t in range(_DSK_TRACKS):
            free_bits = 0xFFFF
            if t == _DSK_DIR_TRACK:
                # Mark dir sectors used
                for s in range(_DSK_DIR_FIRST_S, -1, -1):
                    free_bits &= ~(1 << s)
                free_bits &= ~1  # sector 0 = VTOC
            base = 0x38 + t * 4
            vtoc[base]   = (free_bits >> 8) & 0xFF
            vtoc[base+1] = free_bits & 0xFF
            vtoc[base+2] = 0
            vtoc[base+3] = 0
        # Init first directory sector
        dir_sec = bytearray(_DSK_SEC_SIZE)
        dir_sec[0x01] = 0    # no next track
        dir_sec[0x02] = 0
        self._write_sec(_DSK_DIR_TRACK, _DSK_DIR_FIRST_S, dir_sec)
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _vtoc_is_free(self, track: int, sector: int) -> bool:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base+1]
        return bool(bits & (1 << sector))

    def _vtoc_alloc(self, track: int, sector: int) -> None:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base+1]
        bits &= ~(1 << sector)
        vtoc[base]   = (bits >> 8) & 0xFF
        vtoc[base+1] = bits & 0xFF
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _vtoc_free_sec(self, track: int, sector: int) -> None:
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        base = 0x38 + track * 4
        bits = (vtoc[base] << 8) | vtoc[base+1]
        bits |= (1 << sector)
        vtoc[base]   = (bits >> 8) & 0xFF
        vtoc[base+1] = bits & 0xFF
        self._write_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC, vtoc)

    def _find_free_sector(self) -> tuple:
        # Start at track 1: track 0 = boot track, and track=0 in a dir entry means "empty"
        for t in range(1, _DSK_TRACKS):
            if t == _DSK_DIR_TRACK:
                continue
            for s in range(_DSK_SECTORS - 1, -1, -1):
                if self._vtoc_is_free(t, s):
                    return t, s
        raise RuntimeError('Disk full.')

    def _iter_dir_entries(self):
        t, s = _DSK_DIR_TRACK, _DSK_DIR_FIRST_S
        while t:
            sec = self._read_sec(t, s)
            next_t = sec[0x01]
            next_s = sec[0x02]
            for i in range(7):
                off = 0x0B + i * 0x23
                entry = bytes(sec[off:off + 0x23])
                yield t, s, off, entry
            t = next_t if (next_t != 0) else 0
            s = next_s

    def list_files(self) -> list:
        files = []
        for _, _, _, entry in self._iter_dir_entries():
            track = entry[0x00]
            if track == 0x00 or track == 0xFF:
                continue
            ftype = entry[0x02]
            name_bytes = entry[0x03:0x21]
            name = ''.join(chr(b & 0x7F) for b in name_bytes).rstrip()
            sectors = entry[0x21] | (entry[0x22] << 8)
            type_names = {0x00:'T', 0x01:'I', 0x02:'A', 0x04:'B', 0x08:'S', 0x10:'R', 0x20:'A', 0x40:'B'}
            tname = type_names.get(ftype & 0x7F, f'${ftype:02X}')
            locked = '*' if ftype & 0x80 else ' '
            files.append((tname + locked, name, sectors))
        return files

    def add_file(self, file_data: bytes, apple_name: str, file_type: str = 'bin') -> None:
        type_codes = {'t': 0x00, 'i': 0x01, 'a': 0x02, 'b': 0x04, 's': 0x08, 'bin': 0x04}
        ftype_byte = type_codes.get(file_type.lower(), 0x04)

        # Find free directory slot (track byte 0x00/0xFF = unused/deleted)
        dir_t, dir_s, dir_off = None, None, None
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0x00] in (0x00, 0xFF):
                dir_t, dir_s, dir_off = dt, ds, doff
                break
        if dir_t is None:
            raise RuntimeError('Directory full.')

        # Allocate a track-sector list sector first
        tsl_t, tsl_s = self._find_free_sector()
        self._vtoc_alloc(tsl_t, tsl_s)
        tsl = bytearray(_DSK_SEC_SIZE)

        # Write file data sectors
        chunks = [file_data[i:i+_DSK_SEC_SIZE] for i in range(0, max(1, len(file_data)), _DSK_SEC_SIZE)]
        tsl_entries = []
        for chunk in chunks:
            ft, fs = self._find_free_sector()
            self._vtoc_alloc(ft, fs)
            sec = bytearray(_DSK_SEC_SIZE)
            sec[:len(chunk)] = chunk
            self._write_sec(ft, fs, sec)
            tsl_entries.append((ft, fs))

        # Fill TSL sector
        tsl[0x01] = 0
        tsl[0x02] = 0
        vtoc = self._read_sec(_DSK_VTOC_TRACK, _DSK_VTOC_SEC)
        tsl[0x05] = vtoc[0x06]
        for i, (ft, fs) in enumerate(tsl_entries):
            base = 0x0C + i * 2
            tsl[base]   = ft
            tsl[base+1] = fs
        self._write_sec(tsl_t, tsl_s, tsl)

        # Write directory entry (Apple DOS 3.3: tsl@0x00, type@0x02, name@0x03-0x20, secs@0x21)
        dir_sec = self._read_sec(dir_t, dir_s)
        entry = bytearray(0x23)
        entry[0x00] = tsl_t
        entry[0x01] = tsl_s
        entry[0x02] = ftype_byte
        name_str = (apple_name + ' ' * 30)[:30]
        for i, c in enumerate(name_str):
            entry[0x03 + i] = (ord(c) | 0x80) & 0xFF
        total_secs = len(tsl_entries) + 1
        entry[0x21] = total_secs & 0xFF
        entry[0x22] = (total_secs >> 8) & 0xFF
        dir_sec[dir_off:dir_off+0x23] = entry
        self._write_sec(dir_t, dir_s, dir_sec)

    def remove_file(self, apple_name: str) -> bool:
        target = apple_name.upper().rstrip()
        for dt, ds, doff, entry in self._iter_dir_entries():
            if entry[0x00] in (0x00, 0xFF):
                continue
            name_bytes = entry[0x03:0x21]
            name = ''.join(chr(b & 0x7F) for b in name_bytes).rstrip().upper()
            if name == target:
                tsl_t = entry[0x00]
                tsl_s = entry[0x01]
                tsl = self._read_sec(tsl_t, tsl_s)
                for i in range((0xFE - 0x0C) // 2):
                    base = 0x0C + i * 2
                    ft, fs = tsl[base], tsl[base+1]
                    if ft == 0 and fs == 0:
                        break
                    self._vtoc_free_sec(ft, fs)
                self._vtoc_free_sec(tsl_t, tsl_s)
                dir_sec = self._read_sec(dt, ds)
                dir_sec[doff + 0x00] = 0xFF  # mark deleted (track=0xFF)
                self._write_sec(dt, ds, dir_sec)
                return True
        return False


# ---------------------------------------------------------------------------
# Format detection
# ---------------------------------------------------------------------------

def detect_format(path: Path, fmt_arg: str) -> str:
    if fmt_arg:
        return fmt_arg.lower()
    ext = path.suffix.lower()
    return {'d64': 'd64', '.d64': 'd64', '.atr': 'atr', '.dsk': 'dsk', '.po': 'dsk'}.get(ext, '')


def load_image(path: Path, fmt: str):
    if fmt == 'd64':
        return D64Image.load(path)
    if fmt == 'atr':
        return ATRImage.load(path)
    if fmt == 'dsk':
        return DSKImage.load(path)
    sys.exit(f'Cannot detect format for {path}. Use --format d64|atr|dsk.')


# ---------------------------------------------------------------------------
# CLI commands
# ---------------------------------------------------------------------------

def cmd_create(args) -> None:
    out = Path(args.image)
    fmt = detect_format(out, args.format)
    if not fmt:
        sys.exit('Cannot detect format from extension. Specify --format d64|atr|dsk.')
    name = args.name or 'NEW DISK'
    if fmt == 'd64':
        img = D64Image.create(disk_name=name)
    elif fmt == 'atr':
        img = ATRImage.create()
    elif fmt == 'dsk':
        img = DSKImage.create(disk_name=name)
    else:
        sys.exit(f'Unknown format: {fmt}')
    img.save(out)
    print(f'Created {fmt.upper()} image: {out}')


def cmd_add(args) -> None:
    img_path = Path(args.image)
    src_path = Path(args.file)
    if not img_path.exists():
        sys.exit(f'Image not found: {img_path}')
    if not src_path.exists():
        sys.exit(f'File not found: {src_path}')
    fmt = detect_format(img_path, args.format)
    img = load_image(img_path, fmt)
    file_data = src_path.read_bytes()
    name = args.name or src_path.stem.upper()
    ftype = args.type or 'prg'
    img.add_file(file_data, name, ftype)
    img.save(img_path)
    print(f'Added {name} ({len(file_data)} bytes) to {img_path}')


def cmd_list(args) -> None:
    img_path = Path(args.image)
    if not img_path.exists():
        sys.exit(f'Image not found: {img_path}')
    fmt = detect_format(img_path, args.format)
    img = load_image(img_path, fmt)
    files = img.list_files()
    if not files:
        print('(empty disk)')
        return
    for ftype, name, blocks in files:
        if ftype == 'HEADER':
            print(f'  0  "{name}"')
            print()
        else:
            print(f'  {blocks:3d}  "{name}"  {ftype}')
    total_blocks = sum(b for t, _, b in files if t != 'HEADER')
    print(f'\n  {total_blocks} BLOCKS USED')


def cmd_remove(args) -> None:
    img_path = Path(args.image)
    if not img_path.exists():
        sys.exit(f'Image not found: {img_path}')
    fmt = detect_format(img_path, args.format)
    img = load_image(img_path, fmt)
    if img.remove_file(args.name.upper()):
        img.save(img_path)
        print(f'Removed "{args.name.upper()}" from {img_path}')
    else:
        sys.exit(f'File not found: {args.name}')


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description='Create and manage retro 8-bit disk images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('--format', choices=['d64', 'atr', 'dsk'],
                    help='Disk format (auto-detected from extension if omitted)')
    sub = ap.add_subparsers(dest='command', required=True)

    p_create = sub.add_parser('create', help='Create a new blank disk image')
    p_create.add_argument('image', help='Output disk image path')
    p_create.add_argument('--name', help='Disk name/label')

    p_add = sub.add_parser('add', help='Add a file to a disk image')
    p_add.add_argument('image', help='Disk image path')
    p_add.add_argument('file',  help='File to add')
    p_add.add_argument('--name', help='Filename on disk (default: source stem)')
    p_add.add_argument('--type', default='prg',
                       help='File type: prg/seq/usr (D64), bin/seq (ATR/DSK) [default: prg/bin]')

    p_list = sub.add_parser('list', help='List files in a disk image')
    p_list.add_argument('image', help='Disk image path')

    p_rm = sub.add_parser('remove', help='Remove a file from a disk image')
    p_rm.add_argument('image', help='Disk image path')
    p_rm.add_argument('name',  help='Filename to remove (as shown by list)')

    args = ap.parse_args()
    if args.command == 'create':
        cmd_create(args)
    elif args.command == 'add':
        cmd_add(args)
    elif args.command == 'list':
        cmd_list(args)
    elif args.command == 'remove':
        cmd_remove(args)


if __name__ == '__main__':
    main()
