#!/usr/bin/env python3
"""
diskimage-atari.py — Atari disk image handler.

Fully implemented: atr xfd st msa cas
Stubs: atx stx stt pro di jam dim
"""

import struct
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# ATR — Atari DOS 2 disk image  (single-density, 128-byte sectors)
# ---------------------------------------------------------------------------

_ATR_MAGIC       = 0x0296
_ATR_SECTOR_SIZE = 128
_ATR_SECTORS     = 720
_ATR_VTOC_SEC    = 360
_ATR_DIR_START   = 361
_ATR_DIR_SECS    = 8
_ATR_HEADER_SIZE = 16


def _atr_sec_offset(sector: int) -> int:
    return _ATR_HEADER_SIZE + (sector - 1) * _ATR_SECTOR_SIZE


def _atr_make_header(sectors: int = _ATR_SECTORS, sec_size: int = _ATR_SECTOR_SIZE) -> bytes:
    paragraphs = (sectors * sec_size) // 16
    return struct.pack('<HHHH8x', _ATR_MAGIC, paragraphs & 0xFFFF, sec_size, paragraphs >> 16)


class ATRImage:
    def __init__(self, data: bytearray):
        self.data = data

    @classmethod
    def create(cls, disk_name: str = '', **kw) -> 'ATRImage':
        size = _ATR_HEADER_SIZE + _ATR_SECTORS * _ATR_SECTOR_SIZE
        data = bytearray(size)
        data[:_ATR_HEADER_SIZE] = _atr_make_header()
        img = cls(data)
        img._init_vtoc()
        img._init_directory()
        return img

    @classmethod
    def load(cls, path: Path) -> 'ATRImage':
        return cls(bytearray(path.read_bytes()))

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
        vtoc[0] = 0x02
        vtoc[1] = (_ATR_SECTORS - 1) & 0xFF
        vtoc[2] = (_ATR_SECTORS - 1) >> 8
        free = _ATR_SECTORS - _ATR_DIR_SECS - 1
        vtoc[3] = free & 0xFF
        vtoc[4] = (free >> 8) & 0xFF
        for sec in range(1, _ATR_SECTORS + 1):
            byte_idx = 10 + (sec - 1) // 8
            bit_idx  = 7 - ((sec - 1) % 8)
            if byte_idx < _ATR_SECTOR_SIZE:
                vtoc[byte_idx] |= (1 << bit_idx)
        for sec in [_ATR_VTOC_SEC] + list(range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS)):
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
        if vtoc[3] > 0:
            vtoc[3] -= 1
        self._write_sec(_ATR_VTOC_SEC, vtoc)

    def _vtoc_free(self, sector: int) -> None:
        vtoc = self._read_sec(_ATR_VTOC_SEC)
        byte_idx = 10 + (sector - 1) // 8
        bit_idx  = 7 - ((sector - 1) % 8)
        if not (vtoc[byte_idx] & (1 << bit_idx)):
            vtoc[byte_idx] |= (1 << bit_idx)
            vtoc[3] = min(vtoc[3] + 1, 0xFF)
        self._write_sec(_ATR_VTOC_SEC, vtoc)

    def _find_free_sector(self) -> int:
        for sec in range(1, _ATR_SECTORS + 1):
            if sec == _ATR_VTOC_SEC:
                continue
            if _ATR_DIR_START <= sec < _ATR_DIR_START + _ATR_DIR_SECS:
                continue
            if self._vtoc_is_free(sec):
                return sec
        raise RuntimeError('Disk full.')

    def _iter_dir_entries(self):
        for ds in range(_ATR_DIR_START, _ATR_DIR_START + _ATR_DIR_SECS):
            sec = self._read_sec(ds)
            for i in range(8):
                off = i * 16
                entry_num = (ds - _ATR_DIR_START) * 8 + i
                yield ds, i, off, bytes(sec[off:off + 16]), entry_num

    def list_files(self) -> list:
        files = []
        for _, _, _, entry, _ in self._iter_dir_entries():
            flags = entry[0]
            if flags in (0x00, 0x80):
                continue
            fname = entry[5:13].decode('ascii', 'replace').rstrip()
            ext   = entry[13:16].decode('ascii', 'replace').rstrip()
            size  = entry[1] | (entry[2] << 8)
            name  = f'{fname}.{ext}' if ext.strip() else fname
            ftype = 'DEL' if flags & 0x20 else 'FILE'
            files.append((ftype, name, size))
        return files

    def add_file(self, file_data: bytes, atari_name: str, file_type: str = 'bin') -> None:
        parts = atari_name.upper().split('.')
        fname = (parts[0] + '        ')[:8]
        ext   = (parts[1] + '   ')[:3] if len(parts) > 1 else '   '
        dir_sec_idx = slot_idx = slot_off = None
        for ds, si, off, entry, _ in self._iter_dir_entries():
            if entry[0] in (0x00, 0x80):
                dir_sec_idx, slot_idx, slot_off = ds, si, off
                break
        if dir_sec_idx is None:
            raise RuntimeError('Directory full.')
        chunks = [file_data[i:i + 125] for i in range(0, len(file_data), 125)] or [b'']
        allocated = []
        for chunk in chunks:
            sec_num = self._find_free_sector()
            self._vtoc_alloc(sec_num)
            allocated.append((sec_num, chunk))
        entry_num = (dir_sec_idx - _ATR_DIR_START) * 8 + slot_idx
        for i, (sec_num, chunk) in enumerate(allocated):
            sec = bytearray(_ATR_SECTOR_SIZE)
            is_last = (i + 1 == len(allocated))
            if is_last:
                sec[125] = (entry_num & 0x3F) << 2
                sec[126] = 0
                sec[127] = len(chunk)
            else:
                next_sec = allocated[i + 1][0]
                sec[125] = ((entry_num & 0x3F) << 2) | ((next_sec >> 8) & 0x03)
                sec[126] = next_sec & 0xFF
                sec[127] = 125
            sec[:len(chunk)] = chunk
            self._write_sec(sec_num, sec)
        dir_sec = self._read_sec(dir_sec_idx)
        entry = bytearray(16)
        entry[0] = 0x42
        entry[1] = len(allocated) & 0xFF
        entry[2] = (len(allocated) >> 8) & 0xFF
        entry[3] = allocated[0][0] & 0xFF
        entry[4] = (allocated[0][0] >> 8) & 0xFF
        entry[5:13] = fname.encode('ascii')
        entry[13:16] = ext.encode('ascii')
        dir_sec[slot_off:slot_off + 16] = entry
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
                sec_num = entry[3] | (entry[4] << 8)
                while sec_num:
                    sec = self._read_sec(sec_num)
                    self._vtoc_free(sec_num)
                    next_hi  = (sec[125] & 0x03) << 8
                    next_lo  = sec[126]
                    next_sec = next_hi | next_lo
                    sec_num  = 0 if sec[127] < 125 else next_sec
                dir_sec = self._read_sec(ds)
                dir_sec[off] = 0x80
                self._write_sec(ds, dir_sec)
                return True
        return False


