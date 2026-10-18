# 06-graphics.md — Low-Level Graphics (BIOS.GRP)

## Purpose

Drawing library: points, lines (Bresenham), horizontal and vertical lines, filled rectangles, sprites. Works in all four screen modes, with write modes (`Replace`, `AND`, `OR`, `XOR`, `Transparent`) and clipping.

**Important:** `BIOS.GRP` is **not wired into** `BIOS.MAC` via `INCLUDE` in the current package. It is a separate library that must be linked manually. It depends on `BIOS.SCR` (variables `SCRMOD`, `PALTAB`, `BUFSYM1`, `BUFSYM2`) and on `BIOS.MAC` (`WR_PSG`, `CPHLDE`, `CPHLBC`, `DIVISION`).

For the CPC programmer this is a replacement for the `GRA_*` functions, but with a **different API**: you fill in fields in the `GR` table (`0FC00H`) and call a function. No registers with coordinates — everything through memory.

**Source:** `BIOS.GRP` (separate).

---

## `GR` parameter table (`0FC00H`)

All functions read arguments from this table. Fill in the fields before calling.

| Offset | Name | Size | Purpose |
|--------|------|------|---------|
| `+00` | `_X1` | word | X1 |
| `+02` | `_Y1` | word | Y1 |
| `+04` | `_X2` | word | X2 |
| `+06` | `_Y2` | word | Y2 |
| `+08` | `_DX` | word | Width along X |
| `+10` | `_DY` | word | Height along Y |
| `+12` | `_SRC_PAGE` | byte | Source page |
| `+13` | `_DST_PAGE` | byte | Destination page |
| `+14` | `_ARG` | byte | Flags: bit0 X1/Y1 — address, bit1 X2/Y2 — address, bit2 X direction, bit3 Y direction |
| `+15` | `_WRT_MOD` | byte | Write mode: 0 Replace, 1 AND, 2 OR, 3 XOR, 4 Transparent, 5 AND, 6 OR, 7 XOR |
| `+16` | `_FG_COLOR` | byte | Foreground color |
| `+17` | `_BG_COLOR` | byte | Background color |
| `+18` | `_LN_MASK` | word | Line mask (for dashing) |
| `+20` | `_PATPTR` | long | Pointer to the fill pattern |
| `+24` | `_PATMSK` | word | Number of lines in the pattern (0 = no pattern) |
| `+26` | `_CLIP` | byte | Clipping flag (0 = none) |
| `+27` | `_XMN_CLIP` | word | Left clipping boundary |
| `+29` | `_YMN_CLIP` | word | Top boundary |
| `+31` | `_XMX_CLIP` | word | Right boundary |
| `+33` | `_YMX_CLIP` | word | Bottom boundary |
| `+35` | `_SDBPTR` | long | Pointer to the Sprite Definition Block |
| `+39` | `_SPRBUF` | long | Pointer to the sprite buffer |
| `+64` | `WR_PIX` | 3 | Pixel write vector |
| `+67` | `WR_LINE` | 3 | Line write vector |
| `+70` | `GR_PAPER` | byte | Background color (internal) |
| `+71` | `GR_INK` | byte | Foreground color (internal) |

---

## Initialization

### `GRAPH_INIT`

Clears the `GR` table (zeroes 0DFH bytes), sets `_FG_COLOR=3`, `_WRT_MOD=0`, and calls `CLS`.

```
Input:  —
Output: —
Modifies: all registers
```
Call after `SCR_INIT`.

---

### `SET_WRITE_MODE` / `GET_WRITE_MODE`

Set/read the write mode.

```
Input:  A = mode (0–7)
Output: (GET) A = mode
```
Installs the `WR_PIX` and `WR_LINE` vectors via a `JP` table. Mode 4 — `Transparent` (transparent background, only `_FG_COLOR` is drawn).

---

## Points

### `PUT_PIXEL`

Draws a point.

```
Input:  DE = X, HL = Y, A = color (0–15)
        _WRT_MOD, _DST_PAGE
Output: —
Modifies: AF
```
The color is converted via `TRANS_COLOR` depending on the screen mode. Then `GR_GET_ADR` computes the VRAM address and mask, and `WR_PIX` writes the byte.

