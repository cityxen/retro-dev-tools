# CityXen Retro Dev Tools
#### 8 & 16 bit hijinx and programming!

Assembly include libraries and build tooling for retro computer development, maintained by Deadline / CityXen.

This repo provides a shared library of reusable 6502/6510 assembly modules and helper scripts, used across multiple retro platform projects. The include libraries are designed to be referenced directly from your project's assembler config.

---

## Repo Contents

### `cityxen-tools/`

Build helper scripts for Windows.

| Script | Description |
|---|---|
| `KickAss.bat` | Wrapper that invokes KickAssembler (`KickAss.jar`) with a generated config file |
| `genkickass-script.bat` | Calls `genkickass-script.py` — pass arguments through |
| `genkickass-script.py` | Generates a `KickAss_AutoGen.cfg` for a target machine and emulator |
| `kickit.py` | Converts ACME, DASM, Merlin, raw binary, etc. source code files to KickAssembler source code |
| `kick2xex.py` | Wraps a KickAssembler PRG output as an Atari XEX (strips 2-byte load header, adds `$FFFF` magic and run-address segment at `$02E0`) |
| `kick2apple.py` | Strips KickAssembler PRG header to raw `.bin`; generates a tokenized Applesoft BASIC STARTUP that BRUNs the binary |
| `c64sprites2apple.py` | Converts C64 sprite data (binary or KickAssembler text) to Apple IIe HGR KickAssembler `.byte` data |
| `diskimage.py` | Create and manage retro disk images across multiple platforms — routes to per-platform sub-modules |

#### genkickass-script.py targets

Supported `-t` values: `C64`, `C128`, `VIC20`, `PET`, `DTV`

```
python genkickass-script.py -t C64
python genkickass-script.py -t C128 -e "C:\path\to\x128.exe"
```

#### kickit.py usage

Converts ACME, DASM, Merlin, Prog8, raw binary, etc. to KickAssembler `.byte` syntax.

```
python kickit.py input.asm
python kickit.py chars.bin   -o chars.asm  -l charset
python kickit.py game.prg    --skip 2      -l prg_data
python kickit.py sprites.p8  -o sprites.asm
```

| Input | Detected by | Extracted as |
|---|---|---|
| KickAssembler / CA65 | `.byte` keyword | as-is |
| ACME / 64tass | `!byte` keyword | `.byte` |
| DASM | `dc.b` keyword | `.byte` |
| Merlin | `dfb` keyword | `.byte` |
| Raw binary | `.bin` `.raw` `.prg` ext | `.byte` |
| **Prog8** | `.p8` ext | `ubyte[]`/`uword[]` → `.byte`/`.word`; `const ubyte/uword` → `.const`; literal `.byte`/`.char` inside `%asm` blocks |

#### kick2xex.py usage

Wraps a KickAssembler PRG as a standard Atari XEX with a run-address segment.

```
python kick2xex.py prg_files\game.prg prg_files\game.xex
```

#### kick2apple.py usage

Strips the KickAssembler PRG header and generates a ProDOS-ready binary plus an Applesoft STARTUP.

```
python kick2apple.py prg_files\game.prg prg_files\game.bin
python kick2apple.py prg_files\game.prg prg_files\game.bin --brun GAME
python kick2apple.py prg_files\game.prg prg_files\game.bin --no-startup
```

#### diskimage.py usage

Creates and manages disk images for retro platforms. The platform sub-module and disk format are both auto-detected from the file extension. Use `--format` to override when the extension is ambiguous or you need a specific format.

```
python diskimage.py list   image.d64
python diskimage.py list   image.atr
python diskimage.py list   image.dsk          # auto-detects DOS 3.3 or ProDOS

python diskimage.py create output.d64         [--name "DISK NAME"]
python diskimage.py create output.po          [--name VOLNAME]
python diskimage.py create output.atr

python diskimage.py add    image.d64  game.prg  [--name GAME] [--type prg|seq|usr]
python diskimage.py add    image.atr  game.xex  [--name GAME.XEX]
python diskimage.py add    image.po   game.bin  [--name GAME]  [--type bin|sys|bas|txt]

python diskimage.py remove image.d64  GAME
python diskimage.py remove image.po   PRODOS

# Override platform or format explicitly
python diskimage.py --format appleii  list   ambiguous.img
python diskimage.py --format po       list   prodos.dsk
python diskimage.py --format commodore list  somefile.img
```

#### Platform sub-modules and format auto-detection

The `--format` flag accepts either a **platform name** (routes all formats for that platform) or a **format key** (selects exactly one format).

| Platform | Module | Extensions handled |
|---|---|---|
| Commodore | `diskimage-commodore.py` | `.d64` `.d71` `.d81` `.t64` `.g64` `.p00` and more |
| Atari 8-bit | `diskimage-atari.py` | `.atr` `.xfd` `.atx` `.st` `.msa` and more |
| Apple II | `diskimage-appleii.py` | `.dsk` `.do` `.po` `.hdv` `.nib` `.2mg` `.woz` and more |
| Amiga | `diskimage-amiga.py` | `.adf` `.dms` `.hdf` `.ipf` and more |
| Mac | `diskimage-mac.py` | `.dc42` `.toast` `.image` and more |
| DOS/PC | `diskimage-dos.py` | `.ima` `.img` `.td0` `.imd` and more |
| Console | `diskimage-console.py` | `.fds` `.iso` `.gdi` `.chd` and more |

