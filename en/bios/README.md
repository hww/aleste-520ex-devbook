# README.md — BIOS Aleste 520 EX

## What this is

The Aleste 520 EX BIOS is not a single firmware but a **loadable module** that lives in RAM and is switched together with the machine's mode. In Amstrad mode you work with the Amstrad BIOS from the lower ROM (page 0). In Aleste mode (`MAPMOD=1`) the RAM pages containing the BIOS code are mapped into the address space, and you call it through the **vector table at the start of memory** — exactly as on the MSX or CPC, but with different internals.

The Aleste is a clone of the Amstrad CPC 6128, developed in Omsk in 1993. It can pretend to be a CPC, but under that pretense hides a machine with an MSX-compatible memory mapper, a 64-color palette, an RTC, and a serial port.

## Memory map: three levels

### 1. BIOS vectors (`0000H`–`0165H`)

Starting at address `0000H` there is a table of `JP` instructions. **Call only the vectors, never the addresses behind them** — the internal addresses change from version to version.

```asm
L0000: JP INIT        ; BIOS initialization
L0008: JP INKEY       ; non-blocking input
L0018: JP SYMBOL      ; character output
...
L0069: JP SCR_INIT    ; screen initialization
L00ED: JP KEY_INIT    ; keyboard initialization
L0135: JP MOUS_INIT   ; mouse initialization
L0153: JP COM_INI     ; RS-232 initialization
```

The full list is in `BIOS.MAC`, lines `L0000`–`L0165`. Each vector leads to a specific driver described in a separate document.

### 2. Work area (`0FC00H`–`0FFE0H`)

All BIOS variables live in the upper part of the address space — the analogue of MSX "system variables." Reading is allowed; writing without need is not.

| Address           | What is there                            | Document                         |
|-------------------|------------------------------------------|----------------------------------|
| `0FC00H`          | `GR` — graphics parameter table          | [06-graphics.md](06-graphics.md) |
| `0FCE2H`          | `WORKSPC` — BIOS stack                   | —                                |
| `0FD90H`–`0FDDBH` | Hooks (NMI, Timer, RS-232, KBD, Mouse, …) | [08-errata.md](08-errata.md)     |
| `0FDF5H`          | `EXTPORT` — shadow port `0FABF`          | —                                |
| `0FE09H`/`0FE0AH` | `CSRY`/`CSRX` — cursor                   | [01-screen.md](01-screen.md)     |
| `0FE14H`/`0FE15H` | `INK`/`PAPER` — colors                   | [01-screen.md](01-screen.md)     |
| `0FEA5H`          | `KEYBUF` — key buffer                    | [02-keyboard.md](02-keyboard.md) |
| `0FEE9H`/`0FEEBH` | `MOUS_X1`/`MOUS_Y1` — mouse              | [03-mouse.md](03-mouse.md)       |

### 3. Hooks (`0FD90H`–`0FDDBH`)

Five-byte areas initialized as `RET`. The BIOS calls them at key points. To hook in — write `JP your_code` or `RST 30H` with the page number (the MSX technique). The list of hooks is in `BIOS.MAC`.

## Drivers

| Driver      | File       | What it does                                          | Document                         |
|-------------|------------|-------------------------------------------------------|----------------------------------|
| **Screen**  | `BIOS.SCR` | Characters, cursor, windows, scroll, colors, palette, BEEP | [01-screen.md](01-screen.md)     |
| **Keyboard**| `BIOS.DRV` | Matrix, virtual codes, buffer, modifiers              | [02-keyboard.md](02-keyboard.md) |
| **Mouse**   | `BIOS.DRV` | Coordinates, buttons, limits                          | [03-mouse.md](03-mouse.md)       |
| **RS-232**  | `BIOS.DRV` | Serial port (and the mouse through it)                | [04-serial.md](04-serial.md)     |
| **Printer** | `BIOS.DRV` | Parallel/serial output                                | [05-printer.md](05-printer.md)   |
| **Graphics**| `BIOS.GRP` | Points, lines, rectangles, write modes                | [06-graphics.md](06-graphics.md) |
| **Sprites** | `BIOS.SPR` | RAM↔VRAM copying, sprites                             | [07-sprites.md](07-sprites.md)   |
| **Font**    | `PGT.REL`  |                                                       | [                                |

**Important:** `BIOS.GRP` and `BIOS.SPR` are **not wired into** `BIOS.MAC` via `INCLUDE` in the current package. They are libraries that are linked separately if graphics are needed.

## Known issues

The package is **incomplete**. The main thing: `BIOS.DRV` is truncated at `CTS_INT`, and `COM_OUT`, `COM_IN`, `COM_OUT_ST`, `COM_IN_ST`, `RX_INT`, `TX_INT`, `TEST_TX` are missing. Without them `BIOS.MAC` will not link. Details and workarounds — in [08-errata.md](08-errata.md).

## Build (approximate)

```
BIOS.MAC  ──INCLUDE──► BIOS.SCR
          ──INCLUDE──► BIOS.DRV
          ──INCLUDE──► (BIOS.GRP, BIOS.SPR — add manually)
          ──EXTRN───► ALEST (font, missing)
ROM.MAC   ──EXTRN───► DATA (splash screen, missing), ALEST
```

Build script

```bash
M80=BIOS
L80 /P:0,BIOS,PGT,BIOS/N/E
DEL BIOS.REL
COPY BIOS.COM A:BIOS.SYS
A:RESET
```