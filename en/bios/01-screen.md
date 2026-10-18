# 01-screen.md — Screen Driver (BIOS.SCR)

## Purpose

Manages character output, the cursor, output windows, scrolling, colors, and the palette. Unlike the CPC, there is **no fixed screen** here — you define a window via `SET_SIZE`, and all output is confined to its bounds. This is closer to the MSX approach with a programmable window than to the CPC's fixed 40×24.

The driver supports four screen modes (640×200×2, 320×200×4, 640×200×4, 320×200×16), switched via `SET_SCRMOD`. Each mode has its own VRAM layout and its own default palette.

**Source:** `BIOS.SCR` (included via `INCLUDE BIOS.SCR` in `BIOS.MAC`).

---

## Initialization and screen mode

### `SCR_INIT` (`L0069`)

Screen initialization. Copies `SCRINITAB` into the work area (`WUP`…`GRPHED`) and calls `SET_SCRMOD` with `A=0, B=0, C=0` (640×200×2 mode, black text on black background).

```
Input:  —
Output: —
Modifies: all registers
```
Called from the BIOS `INIT`. Do not call manually.

---

### `SET_SCRMOD` (`L0081`)

Set the screen mode. Switches the VRAM layout, the default palette, the MC6845 registers, and the `VRAMADR`/`WYWOD`/`WIDTH`/`ROLL3`/`ROLSTR`/`CURON`/`CUROFF` vectors.

```
Input:  A = mode: 0 = 640×200×2, 1 = 320×200×4, 2 = 640×200×4, 3 = 320×200×16
        B = text color
        C = background color
Output: —
Modifies: all registers
```
After the call the screen is cleared (`CLS`) and enabled (`ENA_SCR`). The vectors are reconfigured via a `JP` table, so old `SYMBOL` calls automatically land in the new code.

---

### `GET_SCRMOD` (`L0084`)

Returns the current mode.

```
Input:  —
Output: A = mode (0–3)
```

---

### `DIS_SCR` / `ENA_SCR` (`L006C` / `L006F`)

Screen off and on (bit 3 of `EXTPORT`).

```
Input:  —
Output: —
Modifies: AF
```
Does not clear VRAM — only disables output. Useful for instant clearing without flicker: `DIS_SCR` → clear → `ENA_SCR`.

---

## Character output

### `SYMBOL` (`L0018`)

The main way to print. Outputs a character at the current cursor position and handles control codes (`CR`, `LF`, `TAB`, `DEL`, `ESC` sequences).

```
Input:  A = character code (0–255)
Output: —
Modifies: AF, BC, DE, HL
```
If `A` is a control code (0–1FH), the corresponding function from `CTRLTAB` is executed (for example, `0CH` = `CLS`, `0DH` = `CR`). If `A=1BH` (`ESC`), parsing of an ESC sequence begins.

**Example:**
```asm
    LD  A,'H'
    CALL L0018      ; output 'H' at the current position
    LD  A,0DH
    CALL L0018      ; CR
    LD  A,0AH
    CALL L0018      ; LF
```

---

### `WR_SYMBOL` (`L0072`)

Output a character at a **given** position, without changing the cursor and without handling control codes.

```
Input:  A = character code, H = X, L = Y
Output: —
Modifies: AF
```
Used when you need to draw a character at a specific place (for example, in `SETUP` from `ROM.MAC`).

---

### `MESSAGE` (`L007B`)

Output a string with handling of all control codes, at the current cursor position.

```
Input:  DE = string address (terminated by 0)
Output: —
Modifies: all registers
```
**Example:**
```asm
    LD  DE,TEXT
    CALL L007B
    ...
TEXT: DB 'Hello, Aleste!',0
```

---

### `MESSAGE1` (`L0075`)

Output a string **without** handling control codes, at position `[HL]`.

```
Input:  DE = string address (0), H = X, L = Y
Output: —
Modifies: all registers
```
Faster than `MESSAGE`, but does not handle `CR`/`LF`/`TAB`. Used in `SETUP` for outputting fixed strings.

---

### `FMESSXY` (`L0162`)

Fast output of a string at position `[HL]` **directly into VRAM**, bypassing buffers and mode handling. Used in `SETUP` for speed.

```
Input:  DE = string (0), H = X, L = Y
Output: —
Modifies: all registers
```
Does not support `MODES` (underline, inverse, wide, grid) or `SYMMOD` (AND/OR/XOR). Direct write only.

---

### `SET_FONT` / `GET_FONT` (`L0087` / `L008A`)

Font appearance: underline, inverse, wide, grid.

