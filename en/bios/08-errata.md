# 08-errata.md — Known Issues of the Package

## Purpose

This document records everything that is **missing, truncated, or not wired in** in the provided source package. If you are trying to build the firmware — start here. If you are studying the code — here are listed the places where context is missing.

---

## 1. `BIOS.DRV` — truncated at `CTS_INT`

The file breaks off at the comment `; Прерывание по готовности пер◀` (should be "…передачи", i.e. "…transmission"). **7 symbols** referenced in the visible code are missing:

| Symbol | Who references it | Purpose | Document |
|--------|-------------------|---------|----------|
| `TEST_TX` | `CTS_INT` (`CALL TEST_TX`) | XON/XOFF / transmit readiness check | [04-serial.md](04-serial.md) |
| `RX_INT` | `COM_INI` (`LD (XFDAE+1),HL`) | RxRDY handler (receive a byte into `RX_BUF`) | [04-serial.md](04-serial.md) |
| `TX_INT` | `COM_INI` (`LD (XFDB3+1),HL`) | TxRDY handler (send a byte from `TX_BUF`) | [04-serial.md](04-serial.md) |
| `COM_OUT_ST` | `BIOS.MAC` `L0156` | RS-232 output readiness check | [04-serial.md](04-serial.md) |
| `COM_OUT` | `BIOS.MAC` `L0159` | output a byte to RS-232 | [04-serial.md](04-serial.md) |
| `COM_IN_ST` | `BIOS.MAC` `L015C` | RS-232 input readiness check | [04-serial.md](04-serial.md) |
| `COM_IN` | `BIOS.MAC` `L015F` | receive a byte from RS-232 | [04-serial.md](04-serial.md) |

**Consequence:** `BIOS.MAC` **does not link**. Vectors `L0156`–`L015F` reference undefined symbols.

**How to restore:**
1. Disassemble the finished firmware at addresses `XFDB3` (TxRDY), `XFDAE` (RxRDY), and vectors `L0156`–`L015F`.
2. Or write your own implementations according to the description in [04-serial.md](04-serial.md) (reconstruction from the context of `COM_INI` and `CTS_INT`).

---

## 2. External resources

| Symbol | Where declared | Status | What to do |
|--------|----------------|--------|-----------|
| `ALEST` | `EXTRN` in `BIOS.MAC`, `ROM.MAC` | **missing** (character generator) | Extract from the finished firmware or find a separate font file |
| `DATA` | `EXTRN` in `ROM.MAC` | **missing** (splash screen) | Extract from the finished firmware or draw your own |
| `COLORS` | `BIOS.MAC`: `PALTAB EQU 0FE7FH; DS 10H,COLORS` | **not defined** | Replace with `0` — `PALTAB` is initialized via `PAL_INIT` from `PALINITAB` anyway |

**Consequence:** without `ALEST` character output does not work (`SYMBOL2` reads the font via `PGTADR`). Without `DATA` the splash screen on cold reboot (`RE_BOOT`) does not work.

---

## 3. `BIOS.GRP` and `BIOS.SPR` are not wired into `BIOS.MAC`

The current `BIOS.MAC` contains only:
```asm
INCLUDE BIOS.SCR
INCLUDE BIOS.DRV
```

`BIOS.GRP` and `BIOS.SPR` are present in the package but **not wired in**. They are libraries that were linked separately (or included in a different version of the main module).

**Consequence:** the functions `PUT_PIXEL`, `GET_PIXEL`, `GR_LINE`, `HORIZ_LINE`, `VERT_LINE`, `FILL_RECTANGLE`, `DRAW_SPRITE`, `UNDRAW_SPRITE`, `COPY_M_TO_V`, `COPY_V_TO_M`, `COPY_V_TO_V` are **not available** through the BIOS vectors. The vectors `L0162` (`FMESSXY`) and `L0165` (`INVERT`) exist, but those are not graphics.

**How to fix:** add to `BIOS.MAC` before `END`:
```asm
INCLUDE BIOS.GRP
INCLUDE BIOS.SPR
```

**The order matters:** `BIOS.SPR` uses `GR_GET_ADR`, `WR_PIX`, `NEXT_LINE`, `TAB_CONV_*` from `BIOS.GRP`, so `BIOS.GRP` must come first.

**Additionally:** `BIOS.GRP` uses `DIVISION`, which is defined in itself, and `WR_PSG`, `CPHLDE`, `CPHLBC` from `BIOS.MAC`. `BIOS.SPR` uses `BUFSYM1`/`BUFSYM2` from `BIOS.SCR`. So the order is:
```
BIOS.SCR
BIOS.DRV
BIOS.GRP
BIOS.SPR
```

---

## 4. `COLORS` is not defined

In `BIOS.MAC`:
```asm
PALTAB EQU 0FE7FH; DS 10H,COLORS
```

