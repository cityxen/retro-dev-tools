#!/usr/bin/env python3
"""
diskimage-commodore.py — Commodore disk image handler.

Fully implemented: d64  d71  d81  t64  p00
Stubs: d67 d80 d82 d1m g64 g71 nib nbz tap crt x64 d13 d90
"""

import struct
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# D64 — Commodore 1541 disk image
# ---------------------------------------------------------------------------
#
# Track/sector zones (GCR):
#   Zone 1: tracks  1-17  → 21 sectors each
#   Zone 2: tracks 18-24  → 19 sectors each  (track 18 = BAM/dir track)
#   Zone 3: tracks 25-30  → 18 sectors each
#   Zone 4: tracks 31-35  → 17 sectors each
#   Total: 683 sectors × 256 bytes = 174,848 bytes

_D64_SECTORS = [0,
    21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,  # tracks  1-17
    19,19,19,19,19,19,19,                                  # tracks 18-24
    18,18,18,18,18,18,                                     # tracks 25-30
    17,17,17,17,17,                                        # tracks 31-35
]
_D64_TOTAL_TRACKS = 35
_D64_DIR_TRACK    = 18
_D64_DIR_SECTOR   = 1
_D64_BAM_TRACK    = 18
_D64_BAM_SECTOR   = 0
_D64_SEC_SIZE     = 256
_D64_TOTAL_SECS   = sum(_D64_SECTORS[1:36])  # 683

_D64_FILETYPES = {'del': 0x00, 'seq': 0x81, 'prg': 0x82, 'usr': 0x83, 'rel': 0x84}
_D64_TYPE_NAMES = {0x80: 'DEL', 0x81: 'SEQ', 0x82: 'PRG', 0x83: 'USR', 0x84: 'REL',
                   0xC0: 'DEL', 0xC1: 'SEQ', 0xC2: 'PRG', 0xC3: 'USR', 0xC4: 'REL'}  # locked variants


def _d64_offset(track: int, sector: int) -> int:
    off = 0
    for t in range(1, track):
        off += _D64_SECTORS[t]
    return (off + sector) * _D64_SEC_SIZE