# ---------------------------------------------------------------------------
# XFD — Atari raw disk image (same structure as ATR, no 16-byte header)
# ---------------------------------------------------------------------------

_XFD_SD_SECS = 720    # single density:  720 × 128 = 92,160 bytes
_XFD_ED_SECS = 1040   # enhanced density: 1040 × 128 = 133,120 bytes


class XFDImage(ATRImage):
    """Raw Atari disk image identical in structure to ATR but without the header."""

    @classmethod
    def create(cls, disk_name: str = '', **kw) -> 'XFDImage':
        data = bytearray(_XFD_SD_SECS * _ATR_SECTOR_SIZE)
        img = cls(data)
        img._init_vtoc()
        img._init_directory()
        return img

    @classmethod
    def load(cls, path: Path) -> 'XFDImage':
        data = bytearray(path.read_bytes())
        known = {_XFD_SD_SECS * _ATR_SECTOR_SIZE, _XFD_ED_SECS * _ATR_SECTOR_SIZE}
        if len(data) not in known:
            raise ValueError(
                f'{path.name}: unrecognised XFD size {len(data)} '
                f'(expected {_XFD_SD_SECS * _ATR_SECTOR_SIZE} or '
                f'{_XFD_ED_SECS * _ATR_SECTOR_SIZE})'
            )
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def _read_sec(self, sector: int) -> bytearray:
        off = (sector - 1) * _ATR_SECTOR_SIZE
        return bytearray(self.data[off:off + _ATR_SECTOR_SIZE])

    def _write_sec(self, sector: int, buf: bytearray) -> None:
        off = (sector - 1) * _ATR_SECTOR_SIZE
        self.data[off:off + _ATR_SECTOR_SIZE] = buf[:_ATR_SECTOR_SIZE]