#### Apple II formats

Apple II disk images use several format conventions. `diskimage.py` auto-detects the filesystem from the file content, not just the extension — in particular, `.dsk` files are sniffed to tell apart DOS 3.3, ProDOS block-ordered, and DOS-sector-ordered ProDOS images.

| Format key | Extension(s) | Description |
|---|---|---|
| `dsk` | `.dsk` | Apple DOS 3.3 (35 tracks × 16 sectors, 143360 bytes) |
| `do` | `.do` | DOS-order image — same layout as `dsk` |
| `po` | `.po` | ProDOS block-ordered (143360 bytes or larger) |
| `do-po` | *(auto)* | DOS-sector-ordered image containing a ProDOS filesystem — auto-detected from `.dsk`/`.do` files; read/write remaps sectors transparently |
| `hdv` | `.hdv` | Apple IIgs ProDOS hard disk volume (ProDOS block-ordered, up to ~32 MB) |
| `nib` | `.nib` | Nibblized GCR image (232960 bytes, read-only listing) |
| `2mg` | `.2mg` `.2img` | Universal Apple II container — wraps DOS 3.3, ProDOS, or NIB inner image |
| `woz` | `.woz` | WOZ flux image (stub — listing not yet implemented) |

**Format auto-detection for `.dsk` / `.do` files:**

1. Check for a ProDOS volume header after remapping sectors using the DOS→ProDOS interleave table → detected as `do-po`
2. Check for a ProDOS volume header at ProDOS block offsets → detected as `po`
3. Check for a valid DOS 3.3 VTOC (track 17, sector 0) → detected as `dsk`

This means `ip65.dsk`, `prodos.dsk`, and genuine `dos33.dsk` are all handled correctly without any `--format` flag.

---

#### c64sprites2apple.py usage

Converts C64 sprite data to Apple IIe HGR `.byte` blocks. Each C64 sprite row (24 pixels, 3 bytes) is repacked into Apple HGR format (7 pixels/byte, bit 0 = leftmost). Outputs a label per sprite with an ASCII pixel preview on each row.

```
python c64sprites2apple.py sprites.bin -o sprites.asm
python c64sprites2apple.py sprites.asm -o sprites.asm -l spr_player
python c64sprites2apple.py sprites.bin --multicolor --sprites 4
python c64sprites2apple.py sprites.bin -p 1 -l enemy
```

| Flag | Description |
|---|---|
| `-n N` / `--sprites N` | Convert only the first N sprites (default: all) |
| `-l` / `--label` | Label prefix for output blocks (`spr_data0`, `spr_data1`, …) |
| `-m` / `--multicolor` | Treat input as multi-color C64 sprites (2 bits per pixel) |
| `--no-stretch` | Multi-color: keep at 12px / 2 HGR bytes wide (default doubles pixels to 24px / 4 bytes) |
| `-p 0\|1` / `--palette` | HGR palette bit: `0` = violet/green (default), `1` = blue/orange |
| `-f binary\|kickass` | Force input format (default: auto-detect by file extension) |

---

### `include/`

Reusable assembly include libraries, organized by platform. Each platform folder contains a core library set plus inline library modules (`.il.asm` files).

| Platform | Folder | Assembler |
|---|---|---|
| Commodore 64 | `include/commodore64/` | KickAssembler |
| Commodore 128 | `include/commodore128/` | KickAssembler |
| Commodore 16 / Plus/4 | `include/commodore16/` | KickAssembler |
| Commodore VIC-20 | `include/vic20/` | KickAssembler |
| Commodore PET | `include/pet/` | KickAssembler |
| Atari 8-bit | `include/atari8bit/` | KickAssembler |
| Apple IIe | `include/appleiie/` | KickAssembler |

#### Common library modules (varies by platform)

- `CityXenLib.asm` / `CityXenLibCode.asm` — Main library entry points
- `Constants.asm` — Platform constants
- `Macros.asm` / `PrintMacros.asm` — Macro definitions
- `Music.asm` / `SpriteManagement.asm` — Platform-specific subsystems
- Inline modules: `print`, `input`, `string`, `random`, `score`, `rle`, `sfxkit`, `sprite`, `timers`, `sys`, `disk`, `userport`, and more

---

## Dependencies

The following are required but **not included in this repo**. You must install these separately:

- **KickAssembler** (`dev-tools/commodore64/KickAssembler/KickAss.jar`) - required
- **Emulators**
- **Java** - required to run KickAssembler
- **Python 3** - required to run the `cityxen-tools` scripts

---

## Installation

```
git clone https://github.com/cityxen/retro-dev-tools
```

Reference the `include/` folder for your target platform in your assembler config or build script.

Add `cityxen-tools/` to your system environment path.

---

More to come,
Deadline