class D64Image:
    def __init__(self, data: bytearray):
        self.data = data

    # --- factory methods ---

    @classmethod
    def create(cls, disk_name: str = 'NEW DISK', disk_id: str = 'AA', **kw) -> 'D64Image':
        data = bytearray(_D64_TOTAL_SECS * _D64_SEC_SIZE)
        img = cls(data)
        img._init_bam(disk_name, disk_id)
        img._init_directory()
        return img

    @classmethod
    def load(cls, path: Path) -> 'D64Image':
        data = bytearray(path.read_bytes())
        # Accept standard 174848 bytes and error-flagged 175531 bytes
        if len(data) not in (174848, 175531):
            raise ValueError(
                f'{path.name}: expected 174848 bytes for D64, got {len(data)}'
            )
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data[:_D64_TOTAL_SECS * _D64_SEC_SIZE])

    # --- low-level sector I/O ---

    def _read_sec(self, track: int, sector: int) -> bytearray:
        off = _d64_offset(track, sector)
        return bytearray(self.data[off:off + _D64_SEC_SIZE])

    def _write_sec(self, track: int, sector: int, buf: bytearray) -> None:
        off = _d64_offset(track, sector)
        self.data[off:off + _D64_SEC_SIZE] = buf[:_D64_SEC_SIZE]

    # --- BAM ---

    def _init_bam(self, disk_name: str, disk_id: str) -> None:
        bam = bytearray(_D64_SEC_SIZE)
        bam[0] = _D64_DIR_TRACK
        bam[1] = _D64_DIR_SECTOR
        bam[2] = 0x41   # DOS version 'A'
        bam[3] = 0x00
        for t in range(1, _D64_TOTAL_TRACKS + 1):
            nsec    = _D64_SECTORS[t]
            bam_off = 4 + (t - 1) * 4
            if t == _D64_DIR_TRACK:
                # Entire track 18 marked unavailable for file data
                bam[bam_off] = bam[bam_off+1] = bam[bam_off+2] = bam[bam_off+3] = 0x00
            else:
                bam[bam_off] = nsec
                bits = (1 << nsec) - 1
                bam[bam_off+1] = bits & 0xFF
                bam[bam_off+2] = (bits >> 8) & 0xFF
                bam[bam_off+3] = (bits >> 16) & 0xFF
        name_bytes = (disk_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        bam[144:160] = name_bytes
        bam[160] = bam[161] = 0xA0
        id_bytes   = (disk_id.upper().encode('ascii', 'replace') + b'AA')[:2]
        bam[162:164] = id_bytes
        bam[164]     = 0xA0
        bam[165:167] = b'2A'   # DOS type
        bam[167] = bam[168] = 0xA0
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _init_directory(self) -> None:
        sec    = bytearray(_D64_SEC_SIZE)
        sec[0] = 0x00   # end-of-chain link
        sec[1] = 0xFF
        self._write_sec(_D64_DIR_TRACK, _D64_DIR_SECTOR, sec)

    def _bam_alloc(self, track: int, sector: int) -> None:
        bam     = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam_off = 4 + (track - 1) * 4
        bam[bam_off] = max(0, bam[bam_off] - 1)
        bam[bam_off + 1 + sector // 8] &= ~(1 << (sector % 8))
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _bam_free_sector(self, track: int, sector: int) -> None:
        bam      = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam_off  = 4 + (track - 1) * 4
        byte_idx = sector // 8
        bit      = 1 << (sector % 8)
        if not (bam[bam_off + 1 + byte_idx] & bit):
            bam[bam_off] = min(bam[bam_off] + 1, _D64_SECTORS[track])
            bam[bam_off + 1 + byte_idx] |= bit
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _find_free_sector(self, start_track: int = 1) -> tuple:
        bam = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        for t in range(start_track, _D64_TOTAL_TRACKS + 1):
            if t == _D64_DIR_TRACK:
                continue
            bam_off = 4 + (t - 1) * 4
            if bam[bam_off] == 0:
                continue
            for s in range(_D64_SECTORS[t]):
                if bam[bam_off + 1 + s // 8] & (1 << (s % 8)):
                    return t, s
        raise RuntimeError('Disk full — no free sectors available.')

    def free_blocks(self) -> int:
        bam   = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        total = 0
        for t in range(1, _D64_TOTAL_TRACKS + 1):
            if t == _D64_DIR_TRACK:
                continue
            total += bam[4 + (t - 1) * 4]
        return total

    # --- directory iteration ---

    def _iter_dir_entries(self):
        t, s  = _D64_DIR_TRACK, _D64_DIR_SECTOR
        seen  = set()
        while t and (t, s) not in seen:
            seen.add((t, s))
            sec              = self._read_sec(t, s)
            next_t, next_s   = sec[0], sec[1]
            for i in range(8):
                off = 2 + i * 32
                yield t, s, off, bytes(sec[off:off + 32])
            t = next_t
            s = next_s if next_t else 0

    def _alloc_dir_sector(self, used_sectors: set) -> tuple:
        used_s = {s for (t, s) in used_sectors if t == _D64_DIR_TRACK}
        for s in range(1, _D64_SECTORS[_D64_DIR_TRACK]):
            if s not in used_s:
                return _D64_DIR_TRACK, s
        raise RuntimeError('Directory full — all 18 directory sectors used (144 file limit).')

    # --- public interface ---

    def list_files(self) -> list:
        files = []
        bam   = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        disk_name = bam[144:160].rstrip(b'\xa0').decode('latin-1', 'replace')
        files.append(('HEADER', disk_name, self.free_blocks()))
        for _, _, _, entry in self._iter_dir_entries():
            ftype = entry[0]
            if ftype == 0x00:
                continue
            if not (ftype & 0x80):
                continue   # scratched / open file — skip
            fname  = entry[3:19].rstrip(b'\xa0').decode('latin-1', 'replace')
            blocks = entry[28] | (entry[29] << 8)
            locked = '<' if ftype & 0x40 else ''
            base   = (ftype & 0x07) | 0x80
            tname  = _D64_TYPE_NAMES.get(base, f'?{ftype:02X}') + locked
            files.append((tname, fname, blocks))
        return files

    def add_file(self, file_data: bytes, petscii_name: str,
                 file_type: str = 'prg') -> None:
        ftype_byte = _D64_FILETYPES.get(file_type.lower(), 0x82)
        if ftype_byte != 0x00:
            ftype_byte |= 0x80   # mark closed

        # Find a free or scratched directory slot; track the chain for expansion
        dir_t = dir_s = dir_off = None
        visited = set()
        last_dir_t = last_dir_s = _D64_DIR_TRACK, _D64_DIR_SECTOR
        t, s = _D64_DIR_TRACK, _D64_DIR_SECTOR
        while t and (t, s) not in visited:
            visited.add((t, s))
            last_dir_t, last_dir_s = t, s
            sec = self._read_sec(t, s)
            if dir_t is None:
                for i in range(8):
                    off = 2 + i * 32
                    e = sec[off:off + 32]
                    if e[0] == 0x00 or not (e[0] & 0x80):
                        dir_t, dir_s, dir_off = t, s, off
                        break
            next_t = sec[0]
            t, s = (next_t, sec[1]) if next_t else (0, 0)

        if dir_t is None:
            # Expand directory: allocate new sector on track 18
            new_t, new_s = self._alloc_dir_sector(visited)
            lsec = bytearray(self._read_sec(last_dir_t, last_dir_s))
            lsec[0], lsec[1] = new_t, new_s
            self._write_sec(last_dir_t, last_dir_s, lsec)
            nsec = bytearray(_D64_SEC_SIZE)
            nsec[0], nsec[1] = 0x00, 0xFF
            self._write_sec(new_t, new_s, nsec)
            dir_t, dir_s, dir_off = new_t, new_s, 2

        # Allocate sectors for file data
        chunks    = [file_data[i:i + 254] for i in range(0, len(file_data), 254)] or [b'']
        allocated = []
        for chunk in chunks:
            t, s = self._find_free_sector(1)
            self._bam_alloc(t, s)
            allocated.append((t, s, chunk))

        # Write sector chain
        for i, (t, s, chunk) in enumerate(allocated):
            sec = bytearray(_D64_SEC_SIZE)
            if i + 1 < len(allocated):
                sec[0], sec[1] = allocated[i + 1][0], allocated[i + 1][1]
            else:
                sec[0] = 0x00
                sec[1] = len(chunk) + 1   # byte count in last sector
            sec[2:2 + len(chunk)] = chunk
            self._write_sec(t, s, sec)

        # Write directory entry
        sec   = bytearray(self._read_sec(dir_t, dir_s))
        entry = bytearray(32)
        entry[0]     = ftype_byte
        entry[1]     = allocated[0][0]
        entry[2]     = allocated[0][1]
        entry[3:19]  = (petscii_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        n            = len(chunks)
        entry[28]    = n & 0xFF
        entry[29]    = (n >> 8) & 0xFF
        sec[dir_off:dir_off + 32] = entry
        self._write_sec(dir_t, dir_s, sec)

    def remove_file(self, petscii_name: str) -> bool:
        target = petscii_name.upper()
        for dt, ds, doff, entry in self._iter_dir_entries():
            if not (entry[0] & 0x80):
                continue
            fname = entry[3:19].rstrip(b'\xa0').decode('latin-1', 'replace').upper()
            if fname != target:
                continue
            # Free sector chain
            t, s = entry[1], entry[2]
            while t:
                sec      = self._read_sec(t, s)
                nt, ns   = sec[0], sec[1]
                self._bam_free_sector(t, s)
                t = nt
                s = ns if nt else 0
            # Scratch the directory entry (clear type byte)
            sec         = bytearray(self._read_sec(dt, ds))
            sec[doff]   = 0x00
            self._write_sec(dt, ds, sec)
            return True
        return False


# ---------------------------------------------------------------------------
# D71 — Commodore 1571 disk image (double-sided)
# ---------------------------------------------------------------------------
#
# Side 1 (tracks 1-35) mirrors D64 zone structure.
# Side 2 (tracks 36-70) mirrors Side 1.
# Total: 1366 sectors × 256 bytes = 349,696 bytes
# Directory: same track 18 as D64.
# Primary BAM:   T18,S0  (side 1: tracks  1-35 bitmaps + free counts)
# Secondary BAM: T53,S0  (side 2: tracks 36-70 bitmaps + free counts)

_D71_SIDE2_OFFSET = 36   # side 2 starts at logical track 36

# Tracks 36-70 mirror the D64 zone structure (track 36 ≡ track 1, etc.)
_D71_SECTORS = list(_D64_SECTORS)  # index 0-35
_D71_SECTORS += [
    21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,  # 36-52
    19,19,19,19,19,19,19,                                  # 53-59
    18,18,18,18,18,18,                                     # 60-65
    17,17,17,17,17,                                        # 66-70
]
_D71_TOTAL_TRACKS = 70
_D71_TOTAL_SECS   = sum(_D71_SECTORS[1:71])   # 1366
_D71_BAM2_TRACK   = 53   # secondary BAM track (on side 2)
_D71_BAM2_SECTOR  = 0


def _d71_offset(track: int, sector: int) -> int:
    if track <= _D64_TOTAL_TRACKS:
        return _d64_offset(track, sector)
    off = _D64_TOTAL_SECS
    for t in range(_D71_SIDE2_OFFSET, track):
        off += _D71_SECTORS[t]
    return (off + sector) * _D64_SEC_SIZE


class D71Image(D64Image):
    """Double-sided 1571 disk image. Shares D64 directory/BAM logic for side 1."""

    @classmethod
    def create(cls, disk_name: str = 'NEW DISK', disk_id: str = 'AA', **kw) -> 'D71Image':
        data = bytearray(_D71_TOTAL_SECS * _D64_SEC_SIZE)
        img  = cls(data)
        img._init_bam(disk_name, disk_id)
        img._init_bam2()
        img._init_directory()
        return img

    @classmethod
    def load(cls, path: Path) -> 'D71Image':
        data = bytearray(path.read_bytes())
        if len(data) not in (349696, 351062):
            raise ValueError(
                f'{path.name}: expected 349696 bytes for D71, got {len(data)}'
            )
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data[:_D71_TOTAL_SECS * _D64_SEC_SIZE])

    # Override _read_sec/_write_sec to use the larger offset table

    def _read_sec(self, track: int, sector: int) -> bytearray:
        off = _d71_offset(track, sector)
        return bytearray(self.data[off:off + _D64_SEC_SIZE])

    def _write_sec(self, track: int, sector: int, buf: bytearray) -> None:
        off = _d71_offset(track, sector)
        self.data[off:off + _D64_SEC_SIZE] = buf[:_D64_SEC_SIZE]

    def _init_bam(self, disk_name: str, disk_id: str) -> None:
        # Same as D64 but byte 3 = 0x80 (double-sided flag) and DOS type '3D'
        super()._init_bam(disk_name, disk_id)
        bam     = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam[3]  = 0x80
        bam[165:167] = b'3D'
        self._write_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR, bam)

    def _init_bam2(self) -> None:
        """Initialize secondary BAM at T53,S0 for tracks 36-70."""
        bam    = bytearray(_D64_SEC_SIZE)
        bam[0] = 0x00
        bam[1] = 0xFF
        bam[2] = 0x44   # 'D' for double-sided
        bam[3] = 0xBB
        for t in range(_D71_SIDE2_OFFSET, _D71_TOTAL_TRACKS + 1):
            nsec    = _D71_SECTORS[t]
            bam_off = 4 + (t - _D71_SIDE2_OFFSET) * 4
            bits    = (1 << nsec) - 1
            bam[bam_off]   = nsec
            bam[bam_off+1] = bits & 0xFF
            bam[bam_off+2] = (bits >> 8) & 0xFF
            bam[bam_off+3] = (bits >> 16) & 0xFF
        self._write_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR, bam)

    def _bam_alloc(self, track: int, sector: int) -> None:
        if track <= _D64_TOTAL_TRACKS:
            super()._bam_alloc(track, sector)
            return
        bam     = self._read_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR)
        bam_off = 4 + (track - _D71_SIDE2_OFFSET) * 4
        bam[bam_off] = max(0, bam[bam_off] - 1)
        bam[bam_off + 1 + sector // 8] &= ~(1 << (sector % 8))
        self._write_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR, bam)

    def _bam_free_sector(self, track: int, sector: int) -> None:
        if track <= _D64_TOTAL_TRACKS:
            super()._bam_free_sector(track, sector)
            return
        bam      = self._read_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR)
        bam_off  = 4 + (track - _D71_SIDE2_OFFSET) * 4
        byte_idx = sector // 8
        bit      = 1 << (sector % 8)
        if not (bam[bam_off + 1 + byte_idx] & bit):
            bam[bam_off] = min(bam[bam_off] + 1, _D71_SECTORS[track])
            bam[bam_off + 1 + byte_idx] |= bit
        self._write_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR, bam)

    def _find_free_sector(self, start_track: int = 1) -> tuple:
        # Search side 1 first, then side 2
        bam1 = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        for t in range(max(start_track, 1), _D64_TOTAL_TRACKS + 1):
            if t == _D64_DIR_TRACK:
                continue
            bam_off = 4 + (t - 1) * 4
            if bam1[bam_off] == 0:
                continue
            for s in range(_D64_SECTORS[t]):
                if bam1[bam_off + 1 + s // 8] & (1 << (s % 8)):
                    return t, s
        bam2 = self._read_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR)
        for t in range(_D71_SIDE2_OFFSET, _D71_TOTAL_TRACKS + 1):
            bam_off = 4 + (t - _D71_SIDE2_OFFSET) * 4
            if bam2[bam_off] == 0:
                continue
            for s in range(_D71_SECTORS[t]):
                if bam2[bam_off + 1 + s // 8] & (1 << (s % 8)):
                    return t, s
        raise RuntimeError('Disk full — no free sectors available.')

    def free_blocks(self) -> int:
        bam1  = self._read_sec(_D64_BAM_TRACK, _D64_BAM_SECTOR)
        bam2  = self._read_sec(_D71_BAM2_TRACK, _D71_BAM2_SECTOR)
        total = 0
        for t in range(1, _D64_TOTAL_TRACKS + 1):
            if t == _D64_DIR_TRACK:
                continue
            total += bam1[4 + (t - 1) * 4]
        for t in range(_D71_SIDE2_OFFSET, _D71_TOTAL_TRACKS + 1):
            total += bam2[4 + (t - _D71_SIDE2_OFFSET) * 4]
        return total


# ---------------------------------------------------------------------------
# D81 — Commodore 1581 disk image (3.5", 80 tracks, 40 sectors/track)
# ---------------------------------------------------------------------------
#
# Layout:
#   80 tracks × 40 sectors × 256 bytes = 819,200 bytes
#   Track 40 = directory track
#   T40,S0 = disk header
#   T40,S1 = BAM sector 1 (tracks 1-40)
#   T40,S2 = BAM sector 2 (tracks 41-80)
#   T40,S3 = first directory sector
#
# BAM entry per track: 6 bytes
#   [0] free sector count  [1-5] 40-bit sector bitmap (LSB=sector 0)

_D81_TRACKS        = 80
_D81_SECS_PER_TRACK = 40
_D81_SEC_SIZE      = 256
_D81_TOTAL_SECS    = _D81_TRACKS * _D81_SECS_PER_TRACK  # 3200
_D81_DIR_TRACK     = 40
_D81_HDR_SECTOR    = 0
_D81_BAM1_SECTOR   = 1   # covers tracks 1-40
_D81_BAM2_SECTOR   = 2   # covers tracks 41-80
_D81_DIR_SECTOR    = 3   # first directory sector
_D81_BAM_ENTRY_SZ  = 6
_D81_BAM_HDR_SZ    = 4   # bytes before track entries in each BAM sector


def _d81_offset(track: int, sector: int) -> int:
    return ((track - 1) * _D81_SECS_PER_TRACK + sector) * _D81_SEC_SIZE


class D81Image:
    def __init__(self, data: bytearray):
        self.data = data

    @classmethod
    def create(cls, disk_name: str = 'NEW DISK', disk_id: str = 'AA', **kw) -> 'D81Image':
        data = bytearray(_D81_TOTAL_SECS * _D81_SEC_SIZE)
        img  = cls(data)
        img._init_header(disk_name, disk_id)
        img._init_bam()
        img._init_directory()
        return img

    @classmethod
    def load(cls, path: Path) -> 'D81Image':
        data = bytearray(path.read_bytes())
        if len(data) != _D81_TOTAL_SECS * _D81_SEC_SIZE:
            raise ValueError(
                f'{path.name}: expected {_D81_TOTAL_SECS * _D81_SEC_SIZE} bytes for D81, '
                f'got {len(data)}'
            )
        return cls(data)

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)

    def _read_sec(self, track: int, sector: int) -> bytearray:
        off = _d81_offset(track, sector)
        return bytearray(self.data[off:off + _D81_SEC_SIZE])

    def _write_sec(self, track: int, sector: int, buf: bytearray) -> None:
        off = _d81_offset(track, sector)
        self.data[off:off + _D81_SEC_SIZE] = buf[:_D81_SEC_SIZE]

    def _init_header(self, disk_name: str, disk_id: str) -> None:
        hdr    = bytearray(_D81_SEC_SIZE)
        hdr[0] = _D81_DIR_TRACK
        hdr[1] = _D81_DIR_SECTOR
        hdr[2] = 0x44   # DOS version 'D'
        hdr[3] = 0xBB
        name_bytes  = (disk_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        hdr[4:20]   = name_bytes
        hdr[20:22]  = b'\xa0\xa0'
        id_bytes    = (disk_id.upper().encode('ascii', 'replace') + b'AA')[:2]
        hdr[22:24]  = id_bytes
        hdr[24]     = 0xA0
        hdr[25:27]  = b'3D'
        hdr[27:29]  = b'\xa0\xa0'
        self._write_sec(_D81_DIR_TRACK, _D81_HDR_SECTOR, hdr)

    def _init_bam(self) -> None:
        for bam_sec_idx, (bam_sector, track_start, track_end) in enumerate([
            (_D81_BAM1_SECTOR, 1,  40),
            (_D81_BAM2_SECTOR, 41, 80),
        ]):
            bam    = bytearray(_D81_SEC_SIZE)
            bam[0] = _D81_DIR_TRACK if bam_sec_idx == 0 else 0x00
            bam[1] = _D81_BAM2_SECTOR if bam_sec_idx == 0 else 0xFF
            bam[2] = 0x44   # 'D'
            bam[3] = 0xBB
            for t in range(track_start, track_end + 1):
                entry_off = _D81_BAM_HDR_SZ + (t - track_start) * _D81_BAM_ENTRY_SZ
                if t == _D81_DIR_TRACK:
                    # Mark entire directory track unavailable
                    bam[entry_off:entry_off + _D81_BAM_ENTRY_SZ] = b'\x00' * _D81_BAM_ENTRY_SZ
                else:
                    bam[entry_off]     = _D81_SECS_PER_TRACK
                    bits               = (1 << _D81_SECS_PER_TRACK) - 1
                    bam[entry_off+1]   = bits & 0xFF
                    bam[entry_off+2]   = (bits >> 8) & 0xFF
                    bam[entry_off+3]   = (bits >> 16) & 0xFF
                    bam[entry_off+4]   = (bits >> 24) & 0xFF
                    bam[entry_off+5]   = (bits >> 32) & 0xFF
            self._write_sec(_D81_DIR_TRACK, bam_sector, bam)

    def _init_directory(self) -> None:
        sec    = bytearray(_D81_SEC_SIZE)
        sec[0] = 0x00
        sec[1] = 0xFF
        self._write_sec(_D81_DIR_TRACK, _D81_DIR_SECTOR, sec)

    def _bam_entry_for(self, track: int):
        """Return (bam_bytearray, bam_sector, entry_offset_in_sector)."""
        if track <= 40:
            bam       = self._read_sec(_D81_DIR_TRACK, _D81_BAM1_SECTOR)
            entry_off = _D81_BAM_HDR_SZ + (track - 1) * _D81_BAM_ENTRY_SZ
            return bam, _D81_BAM1_SECTOR, entry_off
        else:
            bam       = self._read_sec(_D81_DIR_TRACK, _D81_BAM2_SECTOR)
            entry_off = _D81_BAM_HDR_SZ + (track - 41) * _D81_BAM_ENTRY_SZ
            return bam, _D81_BAM2_SECTOR, entry_off

    def _bam_alloc(self, track: int, sector: int) -> None:
        bam, bam_sec, eoff = self._bam_entry_for(track)
        bam[eoff]  = max(0, bam[eoff] - 1)
        bam[eoff + 1 + sector // 8] &= ~(1 << (sector % 8))
        self._write_sec(_D81_DIR_TRACK, bam_sec, bam)

    def _bam_free_sector(self, track: int, sector: int) -> None:
        bam, bam_sec, eoff = self._bam_entry_for(track)
        byte_idx = sector // 8
        bit      = 1 << (sector % 8)
        if not (bam[eoff + 1 + byte_idx] & bit):
            bam[eoff] = min(bam[eoff] + 1, _D81_SECS_PER_TRACK)
            bam[eoff + 1 + byte_idx] |= bit
        self._write_sec(_D81_DIR_TRACK, bam_sec, bam)

    def _find_free_sector(self) -> tuple:
        for bam_sec, track_start, track_end in [
            (_D81_BAM1_SECTOR, 1, 40),
            (_D81_BAM2_SECTOR, 41, 80),
        ]:
            bam = self._read_sec(_D81_DIR_TRACK, bam_sec)
            for t in range(track_start, track_end + 1):
                if t == _D81_DIR_TRACK:
                    continue
                eoff = _D81_BAM_HDR_SZ + (t - track_start) * _D81_BAM_ENTRY_SZ
                if bam[eoff] == 0:
                    continue
                for s in range(_D81_SECS_PER_TRACK):
                    if bam[eoff + 1 + s // 8] & (1 << (s % 8)):
                        return t, s
        raise RuntimeError('Disk full — no free sectors available.')

    def free_blocks(self) -> int:
        total = 0
        for bam_sec, track_start, track_end in [
            (_D81_BAM1_SECTOR, 1, 40),
            (_D81_BAM2_SECTOR, 41, 80),
        ]:
            bam = self._read_sec(_D81_DIR_TRACK, bam_sec)
            for t in range(track_start, track_end + 1):
                if t == _D81_DIR_TRACK:
                    continue
                eoff   = _D81_BAM_HDR_SZ + (t - track_start) * _D81_BAM_ENTRY_SZ
                total += bam[eoff]
        return total

    def _iter_dir_entries(self):
        t, s  = _D81_DIR_TRACK, _D81_DIR_SECTOR
        seen  = set()
        while t and (t, s) not in seen:
            seen.add((t, s))
            sec            = self._read_sec(t, s)
            next_t, next_s = sec[0], sec[1]
            for i in range(8):
                off = 2 + i * 32
                yield t, s, off, bytes(sec[off:off + 32])
            t = next_t
            s = next_s if next_t else 0

    def _alloc_dir_sector(self, used_sectors: set) -> tuple:
        used_s = {s for (t, s) in used_sectors if t == _D81_DIR_TRACK}
        # Sectors 0-2 are header/BAM; directory uses 3+
        for s in range(_D81_DIR_SECTOR, _D81_SECS_PER_TRACK):
            if s not in used_s:
                return _D81_DIR_TRACK, s
        raise RuntimeError('Directory full — all directory sectors used (296 file limit).')

    def list_files(self) -> list:
        files = []
        hdr   = self._read_sec(_D81_DIR_TRACK, _D81_HDR_SECTOR)
        disk_name = hdr[4:20].rstrip(b'\xa0').decode('latin-1', 'replace')
        files.append(('HEADER', disk_name, self.free_blocks()))
        for _, _, _, entry in self._iter_dir_entries():
            ftype = entry[0]
            if ftype == 0x00 or not (ftype & 0x80):
                continue
            fname  = entry[3:19].rstrip(b'\xa0').decode('latin-1', 'replace')
            blocks = entry[28] | (entry[29] << 8)
            locked = '<' if ftype & 0x40 else ''
            base   = (ftype & 0x07) | 0x80
            tname  = _D64_TYPE_NAMES.get(base, f'?{ftype:02X}') + locked
            files.append((tname, fname, blocks))
        return files

    def add_file(self, file_data: bytes, petscii_name: str,
                 file_type: str = 'prg') -> None:
        ftype_byte = _D64_FILETYPES.get(file_type.lower(), 0x82)
        if ftype_byte != 0x00:
            ftype_byte |= 0x80

        dir_t = dir_s = dir_off = None
        visited = set()
        last_dir_t, last_dir_s = _D81_DIR_TRACK, _D81_DIR_SECTOR
        t, s = _D81_DIR_TRACK, _D81_DIR_SECTOR
        while t and (t, s) not in visited:
            visited.add((t, s))
            last_dir_t, last_dir_s = t, s
            sec = self._read_sec(t, s)
            if dir_t is None:
                for i in range(8):
                    off = 2 + i * 32
                    e = sec[off:off + 32]
                    if e[0] == 0x00 or not (e[0] & 0x80):
                        dir_t, dir_s, dir_off = t, s, off
                        break
            next_t = sec[0]
            t, s = (next_t, sec[1]) if next_t else (0, 0)

        if dir_t is None:
            new_t, new_s = self._alloc_dir_sector(visited)
            lsec = bytearray(self._read_sec(last_dir_t, last_dir_s))
            lsec[0], lsec[1] = new_t, new_s
            self._write_sec(last_dir_t, last_dir_s, lsec)
            nsec = bytearray(_D81_SEC_SIZE)
            nsec[0], nsec[1] = 0x00, 0xFF
            self._write_sec(new_t, new_s, nsec)
            dir_t, dir_s, dir_off = new_t, new_s, 2

        chunks    = [file_data[i:i + 254] for i in range(0, len(file_data), 254)] or [b'']
        allocated = []
        for chunk in chunks:
            t, s = self._find_free_sector()
            self._bam_alloc(t, s)
            allocated.append((t, s, chunk))

        for i, (t, s, chunk) in enumerate(allocated):
            sec = bytearray(_D81_SEC_SIZE)
            if i + 1 < len(allocated):
                sec[0], sec[1] = allocated[i + 1][0], allocated[i + 1][1]
            else:
                sec[0] = 0x00
                sec[1] = len(chunk) + 1
            sec[2:2 + len(chunk)] = chunk
            self._write_sec(t, s, sec)

        sec   = bytearray(self._read_sec(dir_t, dir_s))
        entry = bytearray(32)
        entry[0]    = ftype_byte
        entry[1]    = allocated[0][0]
        entry[2]    = allocated[0][1]
        entry[3:19] = (petscii_name.upper().encode('ascii', 'replace') + b'\xa0' * 16)[:16]
        n           = len(chunks)
        entry[28]   = n & 0xFF
        entry[29]   = (n >> 8) & 0xFF
        sec[dir_off:dir_off + 32] = entry
        self._write_sec(dir_t, dir_s, sec)

    def remove_file(self, petscii_name: str) -> bool:
        target = petscii_name.upper()
        for dt, ds, doff, entry in self._iter_dir_entries():
            if not (entry[0] & 0x80):
                continue
            fname = entry[3:19].rstrip(b'\xa0').decode('latin-1', 'replace').upper()
            if fname != target:
                continue
            t, s = entry[1], entry[2]
            while t:
                sec    = self._read_sec(t, s)
                nt, ns = sec[0], sec[1]
                self._bam_free_sector(t, s)
                t = nt
                s = ns if nt else 0
            sec       = bytearray(self._read_sec(dt, ds))
            sec[doff] = 0x00
            self._write_sec(dt, ds, sec)
            return True
        return False


# ---------------------------------------------------------------------------
# T64 — Commodore tape archive (read-only: list)
# ---------------------------------------------------------------------------
#
# Header (64 bytes):
#   [0-31]  signature string
#   [32-33] tape version (LE)
#   [34-35] max directory entries (LE)
#   [36-37] used entries (LE)
#   [40-63] tape name
#
# Directory entry (32 bytes each, starting at offset 64):
#   [0]     entry type (1=normal, 3=snapshot)
#   [1]     C64 file type (0=PRG, 1=SEQ, 3=FRZ)
#   [2-3]   start address LE
#   [4-5]   end address LE
#   [8-11]  data offset LE
#   [16-31] filename (space-padded)

_T64_TYPE_NAMES = {0: 'PRG', 1: 'SEQ', 2: 'USR', 3: 'FRZ'}


class T64Image:
    FORMAT = 't64'
    DESC   = 'Commodore Tape Archive'

    def __init__(self, data: bytes, path=None):
        self.data  = data
        self._path = path

    @classmethod
    def create(cls, disk_name: str = 'NEW TAPE', **kw) -> 'T64Image':
        raise NotImplementedError('T64 create: writing tape archives is not supported.')

    @classmethod
    def load(cls, path: Path) -> 'T64Image':
        return cls(path.read_bytes(), path)

    def save(self, path: Path) -> None:
        raise NotImplementedError('T64 save: writing tape archives is not supported.')

    def list_files(self) -> list:
        d = self.data
        if len(d) < 64:
            return [('HEADER', '(invalid T64)', 0)]
        tape_name   = d[40:64].rstrip(b' \x00').decode('latin-1', 'replace')
        max_entries = d[34] | (d[35] << 8)
        used        = d[36] | (d[37] << 8)
        files       = [('HEADER', tape_name, 0)]
        n           = min(max_entries, used, 256)
        for i in range(n):
            base = 64 + i * 32
            if base + 32 > len(d):
                break
            if d[base] == 0:
                continue
            ftype    = d[base + 1]
            start    = d[base+2] | (d[base+3] << 8)
            end      = d[base+4] | (d[base+5] << 8)
            fname    = d[base+16:base+32].rstrip(b' ').decode('latin-1', 'replace')
            size     = max(0, end - start)
            blocks   = max(1, (size + 253) // 254)
            tname    = _T64_TYPE_NAMES.get(ftype, f'T{ftype:02X}')
            files.append((tname, fname, blocks))
        return files

    def add_file(self, d, n, t='prg'):
        raise NotImplementedError('T64 add: writing tape archives is not supported.')

    def remove_file(self, n):
        raise NotImplementedError('T64 remove: writing tape archives is not supported.')


# ---------------------------------------------------------------------------
# P00 — PC64 wrapped PRG file (read-only: list)
# ---------------------------------------------------------------------------
#
# Header (26 bytes):
#   [0-7]   "C64File\0"
#   [8-23]  filename (space-padded)
#   [24]    record size (usually 0)
#   [25]    unused
# Followed by raw PRG data.

class P00Image:
    FORMAT = 'p00'
    DESC   = 'PC64 Wrapped PRG File'

    def __init__(self, data: bytes, path=None):
        self.data  = data
        self._path = path

    @classmethod
    def create(cls, disk_name: str = '', **kw) -> 'P00Image':
        raise NotImplementedError('P00 create: not supported — P00 wraps a single PRG.')

    @classmethod
    def load(cls, path: Path) -> 'P00Image':
        return cls(path.read_bytes(), path)

    def save(self, path: Path) -> None:
        raise NotImplementedError('P00 save: writing P00 files is not supported.')

    def list_files(self) -> list:
        d = self.data
        if len(d) < 26 or d[:7] != b'C64File':
            return [('ERROR', '(invalid P00 header)', 0)]
        fname  = d[8:24].rstrip(b' ').decode('latin-1', 'replace')
        size   = max(0, len(d) - 26)
        blocks = max(1, (size + 253) // 254)
        return [('HEADER', fname, 0), ('PRG', fname, blocks)]

    def add_file(self, d, n, t='prg'):
        raise NotImplementedError('P00 wraps a single file — add is not supported.')

    def remove_file(self, n):
        raise NotImplementedError('P00 wraps a single file — remove is not supported.')


# ---------------------------------------------------------------------------
# Stubs for formats not yet fully implemented
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
        def add_file(self, d, n, t='prg'):
            raise NotImplementedError(f'{self.DESC}: add not yet implemented.')
        def remove_file(self, n):
            raise NotImplementedError(f'{self.DESC}: remove not yet implemented.')
    _Stub.__name__ = key.upper() + 'Image'
    return _Stub


D67Image  = _make_stub('d67',  'Commodore 2040/3040 Disk Image')
D80Image  = _make_stub('d80',  'Commodore 8050 Disk Image')
D82Image  = _make_stub('d82',  'Commodore 8250 Disk Image')
D1MImage  = _make_stub('d1m',  'CMD FD Native Disk Image')
G64Image  = _make_stub('g64',  'GCR Raw Disk Image (1541)')
G71Image  = _make_stub('g71',  'GCR Raw Disk Image (1571)')
NIBImage  = _make_stub('nib',  'Nibble Disk Image (C64)')
NBZImage  = _make_stub('nbz',  'Compressed Nibble Image')
TAPImage  = _make_stub('tap',  'Commodore Tape Pulse Image')
CRTImage  = _make_stub('crt',  'Commodore 64 Cartridge Image')
X64Image  = _make_stub('x64',  'Extended D64 Image')
D13Image  = _make_stub('d13',  'Commodore DOS 2.6 Image')
D90Image  = _make_stub('d90',  'CMD Native Hard Disk Image')


# ---------------------------------------------------------------------------
# Format registry
# ---------------------------------------------------------------------------

FORMATS = {
    'd64':  {'desc': 'Commodore 1541 Disk Image',       'exts': ['.d64'],  'cls': D64Image},
    'd71':  {'desc': 'Commodore 1571 Disk Image',       'exts': ['.d71'],  'cls': D71Image},
    'd81':  {'desc': 'Commodore 1581 Disk Image',       'exts': ['.d81'],  'cls': D81Image},
    't64':  {'desc': 'Commodore Tape Archive',          'exts': ['.t64'],  'cls': T64Image},
    'p00':  {'desc': 'PC64 Wrapped PRG File',           'exts': ['.p00'],  'cls': P00Image},
    'd67':  {'desc': 'Commodore 2040/3040 Disk Image',  'exts': ['.d67'],  'cls': D67Image},
    'd80':  {'desc': 'Commodore 8050 Disk Image',       'exts': ['.d80'],  'cls': D80Image},
    'd82':  {'desc': 'Commodore 8250 Disk Image',       'exts': ['.d82'],  'cls': D82Image},
    'd1m':  {'desc': 'CMD FD Native Disk Image',        'exts': ['.d1m'],  'cls': D1MImage},
    'g64':  {'desc': 'GCR Raw Disk Image (1541)',       'exts': ['.g64'],  'cls': G64Image},
    'g71':  {'desc': 'GCR Raw Disk Image (1571)',       'exts': ['.g71'],  'cls': G71Image},
    'nib':  {'desc': 'Nibble Disk Image (C64)',         'exts': ['.nib'],  'cls': NIBImage},
    'nbz':  {'desc': 'Compressed Nibble Image',         'exts': ['.nbz'],  'cls': NBZImage},
    'tap':  {'desc': 'Commodore Tape Pulse Image',      'exts': ['.tap'],  'cls': TAPImage},
    'crt':  {'desc': 'Commodore 64 Cartridge Image',    'exts': ['.crt'],  'cls': CRTImage},
    'x64':  {'desc': 'Extended D64 Image',              'exts': ['.x64'],  'cls': X64Image},
    'd13':  {'desc': 'Commodore DOS 2.6 Image',         'exts': ['.d13'],  'cls': D13Image},
    'd90':  {'desc': 'CMD Native Hard Disk Image',      'exts': ['.d90'],  'cls': D90Image},
}

_EXT_MAP = {ext: key for key, info in FORMATS.items() for ext in info['exts']}


def detect(path: Path, fmt_hint: str = None) -> str:
    if fmt_hint:
        if fmt_hint in FORMATS:
            return fmt_hint
        raise ValueError(f'Unknown Commodore format: {fmt_hint!r}')
    ext = path.suffix.lower()
    if ext in _EXT_MAP:
        return _EXT_MAP[ext]
    raise ValueError(f'Cannot detect Commodore format from: {path.name}')


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
            print(f'  0  "{name}"  ({size} blocks free)')
            print()
        else:
            print(f'  {size:4d}  {ftype:<6}  "{name}"')
    data = [(t, n, s) for t, n, s in files if t != 'HEADER']
    if data:
        print(f'\n  {sum(s for _, _, s in data)} BLOCKS USED')


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(
        description='Manage Commodore disk images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Formats: ' + ', '.join(FORMATS),
    )
    ap.add_argument('--format', dest='fmt', help='Format key (d64, d71, d81, t64, ...)')
    sub = ap.add_subparsers(dest='command', required=True)

    pc = sub.add_parser('create'); pc.add_argument('image'); pc.add_argument('--name', default='NEW DISK')
    pl = sub.add_parser('list');   pl.add_argument('image')
    pa = sub.add_parser('add');    pa.add_argument('image'); pa.add_argument('file')
    pa.add_argument('--name');     pa.add_argument('--type', default='prg')
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
            img  = load(p, fmt)
            img.add_file(Path(a.file).read_bytes(), name, a.type)
            img.save(p); print(f'Added "{name}" to {p}')
        elif a.command == 'remove':
            img = load(p, fmt)
            if not img.remove_file(a.name.upper()): sys.exit(f'File not found: {a.name}')
            img.save(p); print(f'Removed "{a.name}" from {p}')
    except (ValueError, NotImplementedError, RuntimeError, OSError) as e:
        sys.exit(f'Error: {e}')


if __name__ == '__main__':
    main()
