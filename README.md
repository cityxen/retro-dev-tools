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
| `kickit.py` | Converts assembler byte-data formats (ACME, DASM, Merlin, raw binary, etc.) to KickAssembler `.byte` syntax |
| `kick2xex.py` | Wraps a KickAssembler PRG output as an Atari XEX (strips 2-byte load header, adds `$FFFF` magic and run-address segment at `$02E0`) |
| `kick2apple.py` | Strips KickAssembler PRG header to raw `.bin`; generates a tokenized Applesoft BASIC STARTUP that BRUNs the binary |
| `c64sprites2apple.py` | Converts C64 sprite data (binary or KickAssembler text) to Apple IIe HGR KickAssembler `.byte` data |

#### genkickass-script.py targets

Supported `-t` values: `C64`, `C128`, `VIC20`, `PET`, `DTV`

```
python genkickass-script.py -t C64
python genkickass-script.py -t C128 -e "C:\path\to\x128.exe"
```

#### kickit.py usage

Converts any common byte-data format to KickAssembler syntax.

```
python kickit.py input.asm
python kickit.py chars.bin -o chars.asm -l charset
python kickit.py game.prg --skip 2 -l prg_data
```

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

---

More to come,
Deadline
