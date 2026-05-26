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

The following are required but **not included in this repo** (gitignored). You must install these separately:

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