```
Input:  A = bit mask: bit0 underline, bit1 inverse,
                       bit2 wide, bit3 grid
Output: (GET) A = current mask
```
`SET_FONT` only writes `MODES`; the actual application happens in `SYMBOL2` during output.

---

### `SET_MODE` / `GET_MODE` (`L008D` / `L0090`)

Character output mode: `NORMAL`, `AND`, `OR`, `XOR`.

```
Input:  A = 0 (NORMAL), 1 (AND), 2 (OR), 3 (XOR)
Output: (GET) A = current mode
```
In `XOR` mode a character inverts the background without erasing it. This is **not a hardware feature** but a software one — `WYWOD_XOR`/`WYWODH_XOR` in `BIOS.SCR`.

**Example (blinking cursor via XOR):**
```asm
    LD  A,3
    CALL L008D      ; SET_MODE XOR
    LD  A,' '
    CALL L0018      ; invert the character cell
    ; ... delay ...
    LD  A,' '
    CALL L0018      ; restore it
```

---

## Output window

### `SET_SIZE` (`L0093`)

Set the bounds of the output window. All subsequent `SYMBOL`/`MESSAGE` output is confined to this window, and `SCROLL` works only within it.

```
Input:  H = X of the top-left corner, L = Y
        B = height, C = width
Output: —
Modifies: all registers
```
The coordinates are adjusted according to the current screen mode (`SETSIZE0`). The cursor moves to the top-left corner of the window.

**Example (a 20×10 window in the bottom-right corner):**
```asm
    LD  HL,0028H    ; X=40, Y=0
    LD  BC,0A14H    ; height=10, width=20
    CALL L0093
```

---

### `GET_SIZE` (`L0096`)

Returns the current window bounds.

```
Input:  —
Output: HL = X,Y of the top-left corner
        BC = height, width
Modifies: AF
```

---

### `SCROLL` (`L0078`)

Screen scrolling within the window. If the window coincides with the full screen, **hardware scrolling** via `SET_BASE` is used (fast). Otherwise — software (`L_SCROL1`/`H_ROLL`).

```
Input:  B = 0 (scroll down), otherwise (scroll up)
Output: —
Modifies: all registers
```
Called automatically from `SYMBOL` when the window overflows.

---

## Cursor

### `CUR_INIT` (`L00CC`)

Cursor initialization: `MODECUR=0A0H` (cursor on, insert off, sound off), color `0FH`, shape `CURFORM`.

```
Input:  —
Output: —
```

---

### `ENA_CUR` / `DIS_CUR` (`L00CF` / `L00D2`)

Enable/disable the cursor (bit 7 of `MODECUR`).

```
Input:  —
Output: —
Modifies: AF
```

---

### `INSERT_ON` / `INSERT_OFF` (`L00D5` / `L00D8`)

Insert mode (bit 6 of `MODECUR`). Changes the cursor shape (`CURNORM` ↔ `CURINS`).

```
Input:  —
Output: —
Modifies: AF
```

---

### `SET_CUR` / `GET_CUR` (`L00DB` / `L00DE`)

Set/read the cursor position.

```
Input:  H = X, L = Y (SET_CUR)
Output: H = X, L = Y (GET_CUR)
```
`SET_CUR` adds the window offset (`WUP`) and adjusts via `CSRPOS`. `GET_CUR` subtracts `WUP`.

---

### `PLACE_CUR` / `ERASE_CUR` (`L00E7` / `L00EA`)

Draw/erase the cursor. Saves the background in `BUFCUR`, then XOR-restores it.

```
Input:  —
Output: —
Modifies: all registers
```
Called automatically from `INPUT` (blocking input).

---

### `SET_CURINK` / `GET_CURINK` (`L00E1` / `L00E4`)

Cursor color.

```
Input:  A = color (0–15)
Output: (GET) A = color
```

---

## Colors and palette

### `SET_INK` / `GET_INK` (`L00B1` / `L00B4`)

Character color.

```
Input:  A = color (0–15)
Output: (GET) A = color
```
In mode 0 (`640×200×2`) the color is converted to a 2-bit mask via `PALINITB1`. In modes 1–2 — to a 4-bit mask, in mode 3 — to an 8-bit mask.

---

### `SET_PAPER` / `GET_PAPER` (`L00B7` / `L00BA`)

Background color.

```
Input:  A = color (0–15)
Output: (GET) A = color
```

---

### `SET_BORDER` / `GET_BORDER` (`L00BD` / `L00C0`)

Border color (0–63).

```
Input:  A = color (0–63)
Output: (GET) A = color
```
Writes directly to port `7FFFH` (bits 0–5).

---

### `PAL_INIT` (`L00C3`)