**Example:**
```asm
    LD   DE,100     ; X=100
    LD   HL,50      ; Y=50
    LD   A,7        ; color 7
    CALL PUT_PIXEL
```

---

### `GET_PIXEL`

Reads the color of a point.

```
Input:  DE = X, HL = Y
        _SRC_PAGE
Output: A = color (0–15)
Modifies: AF
```

---

## Lines

### `GR_LINE`

Draws a line using Bresenham's algorithm between `(_X1,_Y1)` and `(_X2,_Y2)`.

```
Input:  _X1, _Y1, _X2, _Y2
        _FG_COLOR, _BG_COLOR, _WRT_MOD, _DST_PAGE, _LN_MASK
Output: —
Modifies: all registers
```
The line is automatically clipped to the clipping bounds (`_CLIP`). `_LN_MASK` is the dash mask (bit 1 = draw, bit 0 = skip).

**Example (diagonal):**
```asm
    LD   HL,0
    LD   (_X1),HL   ; X1=0
    LD   (_Y1),HL   ; Y1=0
    LD   HL,319
    LD   (_X2),HL   ; X2=319
    LD   HL,199
    LD   (_Y2),HL   ; Y2=199
    LD   A,7
    LD   (_FG_COLOR),A
    CALL GR_LINE
```

---

### `HORIZ_LINE`

Horizontal line from `(_X1,_Y1)` to `(_X2,_Y1)` with a fill pattern.

```
Input:  _X1, _X2, _Y1, _FG_COLOR, _BG_COLOR, _WRT_MOD, _DST_PAGE
        _PATPTR, _PATMSK, _CLIP, _XMN_CLIP, _XMX_CLIP, _YMN_CLIP, _YMX_CLIP
Output: —
```
If `_PATMSK=0`, the line is solid. Otherwise `_PATPTR` points to an array of pattern words, and `_PATMSK` is the number of rows in the pattern.

---

### `VERT_LINE`

Vertical line from `(_X1,_Y1)` to `(_X1,_Y2)`.

```
Input:  _X1, _Y1, _Y2, _FG_COLOR, _BG_COLOR, _WRT_MOD, _DST_PAGE
Output: —
```

---

## Rectangles

### `FILL_RECTANGLE`

Filled rectangle from `(_X1,_Y1)` to `(_X2,_Y2)` with a fill pattern.

```
Input:  _X1, _Y1, _X2, _Y2
        _FG_COLOR, _BG_COLOR, _WRT_MOD, _DST_PAGE
        _PATPTR, _PATMSK, _CLIP, _XMN_CLIP, _XMX_CLIP, _YMN_CLIP, _YMX_CLIP
Output: —
Modifies: all registers
```
If `_PATMSK=0`, the rectangle is filled with solid `_FG_COLOR`. Otherwise — with the pattern from `_PATPTR`.

**Example (solid rectangle):**
```asm
    LD   HL,10
    LD   (_X1),HL
    LD   HL,20
    LD   (_Y1),HL
    LD   HL,100
    LD   (_X2),HL
    LD   HL,80
    LD   (_Y2),HL
    LD   A,7
    LD   (_FG_COLOR),A
    XOR  A
    LD   (_PATMSK),A
    CALL FILL_RECTANGLE
```

---

## Clipping

### `TEST_XY_F`, `TEST_XY`, `TEST_XY_L`, `TEST_XY_H`, `TEST_XY_V`

Internal clipping functions. Called automatically from `GR_LINE`/`HORIZ_LINE`/`VERT_LINE`/`FILL_RECTANGLE` if `_CLIP<>0`.

```
Input:  coordinates + _CLIP + _XMN_CLIP/_XMX_CLIP/_YMN_CLIP/_YMX_CLIP
Output: CF=1 if the object is entirely outside the bounds (do not draw)
        CF=0 if it needs to be drawn (coordinates adjusted)
```

**Rule:** if `_CLIP=0`, clipping is disabled and the functions return `CF=1` (draw). If `_CLIP<>0`, the coordinates are clipped to the window `_XMN_CLIP.._XMX_CLIP` / `_YMN_CLIP.._YMX_CLIP`.