`COLORS` is not defined anywhere — neither in `BIOS.SCR`, nor in `BIOS.GRP`, nor in `BIOS.DRV`. This is most likely an artifact: `PALTAB` is initialized via `PAL_INIT` from `PALINITAB`, so `COLORS` can be replaced with `0`.

**How to fix:** in `BIOS.MAC` replace the line with:
```asm
PALTAB EQU 0FE7FH; DS 10H,0
```

---

## 5. `ROM.MAC` — simplified `SNSMAT` without `DI/EI`

`ROM.MAC` contains its own `SNSMAT` (for the loader), which does **not** do `DI`/`EI` at the start/end. The version in `BIOS.MAC` does. For the loader this is acceptable (interrupts are not yet enabled), but it is **not equivalent** to the `BIOS.MAC` version. If you copy `SNSMAT` from `ROM.MAC` into your code — add `DI`/`EI` yourself.

---

## 6. `MOUSE1.MAC` — debug output to ports `0FAD0H/0FAD2H`

The `MOUSE1.MAC` example writes mouse coordinates to ports `0FAD0H`/`0FAD2H`. This is probably debug output (DAC/indicator), not standard peripherals. In real code these ports should not be used.

---

## 7. `BIOS.DRV` — `LPTOUT_3` writes to the AY8910

`LPTOUT_3` writes `0FH` to the AY8910 (register `0FH`) on every byte sent to the printer. This may be a diagnostic signal, but it **interferes** if you use the AY8910 for music. If the printer is not needed — do not call `LPTOUT`. If it is needed — you can replace `CALL WR_PSG` with `NOP`/`RET`.

---

## 8. `BIOS.DRV` — `CTS_INT` does not link

`CTS_INT` contains `CALL TEST_TX`, but `TEST_TX` is missing. Even if you restore `COM_OUT`/`COM_IN`, `CTS_INT` still will not assemble without `TEST_TX`. See item 1.

---

## 9. What **is** there and works

To avoid creating a false impression, let us list what is **fully present** in the package:

| Component | Status |
|-----------|--------|
| `BIOS.MAC` (vectors, `INIT`, `INT38`, slots, `WR_PSG`/`RD_PSG`, `WR_CLOCK`/`RD_CLOCK`, `WR_CRT`/`RD_CRT`, `WAIT`, `CHGRUS`, `SNSMAT`, timer) | ✅ complete |
| `BIOS.SCR` (screen, cursor, ESC, scroll, palette, BEEP) | ✅ complete |
| `BIOS.DRV` — keyboard (`KEY_INIT`, `KEY_SCAN`, `KEY_SCN`, `READ_KEY`, `INPUT`, `INKEY`, `TEST_KEY`, `BREAK`, tables, `SET_*/GET_*`) | ✅ complete |
| `BIOS.DRV` — mouse (`MOUS_INIT/ON/OFF`, `GET_MOUS`, `SET_MOUS`, `SET_MLIM`, `SET_MSCAL`, `MOUS_INT`, `MOUS_ERR`) | ✅ complete |
| `BIOS.DRV` — printer (`LPTOUT`, `LPTSTT`) | ✅ complete |
| `BIOS.DRV` — RS-232 (`COM_INI`, `RS_ERR`, `CTS_INT`) | ⚠️ partial (no tail) |
| `BIOS.GRP` (graphics) | ✅ complete |
| `BIOS.SPR` (sprites) | ✅ complete |
| `ROM.MAC` (loader, `SETUP`, i8272 FDC) | ✅ complete |
| `TKEY1.MAC`, `KEY.MAC`, `MOUSE1.MAC` (examples) | ✅ complete |

---

## 10. Summary

**For studying the code** the package is sufficient. All drivers, except the RS-232 tail, are presented in full, with comments and examples.

**To build the firmware** you need to:
1. Restore the 7 RS-232 symbols (item 1).
2. Find or extract `ALEST` and `DATA` (item 2).
3. Replace `COLORS` with `0` (item 4).
4. Add `INCLUDE BIOS.GRP` and `INCLUDE BIOS.SPR` to `BIOS.MAC` (item 3).

After that `BIOS.MAC` should assemble (given a Z80 assembler that supports `.PHASE`/`.DEPHASE`/`INCLUDE`/`EXTRN` — for example, `ZSM`, `TASM`, `sjasmplus`).

---

## See also

- [README.md](README.md) — overview and memory map
- [01-screen.md](01-screen.md) — screen
- [02-keyboard.md](02-keyboard.md) — keyboard
- [03-mouse.md](03-mouse.md) — mouse
- [04-serial.md](04-serial.md) — RS-232 (reconstruction)
- [05-printer.md](05-printer.md) — printer
- [06-graphics.md](06-graphics.md) — graphics
- [07-sprites.md](07-sprites.md) — sprites