# ---------------------------------------------------------------------------
# ST — Atari ST raw floppy image (FAT12, DD 720KB or HD 1.44MB)
# ---------------------------------------------------------------------------

_ST_SEC_SIZE     = 512
_ST_DD_TOTAL     = 1440   # 80 × 2 × 9  sectors, 737,280 bytes
_ST_HD_TOTAL     = 2880   # 80 × 2 × 18 sectors, 1,474,560 bytes
_ST_DD_SIZE      = _ST_DD_TOTAL * _ST_SEC_SIZE
_ST_HD_SIZE      = _ST_HD_TOTAL * _ST_SEC_SIZE
_ST_ROOT_ENTRIES = 112
_ST_ATTR_VOLUME  = 0x08
_ST_ATTR_DIR     = 0x10
_ST_ATTR_DELETED = 0xE5


def _st_bpb_params(total_secs: int, spt: int) -> dict:
    if total_secs == _ST_DD_TOTAL:
        media, fat_secs, spc = 0xF9, 5, 2
    else:
        media, fat_secs, spc = 0xF0, 9, 1
    root_secs  = (_ST_ROOT_ENTRIES * 32 + _ST_SEC_SIZE - 1) // _ST_SEC_SIZE
    first_data = 1 + 2 * fat_secs + root_secs
    return dict(spc=spc, reserved=1, fat_count=2, root_entries=_ST_ROOT_ENTRIES,
                total_secs=total_secs, media=media, fat_secs=fat_secs,
                spt=spt, heads=2, root_secs=root_secs, first_data=first_data)


