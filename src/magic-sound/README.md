# Magic Sound — STM Player for the Aleste 520EX

**Magic Sound** is a Scream Tracker (`.STM`) module player for the **Magic Sound Board**, an expansion card for the **Aleste 520EX** (a Soviet-built MSX2-compatible computer). It loads a `.STM` file from disk, converts it to the board's DMA-based audio format, and plays it back at 50 Hz using the board's 8237 DMA controller and 8254 programmable interval timers.

The source in this repository is a **fully annotated disassembly** of the original 1993 program, reverse-engineered from the released binary and painstakingly verified to be **byte-for-byte identical** to the original `MAGIC.COM`. It is written for the **sjasmplus** Z80 cross-assembler and builds to a raw `.COM` file ready to be added to an MSX-DOS disk image.

---

## Table of contents

- [Magic Sound — STM Player for the Aleste 520EX](#magic-sound--stm-player-for-the-aleste-520ex)
  - [Table of contents](#table-of-contents)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Building](#building)
  - [Creating a bootable disk image](#creating-a-bootable-disk-image)
    - [Installing DskTool on Ubuntu / Debian](#installing-dsktool-on-ubuntu--debian)
    - [Basic usage](#basic-usage)
    - [End-to-end example](#end-to-end-example)
  - [Running](#running)
  - [Project structure](#project-structure)
  - [How it works](#how-it-works)
  - [Verification](#verification)
  - [Limitations](#limitations)
  - [References](#references)

---

## Features

- **Scream Tracker 2 (STM) playback** — supports 4 channels of 8-bit DMA audio (no FM instruments).
- **Full effect set** — portamento up/down, volume slide, vibrato, tremor, note portamento, tempo, jump, break. Arpeggio is implemented but its dispatch is disabled in the original binary.
- **Scroll marquees** — two XOR-shifted scrolling text lines (top and bottom of the screen).
- **VU meters** — four peak-volume bars drawn per channel.
- **Debug print mode** — pressing Space dumps the current note/sample/volume/command/parameter of all four channels to the screen.
- **BIOS-clean exit** — INT 38h and NMI vectors are saved and restored before returning to MSX-DOS.

---

## Requirements

- **Aleste 520EX** hardware (or a cycle-accurate emulator such as **Caprice32 Aleste**) with a **Magic Sound Board** installed.
- **MSX-DOS** (the player uses BDOS calls `01Ah`, `027h`, `00Fh`, `009h`, `002h` and the `0024h` hook).
- A `.STM` module with **version 2** and **2 patterns** (both are checked at load time).
- For building: **sjasmplus** Z80 cross-assembler (v1.20 or newer).
- For disk-image creation: **DskTool** (see below).

---

## Building

The project builds with a single sjasmplus invocation:

```bash
sjasmplus --raw=magic.com magic.asm
```

- `--raw=magic.com` — output a raw binary file named `magic.com`.
- `magic.asm` — the annotated source.

The output `magic.com` is a **raw CP/M-style binary** to be placed in the root of an MSX-DOS disk.

> **Note:** the source contains no macros and no `LOCAL` directives, so it builds with sjasmplus **out of the box**. Older M80/L80 syntax (as found in some historical listings) is not required.

---

## Creating a bootable disk image

The recommended tool is **DskTool**, a classic console utility for creating, listing, extracting and adding files to MSX-DOS `.dsk` images.

### Installing DskTool on Ubuntu / Debian

```bash
sudo add-apt-repository ppa:amaurycarvalho/dsktool
sudo apt-get update
sudo apt-get install dsktool
```

### Basic usage

| Command | Description |
|---------|-------------|
| `dsktool c 720` | Create a new 720 KB disk image. |
| `dsktool l image.dsk` | List files inside an image. |
| `dsktool e image.dsk file.bas` | Extract a file from an image. |
| `dsktool a image.dsk file.bas` | Add a file to an image. |

### End-to-end example

```bash
# 1. Build the player
sjasmplus --raw=magic.com magic.asm

# 2. Create a blank 720 KB MSX-DOS disk
dsktool c 720
# (or: dsktool c 720 alestedos.dsk)

# 3. Add the player and a module to the disk
dsktool a alestedos.dsk magic.com
dsktool a alestedos.dsk demo.stm

# 4. List the image to verify contents
dsktool l alestedos.dsk
```

The resulting `.dsk` can be mounted in an emulator (e.g. **Caprice32 Aleste**) or written to a real floppy for use on the original hardware.

---

## Running

1. Copy `MAGIC.COM` and a `.STM` file to the same disk.
2. At the MSX-DOS prompt, type:
   ```
   MAGIC
   ```
3. The player opens the **first `.STM` file it finds** (the filename is taken from the FCB at `005Ch`). If the extension is not supplied, `STM` is forced.
4. **Keys:**

| Key | Action |
|-----|--------|
| `Space` | Toggle debug-print mode (dumps current notes of all 4 channels). |
| `CR` | Force advance to the next order on the next tick. |
| any other | Stop playback, restore BIOS vectors, return to MSX-DOS. |

---

## Project structure

```
.
├── magic.asm         # Annotated Z80 source (sjasmplus syntax)
├── README.md         # This file
└── (magic.com)       # Build output — not committed
```

The source is organised as follows:

| Section | Contents |
|---------|----------|
| Constants | All hardware ports (`DMA_*`, `TIM_*`, `VOL_*`, `DMAP_*`), memory-mapped variables (`DATA`, `ORDER`, `SEG_A..D`, per-channel offsets, note-decode offsets), and VU-meter registers. |
| `start` / `loop` | Player main loop, key handling, mode switching. |
| `draw_vu_meter` / `draw_line` | VU-meter rendering. |
| `star_enable` / `sub_2E0` / `set_starts` | Marquee animation and initialisation. |
| `clear` | Work-area zeroing. |
| `restore` | Init-table copying and playback-state setup. |
| Channel setup block (A–D) | Per-tick DMA reprogramming (the `MA_START` equivalent). |
| `next_note` / `get_note` / `ret_div` | Pattern decoding and per-channel DMA parameter preparation. |
| `goto` | Order/pattern commands: tempo, jump, break. |
| `command` | Effect dispatch: slide, portamento, vibrato, tremor, arpeggio (disabled). |
| `next_order` | Order advancement and pattern-pointer reconfiguration. |
| `nmi_imp` | 8237 DMA terminal-count handler. |
| `set_interrupt_hook` / `remove_interrupt_hook` | INT 38h and NMI vector management. |
| `init_div` / `inst_div` | Per-instrument divisor-table precomputation. |
| `load_stm_file` | STM file loading and de-interleaving. |
| `print_*` / `open_file` | Console output and file-open helpers. |
| `int_ptr` | 8254 timers + 8237 DMA initialisation. |
| `multiply` / `divide` | 16×16 multiply and 16/16 divide. |
| `init_screen` | Screen mode and initial VU-meters / marquee. |
| Data | Error messages, `loading_message`, `demo_text`, `vibrato_table`. |

---

## How it works

The player uses a single 50 Hz interrupt (INT 38h) for all timing. The handler runs every raster frame and performs four tasks:

1. **Detects a VSYNC pulse** on PPI port B and polls the NMI line to catch any pending DMA completion.
2. **Programs all four DMA channels** from their per-channel state blocks — but only the parts that changed, guarded by `F_START`, `F_DIV` and `F_VOL` flags.
3. **Decrements the row-tick counter** (`TEMP_CONT`). When it reaches zero, the row advances: each channel fetches the next 4-byte note record from its pattern and updates its DMA parameters.
4. **Runs mid-row effects** (volume slide, vibrato, tremor, portamento) once per tick.

The 8237 DMA controller is configured in **single-transfer, increment, read** mode (`48h..4Bh`); on terminal count, the NMI handler reprograms the affected channel with the **loop half** of the sample (`F_RESTART` → autoinit mode `58h..5Bh`).

The 8254 programmable interval timers generate the audio sample clock. Each channel has its own divisor, computed from the note and the instrument's frequency ratio at load time and stored in `I_DIV`.

The screen layout is:
- Four VU-meter bars (rows 19–22), one per channel.
- Two scrolling marquees, top and bottom, XOR-shifted with a rotating mask.

---

## Verification

This source is **byte-for-byte identical** to the original `MAGIC.COM` when built with sjasmplus. After building, verify with:

```bash
cmp mag.com magic.com && echo "IDENTICAL"
```

A silent `cmp` (or the printed message) confirms that the assembled binary matches the reference binary exactly — a strong guarantee that no functional change has been introduced.

---

## Limitations

- **No FM instruments** — sample-only playback.
- **No pattern loop command** — only order jump and break.
- **Arpeggio dispatch is disabled** in the original binary (`cp 0Ah; ret` in `command`). The `arpejio` routine is present but never reached.
- **Vibrato scaling is approximate** — see the `vibrato` routine.
- **One `.STM` at a time** — the player does not implement file selection; it uses whatever filename is in the FCB at `005Ch`.
- **STM version must be exactly 2** with exactly **2 patterns**; anything else triggers an error message.

---

## References

- **Aleste 520EX** — a Soviet MSX2-compatible computer.
- **Magic Sound Board** — a 4-channel 8-bit DMA audio expansion for the Aleste.
- **Scream Tracker 2 (.STM)** — the module format supported by the player.
- **sjasmplus** — Z80 cross-assembler: <https://github.com/z00m128/sjasmplus>
- **DskTool** — MSX-DOS disk-image tool (see installation section above).
- **Caprice32 Aleste** — cycle-accurate Aleste emulator.

---

*This project is provided as-is for historical, educational and preservation purposes. The original Magic Sound player was authored in 1993; the annotated disassembly was produced in 2026 by reverse-engineering the released binary.*