Initialize the default palette for the current mode. Called from `SET_SCRMOD`.

```
Input:  —
Output: —
```

---

### `SET_PAL` / `GET_PAL` (`L00C6` / `L00C9`)

Set/read the palette for a specific color.

```
Input:  A = color number, E = palette value (SET_PAL)
Output: (GET) E = palette value
```
Writes to port `7FFFH`: first the color number, then `E | 40H`.

---

## PGT (character generator)

### `SET_PGT` / `GET_PGT` (`L0099` / `L009C`)

Set/read the address and page of the character generator.

```
Input:  HL = PGT address, A = page number (SET_PGT)
Output: HL = address, A = page (GET_PGT)
```
By default `PGTADR = ALEST`, `PGTPAGE = 8`.

---

## VRAM pages and base

### `SET_VPAGE` / `GET_VPAGE` (`L00A5` / `L00A8`)

Set/read the logical and physical VRAM page.

```
Input:  A = bit0-1 logical page, bit4-5 physical (SET_VPAGE)
Output: A = current value (GET_VPAGE)
```
In modes 0–1, 2 logical pages are used; in modes 2–3 — 1 (because of the doubled size).

---

### `SET_BASE` / `GET_BASE` (`L00AB` / `L00AE`)

Set/read the address of the start of the image. If the physical page matches the logical one, programs the MC6845 (registers 12/13).

```
Input:  HL = address (SET_BASE)
Output: HL = address (GET_BASE)
```

---

## Miscellaneous

### `BEEP` (`L00A2`)

Sound signal. Three kinds (1, 2, 3); parameters (tone, volume) are read from the RTC (register `1BH`).

```
Input:  —
Output: —
Modifies: all registers
```
Uses channels A and B of the AY8910.

---

### `INVERT` (`L0165`)

Invert character cells in VRAM.

```
Input:  HL = X,Y, B = number of cells
Output: —
Modifies: all registers
```
Inverts 8 bytes (one character cell) for `B` consecutive cells.

---

### `CLS` (`L007E`)

Clear the screen with the background color.

```
Input:  —
Output: —
Modifies: all registers
```

---

### `DEL` (`L007F`? — internal)

Delete the character under the cursor, shifting the line left. Called via `SYMBOL` when `A=7FH`.

---

## Driver variables

| Address   | Name       | Purpose                    |
|-----------|------------|----------------------------|
| `0FE05H`  | `WUP`      | Window top boundary        |
| `0FE06H`  | `WLEFT`    | Window left boundary       |
| `0FE07H`  | `WDOWN`    | Window bottom boundary     |
| `0FE08H`  | `WRIGHT`   | Window right boundary      |
| `0FE09H`  | `CSRY`     | Cursor Y                   |
| `0FE0AH`  | `CSRX`     | Cursor X                   |
| `0FE0BH`  | `PGTPAGE`  | PGT page                   |
| `0FE0CH`  | `PGTADR`   | PGT address                |
| `0FE0EH`  | `SCRMOD`   | Screen mode                |
| `0FE0FH`  | `MODES`    | Font appearance            |
| `0FE10H`  | `SYMMOD`   | Output mode                |
| `0FE11H`  | `BASE`     | Screen start address       |
| `0FE13H`  | `VPAGE`    | VRAM pages                 |
| `0FE14H`  | `INK`      | Character color            |
| `0FE15H`  | `PAPER`    | Background color           |
| `0FE16H`  | `BORDER`   | Border color               |
| `0FE17H`  | `BUFSYM1`  | PGT buffer (8 bytes)       |
| `0FE1FH`  | `BUFSYM2`  | Output buffer (32 bytes)   |
| `0FE3FH`  | `SAVECUR`  | Saved cursor position      |
| `0FE41H`  | `ESCBUF`   | ESC sequence buffer        |
| `0FE49H`  | `ESCADR`   | Pointer into `ESCBUF`      |
| `0FE4BH`  | `ESCCNT`   | ESC counter                |
| `0FE4CH`  | `GRPHED`   | Pseudographics flag        |
| `0FE4DH`  | `MODECUR`  | Cursor mode                |
| `0FE4EH`  | `CURINK`   | Cursor color               |
| `0FE4FH`  | `BUFCUR`   | Cursor background buffer   |
| `0FE6FH`  | `CURNORM`  | Normal cursor shape        |
| `0FE77H`  | `CURINS`   | Insert cursor shape        |
| `0FE7FH`  | `PALTAB`   | Palette tables             |

---

## See also

- [README.md](README.md) — overview and memory map
- [06-graphics.md](06-graphics.md) — graphics (`BIOS.GRP`)
- [08-errata.md](08-errata.md) — known issues