class STImage:
    def __init__(self, data: bytearray):
        self.data = data
        self._b   = self._parse_bpb()

    def _parse_bpb(self) -> dict:
        d = self.data
        if len(d) < 512:
            return _st_bpb_params(_ST_DD_TOTAL, 9)
        spc      = d[0x0D]
        res      = d[0x0E] | (d[0x0F] << 8)
        nfat     = d[0x10]
        rde      = d[0x11] | (d[0x12] << 8)
        tot      = d[0x13] | (d[0x14] << 8)
        media    = d[0x15]
        fat_secs = d[0x16] | (d[0x17] << 8)
        spt      = d[0x18] | (d[0x19] << 8)
        heads    = d[0x1A] | (d[0x1B] << 8)
        root_secs  = max(1, (rde * 32 + 511) // 512)
        first_data = res + nfat * fat_secs + root_secs
        return dict(spc=max(1, spc), reserved=res, fat_count=nfat,
                    root_entries=rde, total_secs=tot, media=media,
                    fat_secs=fat_secs, spt=spt, heads=heads,
                    root_secs=root_secs, first_data=first_data)

    @classmethod
    def create(cls, disk_name: str = '', size_hint: str = 'dd', **kw) -> 'STImage':
        if size_hint.lower() == 'hd':
            total, spt, disk_bytes = _ST_HD_TOTAL, 18, _ST_HD_SIZE
        else:
            total, spt, disk_bytes = _ST_DD_TOTAL, 9, _ST_DD_SIZE
        b    = _st_bpb_params(total, spt)
        data = bytearray(disk_bytes)
        img  = cls.__new__(cls)
        img.data = data
        img._b   = b
        img._write_boot(disk_name)
        img._write_fat()
        return img

    @classmethod
    def load(cls, path: Path) -> 'STImage':
        data = bytearray(path.read_bytes())
        if len(data) not in (_ST_DD_SIZE, _ST_HD_SIZE):
            raise ValueError(
                f'{path.name}: unexpected ST size {len(data)} '
                f'(expected {_ST_DD_SIZE} or {_ST_HD_SIZE})'
            )
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    # --- low-level sector I/O ---

    def _read_sec(self, sec: int) -> bytearray:
        off = sec * _ST_SEC_SIZE
        return bytearray(self.data[off:off + _ST_SEC_SIZE])

    def _write_sec(self, sec: int, buf: bytearray) -> None:
        off = sec * _ST_SEC_SIZE
        self.data[off:off + _ST_SEC_SIZE] = buf[:_ST_SEC_SIZE]

    # --- init ---

    def _write_boot(self, disk_name: str) -> None:
        b = self._b
        s = bytearray(_ST_SEC_SIZE)
        s[0:3]  = b'\xEB\x5A\x90'
        s[3:11] = b'ATARI ST'
        s[0x0B] = 0x00; s[0x0C] = 0x02  # bytes per sector = 512
        s[0x0D] = b['spc']
        s[0x0E] = b['reserved'] & 0xFF;    s[0x0F] = (b['reserved'] >> 8) & 0xFF
        s[0x10] = b['fat_count']
        s[0x11] = b['root_entries'] & 0xFF; s[0x12] = (b['root_entries'] >> 8) & 0xFF
        s[0x13] = b['total_secs'] & 0xFF;  s[0x14] = (b['total_secs'] >> 8) & 0xFF
        s[0x15] = b['media']
        s[0x16] = b['fat_secs'] & 0xFF;    s[0x17] = (b['fat_secs'] >> 8) & 0xFF
        s[0x18] = b['spt'] & 0xFF;         s[0x19] = (b['spt'] >> 8) & 0xFF
        s[0x1A] = b['heads'] & 0xFF;       s[0x1B] = (b['heads'] >> 8) & 0xFF
        self._write_sec(0, s)

    def _write_fat(self) -> None:
        b = self._b
        fat = bytearray(b['fat_secs'] * _ST_SEC_SIZE)
        fat[0] = b['media']; fat[1] = 0xFF; fat[2] = 0xFF
        for i in range(b['fat_count']):
            start = b['reserved'] + i * b['fat_secs']
            for s in range(b['fat_secs']):
                self._write_sec(start + s, bytearray(fat[s * _ST_SEC_SIZE:(s + 1) * _ST_SEC_SIZE]))

    # --- FAT12 access ---

    def _read_fat(self) -> bytearray:
        b = self._b
        fat = bytearray()
        for s in range(b['fat_secs']):
            fat += self._read_sec(b['reserved'] + s)
        return fat

    def _write_fat_buf(self, fat: bytearray) -> None:
        b = self._b
        for i in range(b['fat_count']):
            start = b['reserved'] + i * b['fat_secs']
            for s in range(b['fat_secs']):
                self._write_sec(start + s, bytearray(fat[s * _ST_SEC_SIZE:(s + 1) * _ST_SEC_SIZE]))

    @staticmethod
    def _fat12_get(fat: bytearray, cluster: int) -> int:
        off = cluster * 3 // 2
        raw = fat[off] | (fat[off + 1] << 8)
        return (raw >> 4) if (cluster & 1) else (raw & 0xFFF)

    @staticmethod
    def _fat12_set(fat: bytearray, cluster: int, value: int) -> None:
        off = cluster * 3 // 2
        if cluster & 1:
            fat[off]     = (fat[off] & 0x0F) | ((value & 0x0F) << 4)
            fat[off + 1] = (value >> 4) & 0xFF
        else:
            fat[off]     = value & 0xFF
            fat[off + 1] = (fat[off + 1] & 0xF0) | ((value >> 8) & 0x0F)

    def _fat_find_free(self, fat: bytearray) -> int:
        b = self._b
        n = (b['total_secs'] - b['first_data']) // b['spc'] + 2
        for c in range(2, n):
            if self._fat12_get(fat, c) == 0x000:
                return c
        raise RuntimeError('Disk full — no free clusters.')

    def _cluster_to_sec(self, cluster: int) -> int:
        return self._b['first_data'] + (cluster - 2) * self._b['spc']

    def free_blocks(self) -> int:
        b = self._b
        fat = self._read_fat()
        n   = (b['total_secs'] - b['first_data']) // b['spc'] + 2
        return sum(1 for c in range(2, n) if self._fat12_get(fat, c) == 0)

    # --- root directory iteration ---

    def _root_iter(self):
        b = self._b
        root_start = b['reserved'] + b['fat_count'] * b['fat_secs']
        for rs in range(b['root_secs']):
            sec = self._read_sec(root_start + rs)
            for i in range(_ST_SEC_SIZE // 32):
                off   = i * 32
                entry = bytes(sec[off:off + 32])
                if entry[0] == 0x00:
                    return   # no more entries
                yield root_start + rs, off, entry

    # --- public interface ---

    def list_files(self) -> list:
        files = []
        label = None
        for sec, off, entry in self._root_iter():
            if entry[0] == _ST_ATTR_DELETED:
                continue
            attr = entry[11]
            if attr == _ST_ATTR_VOLUME and label is None:
                label = entry[0:11].rstrip(b' ').decode('ascii', 'replace')
                continue
            if attr & (_ST_ATTR_VOLUME | _ST_ATTR_DIR):
                continue
            fname = entry[0:8].rstrip(b' ').decode('ascii', 'replace')
            ext   = entry[8:11].rstrip(b' ').decode('ascii', 'replace')
            name  = f'{fname}.{ext}' if ext else fname
            size  = struct.unpack_from('<I', entry, 28)[0]
            files.append(('FILE', name, max(1, (size + 511) // 512)))
        if label:
            files.insert(0, ('HEADER', label, self.free_blocks()))
        return files

    def add_file(self, file_data: bytes, fat_name: str, file_type: str = 'bin') -> None:
        parts = fat_name.upper().split('.')
        fname = (parts[0] + '        ')[:8]
        ext   = (parts[1] + '   ')[:3] if len(parts) > 1 else '   '

        # Find free root directory slot
        b = self._b
        root_start = b['reserved'] + b['fat_count'] * b['fat_secs']
        dir_sec = dir_off = None
        for rs in range(b['root_secs']):
            sec = self._read_sec(root_start + rs)
            for i in range(_ST_SEC_SIZE // 32):
                off   = i * 32
                first = sec[off]
                if first in (0x00, _ST_ATTR_DELETED):
                    dir_sec, dir_off = root_start + rs, off
                    break
            if dir_sec is not None:
                break
        if dir_sec is None:
            raise RuntimeError('Root directory full.')

        spc          = b['spc']
        cluster_size = spc * _ST_SEC_SIZE
        fat          = self._read_fat()
        clusters     = []

        if file_data:
            for chunk_start in range(0, len(file_data), cluster_size):
                c = self._fat_find_free(fat)
                self._fat12_set(fat, c, 0xFFF)
                if clusters:
                    self._fat12_set(fat, clusters[-1], c)
                clusters.append(c)

            for i, c in enumerate(clusters):
                chunk     = file_data[i * cluster_size:(i + 1) * cluster_size]
                sec_start = self._cluster_to_sec(c)
                for s in range(spc):
                    piece = bytearray(chunk[s * _ST_SEC_SIZE:(s + 1) * _ST_SEC_SIZE])
                    piece += bytearray(max(0, _ST_SEC_SIZE - len(piece)))
                    self._write_sec(sec_start + s, piece)

        self._write_fat_buf(fat)

        entry = bytearray(32)
        entry[0:8]   = fname.encode('ascii')
        entry[8:11]  = ext.encode('ascii')
        entry[11]    = 0x20
        entry[22:24] = struct.pack('<H', 0x0000)
        entry[24:26] = struct.pack('<H', 0x0021)  # 1980-01-01
        entry[26:28] = struct.pack('<H', clusters[0] if clusters else 0)
        entry[28:32] = struct.pack('<I', len(file_data))
        sec_buf = bytearray(self._read_sec(dir_sec))
        sec_buf[dir_off:dir_off + 32] = entry
        self._write_sec(dir_sec, sec_buf)

    def remove_file(self, fat_name: str) -> bool:
        target = fat_name.upper()
        for sec, off, entry in self._root_iter():
            if entry[0] == _ST_ATTR_DELETED:
                continue
            attr = entry[11]
            if attr & (_ST_ATTR_VOLUME | _ST_ATTR_DIR):
                continue
            fname = entry[0:8].rstrip(b' ').decode('ascii', 'replace')
            ext   = entry[8:11].rstrip(b' ').decode('ascii', 'replace')
            name  = f'{fname}.{ext}' if ext else fname
            if name != target and fname.rstrip() != target:
                continue
            fat = self._read_fat()
            c   = struct.unpack_from('<H', entry, 26)[0]
            while 2 <= c <= 0xFF6:
                nc = self._fat12_get(fat, c)
                self._fat12_set(fat, c, 0x000)
                c  = nc
            self._write_fat_buf(fat)
            sec_buf      = bytearray(self._read_sec(sec))
            sec_buf[off] = _ST_ATTR_DELETED
            self._write_sec(sec, sec_buf)
            return True
        return False


# ---------------------------------------------------------------------------
# MSA — Magic Shadow Archiver (compressed Atari ST floppy)
# ---------------------------------------------------------------------------

_MSA_MAGIC = 0x0E0F


class MSAImage:
    """Wraps an STImage; compresses/decompresses MSA format on load/save."""

    def __init__(self, st: STImage):
        self._st = st

    @classmethod
    def create(cls, disk_name: str = '', **kw) -> 'MSAImage':
        return cls(STImage.create(disk_name))

    @classmethod
    def load(cls, path: Path) -> 'MSAImage':
        raw = path.read_bytes()
        if len(raw) < 10 or struct.unpack_from('>H', raw, 0)[0] != _MSA_MAGIC:
            raise ValueError(f'{path.name}: not a valid MSA file')
        spt   = struct.unpack_from('>H', raw, 2)[0]
        sides = struct.unpack_from('>H', raw, 4)[0]  # 0=single, 1=double
        first = struct.unpack_from('>H', raw, 6)[0]
        last  = struct.unpack_from('>H', raw, 8)[0]
        nsides         = sides + 1
        tracks         = last - first + 1
        track_bytes    = spt * _ST_SEC_SIZE
        total_tracks   = (last + 1) * nsides
        st_data        = bytearray(total_tracks * track_bytes)
        pos = 10
        for t in range(tracks):
            actual = first + t
            for side in range(nsides):
                dlen  = struct.unpack_from('>H', raw, pos)[0]; pos += 2
                chunk = raw[pos:pos + dlen]; pos += dlen
                if dlen == track_bytes:
                    decoded = bytearray(chunk)
                else:
                    decoded = MSAImage._decompress(chunk, track_bytes)
                off = (actual * nsides + side) * track_bytes
                st_data[off:off + track_bytes] = decoded
        return cls(STImage(st_data))

    def save(self, path: Path) -> None:
        st   = self._st
        b    = st._b
        spt  = b['spt']
        nsides      = b['heads']
        track_bytes = spt * _ST_SEC_SIZE
        total_tracks = b['total_secs'] // (spt * nsides)
        out = bytearray()
        out += struct.pack('>HHHHH', _MSA_MAGIC, spt, nsides - 1, 0, total_tracks - 1)
        for track in range(total_tracks):
            for side in range(nsides):
                off  = (track * nsides + side) * track_bytes
                raw  = bytes(st.data[off:off + track_bytes])
                comp = MSAImage._compress(raw)
                if len(comp) >= track_bytes:
                    out += struct.pack('>H', track_bytes) + raw
                else:
                    out += struct.pack('>H', len(comp)) + comp
        path.write_bytes(out)

    @staticmethod
    def _decompress(data: bytes, expected: int) -> bytearray:
        out = bytearray()
        i = 0
        while i < len(data) and len(out) < expected:
            b = data[i]; i += 1
            if b == 0xE5 and i + 1 < len(data):
                count = data[i]; i += 1
                val   = data[i]; i += 1
                out  += bytes([val]) * count
            else:
                out.append(b)
        out += bytearray(max(0, expected - len(out)))
        return out

    @staticmethod
    def _compress(data: bytes) -> bytes:
        out = bytearray()
        i = 0
        while i < len(data):
            b = data[i]
            j = i + 1
            while j < len(data) and data[j] == b and j - i < 255:
                j += 1
            run = j - i
            if run >= 4 or (b == 0xE5 and run >= 1):
                out += bytes([0xE5, run, b])
            else:
                for _ in range(run):
                    if b == 0xE5:
                        out += bytes([0xE5, 1, 0xE5])
                    else:
                        out.append(b)
            i = j
        return bytes(out)

    def list_files(self) -> list:     return self._st.list_files()
    def add_file(self, d, n, t='bin'): self._st.add_file(d, n, t)
    def remove_file(self, n) -> bool:  return self._st.remove_file(n)


# ---------------------------------------------------------------------------
# CAS — Atari cassette image (read-only block listing)
# ---------------------------------------------------------------------------

class CASImage:
    def __init__(self, data: bytes):
        self.data = data

    @classmethod
    def create(cls, disk_name: str = '', **kw) -> 'CASImage':
        raise NotImplementedError('CAS: creating cassette images is not supported.')

    @classmethod
    def load(cls, path: Path) -> 'CASImage':
        return cls(path.read_bytes())

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def list_files(self) -> list:
        d = self.data
        if len(d) < 6 or d[:4] != b'FUJI':
            return [('ERROR', '(invalid CAS — missing FUJI header)', 0)]
        pos        = 4
        hdr_extra  = struct.unpack_from('<H', d, pos)[0] if len(d) >= 6 else 0
        pos       += 2 + hdr_extra
        baud       = 600
        block_num  = 0
        files      = []
        while pos + 8 <= len(d):
            chunk_type = d[pos:pos + 4].decode('ascii', 'replace')
            chunk_len  = struct.unpack_from('<H', d, pos + 4)[0]
            chunk_irg  = struct.unpack_from('<H', d, pos + 6)[0]
            pos       += 8
            chunk_data = d[pos:pos + chunk_len]
            pos       += chunk_len
            if chunk_type == 'baud' and chunk_len >= 2:
                baud = struct.unpack_from('<H', chunk_data, 0)[0]
            elif chunk_type == 'data':
                block_num += 1
                label = f'Block {block_num}  ({baud} baud, {chunk_irg}ms gap)'
                files.append(('BLOCK', label, chunk_len))
            elif chunk_type == 'fsk ':
                block_num += 1
                label = f'FSK block {block_num}  ({chunk_irg}ms gap)'
                files.append(('FSK', label, chunk_len))
        return files

    def add_file(self, data: bytes, name: str, ftype: str = 'bin') -> None:
        raise NotImplementedError('CAS: adding files to cassette images is not supported.')

    def remove_file(self, name: str) -> bool:
        raise NotImplementedError('CAS: removing files from cassette images is not supported.')


# ---------------------------------------------------------------------------
# Stubs for formats not yet implemented
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
    _Stub.__name__ = key.upper() + 'Image'
    return _Stub


ATXImage = _make_stub('atx', 'Atari Protected Disk (ATX)')
STXImage = _make_stub('stx', 'Atari ST Pasti Image')
STTImage = _make_stub('stt', 'Atari ST STEEM Format')
PROImage = _make_stub('pro', 'Atari APE ProSystem Format')
DIImage  = _make_stub('di',  'Atari DJ Emulator Format')
JAMImage = _make_stub('jam', 'Atari JAM Packer Format')
DIMImage = _make_stub('dim', 'Atari F-Copy Format')


# ---------------------------------------------------------------------------
# Format registry
# ---------------------------------------------------------------------------

FORMATS = {
    'atr': {'desc': 'Atari DOS 2 Disk Image (128-byte sectors)', 'exts': ['.atr'],         'cls': ATRImage},
    'xfd': {'desc': 'Atari Raw Disk Image (no header)',           'exts': ['.xfd'],         'cls': XFDImage},
    'st':  {'desc': 'Atari ST Raw Floppy Image (FAT12)',          'exts': ['.st'],           'cls': STImage},
    'msa': {'desc': 'Atari ST Magic Shadow Archiver',             'exts': ['.msa'],         'cls': MSAImage},
    'cas': {'desc': 'Atari Cassette Image',                       'exts': ['.cas'],         'cls': CASImage},
    'atx': {'desc': 'Atari Protected Disk',                       'exts': ['.atx'],         'cls': ATXImage},
    'stx': {'desc': 'Atari ST Pasti Image',                       'exts': ['.stx'],         'cls': STXImage},
    'stt': {'desc': 'Atari ST STEEM Format',                      'exts': ['.stt', '.sttt'],'cls': STTImage},
    'pro': {'desc': 'Atari APE ProSystem Format',                 'exts': ['.pro'],         'cls': PROImage},
    'di':  {'desc': 'Atari DJ Emulator Format',                   'exts': ['.di'],          'cls': DIImage},
    'jam': {'desc': 'Atari JAM Packer Format',                    'exts': ['.jam'],         'cls': JAMImage},
    'dim': {'desc': 'Atari F-Copy Format',                        'exts': ['.dim'],         'cls': DIMImage},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown Atari format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect Atari format from: {path.name}')


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
            print(f'  {size:4d}  {ftype:<6}  "{name}"')
    data = [(t, n, s) for t, n, s in files if t != 'HEADER']
    if data:
        print(f'\n  {sum(s for _, _, s in data)} SECTORS/BLOCKS USED')


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(
        description='Manage Atari disk images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Formats: ' + ', '.join(FORMATS),
    )
    ap.add_argument('--format', dest='fmt', help='Format key (atr, xfd, st, msa, cas, ...)')
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
            if not img.remove_file(a.name.upper()):
                sys.exit(f'File not found: {a.name}')
            img.save(p); print(f'Removed "{a.name}" from {p}')
    except (ValueError, NotImplementedError, RuntimeError, OSError) as e:
        sys.exit(f'Error: {e}')


if __name__ == '__main__':
    main()
