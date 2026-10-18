# 07-sprites.md — Sprites and Block Copying (BIOS.SPR)

## Purpose

Copying blocks between RAM and VRAM, between different VRAM pages, and drawing/erasing sprites. Works in all four screen modes, uses `GR_GET_ADR`, `WR_PIX`, `NEXT_LINE`, `TAB_CONV_*`, `TAB_ST_MSK_*` from `BIOS.GRP`.

**Important:** `BIOS.SPR` is **not wired into** `BIOS.MAC` via `INCLUDE` in the current package. It is a separate library that must be linked after `BIOS.GRP` (because it uses its functions).

**Source:** `BIOS.SPR` (separate).

---

## Copying RAM → VRAM

### `COPY_M_TO_V`

Copies a block from memory into VRAM.

```
Input:  _X1 = length of a row in memory (bytes)
        _Y1 = source address in memory
        _X2 = destination X in VRAM
        _Y2 = destination Y in VRAM
        _DX = width along X
        _DY = height along Y
        _SRC_PAGE = source memory page
        _DST_PAGE = destination VRAM page
        _WRT_MOD
        _CLIP, _XMN_CLIP, _XMX_CLIP, _YMN_CLIP, _YMX_CLIP
Output: —
Modifies: all registers
```

**What it does:** clips the coordinates to the clipping bounds (`TEST_XY_F`), then for each row reads bytes from memory (`IX`) and lays them out into VRAM pixels via `WR_PIX`. Takes the screen mode into account (`COPY_MV_M_0` for 2 colors, `COPY_MV_M_3` for 16 colors, the general case for 4 colors).

**Example (output an 8-byte picture at (10,20)):**
```asm
    LD   HL,8
    LD   (_X1),HL       ; length = 8 bytes
    LD   HL,BITMAP
    LD   (_Y1),HL       ; source address
    LD   HL,10
    LD   (_X2),HL       ; X = 10
    LD   HL,20
    LD   (_Y2),HL       ; Y = 20
    LD   HL,8
    LD   (_DX),HL       ; width = 8
    LD   HL,1
    LD   (_DY),HL       ; height = 1
    XOR  A
    LD   (_SRC_PAGE),A
    LD   (_DST_PAGE),A
    LD   (_WRT_MOD),A
    LD   (_CLIP),A
    CALL COPY_M_TO_V
...
BITMAP: DB 0FFH,81H,81H,81H,81H,81H,81H,0FFH
```

---

## Copying VRAM → RAM

### `COPY_V_TO_M`

Copies a block from VRAM into memory.

```
Input:  _X1 = source X in VRAM
        _Y1 = source Y in VRAM
        _X2 = length of a row in memory (bytes)
        _Y2 = destination address in memory
        _DX = width along X
        _DY = height along Y
        _SRC_PAGE = source VRAM page
        _DST_PAGE = destination memory page
Output: —
Modifies: all registers
```

**What it does:** `COPY_VM_GET` computes the number of bytes along X and the number of shifts, then `COPY_VM_MAIN` for each row reads bytes from VRAM (`IX`) and packs them into memory bytes (`IY`). Takes the screen mode into account.

---

## Copying VRAM → VRAM

### `COPY_V_TO_V`

Copies a block within VRAM (between different pages or within one).

```
Input:  _X1, _Y1 = source coordinates
        _X2, _Y2 = destination coordinates
        _DX = width along X
        _DY = height along Y
        _SRC_PAGE, _DST_PAGE
Output: —
Modifies: all registers
```

**What it does:** `COPY_VV_GET` computes the masks and the number of shifts (taking into account the difference between source and destination X), then `COPY_VV_MAIN` copies byte by byte taking the shift into account. If the shift is negative (`COPY_VV_MAIN_L`), it copies from right to left.

**Example (copy a 50×20 rectangle from (10,20) to (100,40)):**
```asm
    LD   HL,10
    LD   (_X1),HL
    LD   HL,20
    LD   (_Y1),HL
    LD   HL,100
    LD   (_X2),HL
    LD   HL,40
    LD   (_Y2),HL
    LD   HL,50
    LD   (_DX),HL
    LD   HL,20
    LD   (_DY),HL
    XOR  A
    LD   (_SRC_PAGE),A
    LD   (_DST_PAGE),A
    CALL COPY_V_TO_V
```

---

## Sprites

### `DRAW_SPRITE`

Draws a 16×16 sprite with a mask and colors.

```
Input:  HL = Y, DE = X
        B = foreground color (FG)
        C = background color (BG)
        _SDBPTR = pointer to the Sprite Definition Block (SDB)
        _SPRBUF = pointer to the sprite buffer
        _DST_PAGE
Output: —
Modifies: all registers
```