---

## Internal structure (for understanding)

### `GR_GET_ADR`

Converts `(X,Y)` into a physical VRAM address and mask. This is the **key function** used by `PUT_PIXEL`, `GET_PIXEL`, `GR_LINE`, `HORIZ_LINE`, `VERT_LINE`, `FILL_RECTANGLE`, `COPY_*` (from `BIOS.SPR`), and `DRAW_SPRITE`.

```
Input:  HL = Y, DE = X, A = page
Output: HL = VRAM address, A = page, C = mask
```
The VRAM layout depends on the mode (`SCRMOD`):
- Mode 0 (640×200×2): 80 bytes/row, mask `80H..01H`.
- Mode 1 (320×200×4): 80 bytes/row, mask `88H..11H` (2 bits per pixel).
- Mode 2 (640×200×4): 160 bytes/row, mask `88H..11H`.
- Mode 3 (320×200×16): 160 bytes/row, mask `AAH/55H` (4 bits per pixel).

The address is always in the range `4000H..7FFFH` (VRAM), with `SET 6,H` / `RES 7,H` for the correct bank.

---

### `WR_PIX_0..3`, `WR_LINE_*`

Write vectors. `SET_WRITE_MODE` substitutes a `JP` to the required variant:

| Mode | `WR_PIX` | `WR_LINE` (for `HORIZ_MAIN`) |
|------|----------|------------------------------|
| 0 Replace | `WR_PIX_0` | `WR_LINE_*_0` |
| 1 AND | `WR_PIX_1` | `WR_LINE_*_1` |
| 2 OR | `WR_PIX_2` | `WR_LINE_*_2` |
| 3 XOR | `WR_PIX_3` | `WR_LINE_*_3` |
| 4 Transparent | `WR_PIX_0` (with mask) | `WR_LINE_*_4` |
| 5 AND | `WR_PIX_1` | `WR_LINE_*_5` |
| 6 OR | `WR_PIX_2` | `WR_LINE_*_6` |
| 7 XOR | `WR_PIX_3` | `WR_LINE_*_7` |

`WR_LINE_*` are optimized for batch writing (8 pixels at a time) and are used in `HORIZ_MAIN`.

---

### `TRANS_COLOR`

Converts a logical color (0–15) into a physical mask for the current mode.

```
Input:  A = logical color
Output: A = mask (for WR_PIX)
```
In mode 0 (2 colors) — `00H/FFH`. In modes 1–2 (4 colors) — `00H/C0H/0CH/CCH/…`. In mode 3 (16 colors) — `00H/C0H/0CH/…/FFH`.

---

### `CONV_LN_MASK`

Unrolls `_LN_MASK` (word) into `GR_BUFFER` (16 bytes) for `HORIZ_LINE`. Takes the screen mode into account.

---

### `NEXT_LINE` / `PREV_LINE`

Move to the next/previous VRAM row. Takes the screen mode and bank into account (`SET 6,H` / `RES 7,H`).

---

### `DIVISION`

Division `HL / DE` (for `GR_LINE` and `FILL_RECTANGLE`). Returns `HL = quotient`, `DE = remainder`.

---

## Limitations

1. **Not wired into `BIOS.MAC`.** You need to add `INCLUDE BIOS.GRP` manually.
2. **Depends on `BIOS.SCR`.** Uses `SCRMOD`, `PALTAB`, `BUFSYM1`, `BUFSYM2`. Link after `BIOS.SCR`.
3. **Depends on `BIOS.MAC`.** Uses `WR_PSG`, `CPHLDE`, `CPHLBC`, `DIVISION` (the last one is in `BIOS.GRP`).
4. **No hardware acceleration.** Everything is drawn in software, byte by byte. `FILL_RECTANGLE` over the full 320×200×16 screen can take a noticeable amount of time.

---

## See also

- [README.md](README.md) — overview and memory map
- [01-screen.md](01-screen.md) — screen (shared variables)
- [07-sprites.md](07-sprites.md) — sprites (uses `GR_GET_ADR`, `WR_PIX`)
- [08-errata.md](08-errata.md) — known issues