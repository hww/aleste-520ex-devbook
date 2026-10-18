# 03-mouse.md — Mouse Driver (BIOS.DRV)

## Purpose

Receives packets from a serial mouse (MS Mouse or PC Mouse) via RS-232, processes them in the RxRDY interrupt (`XFDAE`), and updates the absolute coordinates and button state in the work area. You simply read the result — the driver takes care of receiving, scaling, and clamping to the bounds.

This is **not a CPC mouse** (the CPC 6128 didn't have one). This is a PC mouse via RS-232, and `MOUS_INIT` configures the 8251 and 8253 for the specific protocol. The driver uses the same port as `COM_INI`, so **you cannot use the mouse and RS-232 at the same time** without switching.

**Source:** `BIOS.DRV` (included via `INCLUDE BIOS.DRV` in `BIOS.MAC`).

---

## Initialization

### `MOUS_INIT` (`L0135`)

Mouse driver initialization. Copies `MOUS_TAB` into the work area (`MOUSFLG`…`MOUS_TIP`), configures the 8251 (channel A in mode 3, 1200 baud) and the 8253, and installs the interrupt handlers `XFDAE` (RxRDY) and `XFDA4` (Error).

```
Input:  A = type: 1 = MS Mouse, 2 = PC Mouse
Output: —
Modifies: all registers
```
Called from the BIOS `INIT` with `A=1` (PC Mouse). After initialization the driver is **disabled** (`MOUSFLG=0`) — you need to call `MOUS_ON`.

**Example:**
```asm
    LD   A,1
    CALL L0135      ; MOUS_INIT (PC Mouse)
    CALL L0138      ; MOUS_ON
```

---

### `MOUS_ON` / `MOUS_OFF` (`L0138` / `L013B`)

Enable/disable the driver. When `MOUSFLG=0` the interrupt handler exits immediately without touching the buffer.

```
Input:  —
Output: —
Modifies: AF
```
`MOUS_OFF` does not disable the 8251 interrupts — it only ignores packets. Useful for temporarily "freezing" the mouse.

---

## Reading the state

### `GET_MOUS` (`L013E`)

Returns the current coordinates, button state, and keyboard modifiers.

```
Input:  —
Output: HL = X (0..Xmax)
        DE = Y (0..Ymax)
        A = buttons: bit0 Left, bit1 Middle, bit2 Right
            + modifiers: bit3 CAPS, bit4 RUS, bit5 Shift, bit6 Ctrl, bit7 Alt
Modifies: all registers
```
The coordinates are **absolute**, within the range set by `SET_MLIM`. The origin is the top-left corner (`0,0`).

**Example (game loop with the mouse):**
```asm
LOOP:
    CALL L013E      ; GET_MOUS
    ; HL = X, DE = Y, A = buttons
    BIT  0,A        ; left button?
    JR   NZ,CLICK
    ; ... draw the cursor at (HL,DE) ...
    JR   LOOP
```

---

### `SET_MOUS` (`L0150`)

Set the mouse position in software (without moving the physical mouse).

```
Input:  HL = X, DE = Y
Output: —
Modifies: all registers
```
Useful for centering the cursor or "teleporting" it after a screen change.

---

## Bounds and scale

### `SET_MLIM` (`L0141`)

Set the coordinate bounds. Also **resets** the current position to `(0,0)`.

```
Input:  HL = Xmax, DE = Ymax
Output: —
Modifies: —
```
Default is `Xmax=639`, `Ymax=199` (from `MOUS_TAB`). For a 320×200 screen it makes sense to use `Xmax=319`, `Ymax=199`.

**Example:**
```asm
    LD   HL,319
    LD   DE,199
    CALL L0141      ; SET_MLIM
```

---

### `GET_MLIM` (`L0144`)

Returns the current bounds.

```
Input:  —
Output: HL = Xmax, DE = Ymax
Modifies: —
```

---

### `SET_MSCAL` (`L0147`)

Set the scale: how many mouse "ticks" make up one pixel. The larger the scale, the slower the cursor moves.

```
Input:  H = X scale, L = Y scale
Output: —
Modifies: —
```
Default is `1` (from `MOUS_TAB`). A value of `2` = the cursor moves twice as slowly.

**Example:**
```asm
    LD   HL,0202H   ; X scale = 2, Y scale = 2
    CALL L0147      ; SET_MSCAL
```

---

### `GET_MSCAL` (`L014A`)

Returns the current scale.

```
Input:  —
Output: H = X scale, L = Y scale
Modifies: —
```

---

## Internal structure (for understanding)

### Packet format

MS Mouse and PC Mouse use a **3-byte packet**:

```
Byte 0: 1 0 0 LB RB Y7 Y6 X7 X6   (sync bits + buttons + high bits)
Byte 1: X7..X0 (signed X delta)
Byte 2: Y7..Y0 (signed Y delta)
```

`MOUS_INT` checks that the first byte has `10xxxxxx` (sync bits), otherwise it ignores it. Packets are accumulated in `RX_BUF`, and when 5 bytes have accumulated, `MOUS_INT2` is called, which updates the coordinates.

### `MOUS_INT`

RxRDY handler. Reads a byte from port `0EEH`, checks the sync bits, and puts it into `RX_BUF`. When the buffer overflows (`RX_BUF+5`), it calls `MOUS_INT2`.

### `MOUS_INT2`

Parses the 3-byte packet:
- `IX+00` — buttons and high bits
- `IX+01` — X delta
- `IX+02` — Y delta

The deltas are **signed** (`JP M` for negative). For each delta:
1. It is added to the counter (`MOUS_X`/`MOUS_Y`).
2. The scale (`MOUS_SCLX`/`MOUS_SCLY`) is subtracted in a loop while the counter ≥ scale.
3. Each subtraction = +1 to the coordinate.
4. The coordinate is clamped to `MOUS_XMAX`/`MOUS_YMAX`.

At the end the `XFDC2` hook (Mouse move hook) is called.

### `MOUS_ERR`

RS-232 error handler (vector `XFDA4`). Resets the buffer and the 8251 state.

---

## Driver variables

| Address   | Name        | Purpose                    |
|-----------|-------------|----------------------------|
| `0FEE5H`  | `MOUSFLG`   | `0` = disabled, `<>0` = enabled |
| `0FEE6H`  | `MOUS_K`    | Button state (bit0–2)      |
| `0FEE7H`  | `MOUS_Y`    | Y delta counter            |
| `0FEE8H`  | `MOUS_X`    | X delta counter            |
| `0FEE9H`  | `MOUS_Y1`   | Absolute Y coordinate (word) |
| `0FEEBH`  | `MOUS_X1`   | Absolute X coordinate (word) |
| `0FEEDH`  | `MOUS_YMAX` | Maximum Y (default 199)    |
| `0FEEFH`  | `MOUS_XMAX` | Maximum X (default 639)    |
| `0FEF1H`  | `MOUS_SCLY` | Y scale (default 1)        |
| `0FEF2H`  | `MOUS_SCLX` | X scale (default 1)        |
| `0FEF3H`  | `MOUS_TIP`  | Mouse type: 0 = PC, 1 = MS |

---

## Hooks

| Address   | Name     | When called |
|-----------|----------|-------------|
| `0FDA4H`  | `XFDA4`  | RS-232 Error — redirected to `MOUS_ERR` |
| `0FDAEH`  | `XFDAE`  | RS-232 RxRDY — redirected to `MOUS_INT` |
| `0FDC2H`  | `XFDC2`  | Mouse move hook — at the end of `MOUS_INT2` |

---

## Limitations

1. **Mouse and RS-232 are incompatible.** Both use the same 8251 and the same `RX_BUF`/`TX_BUF` buffers. If you want to use RS-232 for communication, first call `MOUS_OFF`, then `COM_INI`.

2. **Only 3-button and 2-button mice.** `MOUS_TIP` distinguishes PC (2 buttons) and MS (3 buttons), but `MOUS_INT2` handles `MOUS_K` the same way — bits 0–2.

3. **No wheel.** The driver does not support a scroll wheel (it didn't exist in 1993).

4. **Bounds are reset by `SET_MLIM`.** If you want to preserve the position, call `SET_MOUS` after `SET_MLIM`.

---

## See also

- [README.md](README.md) — overview and memory map
- [02-keyboard.md](02-keyboard.md) — keyboard (shared `KEYMOD`)
- [04-serial.md](04-serial.md) — RS-232 (shared port)
- [08-errata.md](08-errata.md) — known issues