**SDB format:** 32 words (64 bytes). Each row is two words:
- `DW mask` (16 bits: 1 = draw the pixel)
- `DW bits` (16 bits: 1 = FG, 0 = BG)

**Sprite buffer format:** 16 rows × N bytes (N depends on the mode: 3 for 2 colors, 5 for 4 colors, 9 for 16 colors). The buffer stores the **background under the sprite**, so that `UNDRAW_SPRITE` can restore it.

**What it does:**
1. Saves the background under the sprite into `_SPRBUF` (via `LDIR` from VRAM).
2. For each SDB row calls `DRW_S_VDI`, which bitwise applies the mask and color using `WR_PIX_0` (Replace).
3. Restores the VRAM bank.

**Example:**
```asm
    LD   HL,50      ; Y
    LD   DE,100     ; X
    LD   B,7        ; FG = white
    LD   C,0        ; BG = black
    LD   (_SDBPTR),SDB
    LD   (_SPRBUF),SPRBUF
    CALL DRAW_SPRITE
...
SDB:    ; 16 rows of 2 words
    DW 0FFFFH, 0FFFFH   ; row 0: mask all 1, color all 1
    DW 0FFFFH, 0FFFFH
    ; ...
SPRBUF: DS 16*9,0       ; buffer for 16 colors
```

---

### `UNDRAW_SPRITE`

Erases the sprite by restoring the background from `_SPRBUF`.

```
Input:  HL = Y, DE = X
        _SPRBUF = pointer to the sprite buffer
        _DST_PAGE
Output: —
Modifies: all registers
```

**What it does:** copies `_SPRBUF+2` (the background) back into VRAM, row by row. Uses `LDIR` with a `NEXT_LINE` step.

**Example (erase the sprite):**
```asm
    LD   HL,50
    LD   DE,100
    LD   (_SPRBUF),SPRBUF
    CALL UNDRAW_SPRITE
```

---

### `DRW_S_VDI`

Internal function: draws one sprite row. Reads the mask and bits from the SDB (`IX`), applies `_FG_COLOR`/`_BG_COLOR`, writes via `WR_PIX_0`.

```
Input:  IX = pointer to the current SDB row (4 bytes)
        HL = VRAM address
        B = 16 (pixels in the row)
        C = mask (from GR_GET_ADR)
Output: —
```

**Logic:** for each of the 16 pixels it shifts the mask and bits, forms the color byte (`_FG_COLOR & C | D`), forms the mask (`E | C`), and calls `WR_PIX_0`. If the mask bit = 0 — the pixel is not drawn (transparent).

---

## Internal structure

### `COPY_GET_PRM`

Computes the parameters for `COPY_M_TO_V`:
- `E'` = starting mask
- `C'` = ending mask
- `C` = number of shifts
- `E` = number of bytes along X

Takes the screen mode into account (`TAB_ST_MSK_0` for 2 colors, `TAB_ST_MSK_1` for 4/16 colors).

### `COPY_VM_GET`

Computes the parameters for `COPY_V_TO_M`: the number of bytes along X and the number of shifts.

### `COPY_VV_GET`

Computes the parameters for `COPY_V_TO_V`: the starting mask (`E'`), the ending mask (`A'`), the number of shifts (`C`), the number of bytes along X (`E`). If the shift is negative, `COPY_VV_MAIN` calls `NEG` and copies from right to left (`COPY_VV_MAIN_L`).

### `COPY_VV_MAIN`

Copies one VRAM → VRAM row. For each source byte it reads two bytes (the current and the next), shifts and assembles the destination byte, and calls `WR_PIX`.

---

## Limitations

1. **Not wired into `BIOS.MAC`.** You need to add `INCLUDE BIOS.SPR` manually after `BIOS.GRP`.
2. **Depends on `BIOS.GRP`.** Uses `GR_GET_ADR`, `WR_PIX`, `NEXT_LINE`, `TAB_CONV_*`, `TAB_ST_MSK_*`. Link after `BIOS.GRP`.
3. **Sprites are 16×16 only.** The SDB format is fixed (32 words). For sprites of other sizes you need to write your own function.
4. **The sprite buffer must be large enough.** For mode 3 (16 colors) you need `16×9 = 144` bytes per sprite (plus 2 header bytes `_SPRBUF+0/+1` — the VRAM page).
5. **No hardware blitter.** Everything is copied byte by byte via the Z80. `COPY_V_TO_V` over a large area can take a noticeable amount of time.

---

## See also

- [README.md](README.md) — overview and memory map
- [06-graphics.md](06-graphics.md) — graphics (basic functions)
- [01-screen.md](01-screen.md) — screen (modes, VRAM pages)
- [08-errata.md](08-errata.md) — known issues