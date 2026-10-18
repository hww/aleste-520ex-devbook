# 02-keyboard.md — Keyboard Driver (BIOS.DRV)

## Purpose

Scans the keyboard matrix on the 50 Hz interrupt, converts key presses into virtual codes, stores them in the `KEYBUF` ring buffer, and provides access either to the buffer (high level) or to the matrix directly (low level). Unlike the CPC, where the keyboard is scanned via the PPI and the `KM_*` functions, here **the matrix is polled in software** through ports `0F4xx`/`0F6xx`, and conversion to ASCII is done via the `NORMTAB`/`SHIFTAB`/`RUSTAB`/`SHRUSTAB` tables.

The driver supports modifiers (`CAPS`, `RUS`, `Shift`, `Ctrl`, `Alt`), auto-repeat with a configurable delay and rate, and audible key feedback.

**Source:** `BIOS.DRV` (included via `INCLUDE BIOS.DRV` in `BIOS.MAC`).

---

## Initialization

### `KEY_INIT` (`L00ED`)

Driver initialization. Copies `KEYINITAB` into the work area (`OLDKEY`…`KEYMOD`), resets the matrix state to `FFH` (all keys released), and zeroes the buffer and counters.

```
Input:  —
Output: —
Modifies: all registers
```
Called from the BIOS `INIT`. Do not call manually.

---

## High-level input

### `READ_KEY` (`L00F6`)

Read a single key from the buffer **without blocking**. Returns a virtual code (not ASCII) and the modifiers.

```
Input:  —
Output: A = C = virtual key code (0 = buffer empty, ZF=1)
        B = modifiers: bit3 CAPS, bit4 RUS, bit5 Shift, bit6 Ctrl, bit7 Alt
Modifies: AF, BC, DE, HL
```
The virtual code is an **index into the table** (`NORMTAB` etc.), not ASCII. To get ASCII use `INPUT`/`INKEY`, or convert manually via `TABCOD1`…`TABCOD4`.

**Example (poll without waiting):**
```asm
    CALL L00F6      ; READ_KEY
    JR   Z,NO_KEY   ; ZF=1 — buffer empty
    ; A = key code, B = modifiers
```

---

### `INPUT` (`L0010`)

Blocking input with cursor display and audible feedback. Waits until a key appears in the buffer, then converts it to ASCII via the tables.

```
Input:  —
Output: A = ASCII code
Modifies: AF, BC, DE, HL
```
Draws the cursor (`PLACE_CUR`) before waiting and erases it (`ERASE_CUR`) after. If sound is enabled (`MODECUR` bit5), emits a short beep via the AY8910.

**Example:**
```asm
    CALL L0010      ; wait for a key press, A = ASCII
    CP   'Q'
    JR   Z,QUIT
```

---

### `INKEY` (`L0008`)

Non-blocking input with conversion to ASCII. If the buffer is empty — `A=0`.

```
Input:  —
Output: A = ASCII code (0 = no key press)
Modifies: AF, BC, DE, HL
```
Does not draw the cursor and does not beep. Calls the `XFDCC` hook (INKEY hook) before reading.

**Example (game loop):**
```asm
LOOP:
    CALL L0008      ; INKEY
    AND  A
    JR   Z,LOOP     ; no key press — continue
    CP   1BH        ; ESC?
    JR   Z,EXIT
    JR   LOOP
```

---

### `TEST_KEY` (`L00F9`)

Check a specific key by virtual code.

```
Input:  A = virtual key code
Output: ZF=1 if pressed
Modifies: AF
```
Internally calls `SNSMAT` for the required row and checks the bit.

**Example (check Shift):**
```asm
    LD   A,15H      ; Shift code
    CALL L00F9
    JR   Z,SHIFT_DOWN
```

---

### `BREAK` (`L00FC`)

Check for `Ctrl+C` (interrupt).

```
Input:  —
Output: CF=1 if Ctrl+C is pressed
Modifies: AF
```
Checks `Ctrl` (code `17H`) and `C` (code `3EH`) via `TEST_KEY`. Used in `LPTOUT` and `COM_IN` to interrupt long operations.

---

## Keyboard buffer

### `TST_KEYBUF` (`L00F0`)

Check whether the buffer is empty.

```
Input:  —
Output: ZF=1 if the buffer is empty
Modifies: AF
```
Compares `GETKEY` and `PUTKEY`. If equal — the buffer is empty.

---

### `CLR_KEYBUF` (`L00F3`)

Clear the buffer. Sets `GETKEY = PUTKEY = KEYBUF`.

```
Input:  —
Output: —
Modifies: HL
```

---

## Low-level matrix access

### `SNSMAT` (`L014D`)

Read one row of the keyboard matrix. This is the **only** way to poll the matrix directly.

```
Input:  D = row number (0–10)
Output: E = data (bit = 0 means pressed)
Modifies: AF
```
The matrix is 11 rows × 8 columns. Row number `D` corresponds to the rows of `NEWKEY`/`OLDKEY` (offset `D` from the start). Bit 7 — the leftmost key in the row, bit 0 — the rightmost (depends on the layout).

**Example (from `TKEY1.MAC` — check Shift at startup):**
```asm
    LD   D,2
    CALL L014D      ; SNSMAT
    BIT  5,E        ; Shift?
    JR   NZ,NO_SHIFT
    ; Shift is pressed — load Aleste
```

**Example (poll the whole matrix):**
```asm
    LD   HL,NEWKEY
    LD   D,0
LOOP:
    CALL L014D
    LD   (HL),E
    INC  HL
    INC  D
    LD   A,D
    CP   11
    JR   NZ,LOOP
```

---

## Key code tables

The driver uses four tables, whose addresses are stored in `TABCOD1`…`TABCOD4`. Each entry is a length byte and an address word.

### `SET_NORM` / `GET_NORM` (`L00FF` / `L0102`)

Set/read the normal key table (`NORMTAB`).

```
Input:  HL = table address (SET_NORM)
Output: HL = address (GET_NORM), A = length
```

---

### `SET_SHIFT` / `GET_SHIFT` (`L0105` / `L0108`)

Shifted key table (`SHIFTAB`).

---

### `SET_RUS` / `GET_RUS` (`L010B` / `L010E`)

Russian key table (`RUSTAB`).

---

### `SET_SHRUS` / `GET_SHRUS` (`L0111` / `L0114`)

Shifted Russian key table (`SHRUSTAB`).

---

## Scan and auto-repeat configuration

### `SET_SCAN` / `GET_SCAN` (`L0117` / `L011A`)

Scan counter: how often `KEY_SCAN` is called in the 50 Hz interrupt. `1` = every frame, `2` = every other frame, etc.

```
Input:  A = value (SET_SCAN)
Output: (GET) A = value
```
Default is `1`.

---

### `SET_REPT` / `GET_REPT` (`L011D` / `L0120`)

Auto-repeat counter: how often a held key repeats (in frames after the delay).

```
Input:  A = value (SET_REPT)
Output: (GET) A = value
```
Default is `2`.

---

### `SET_DELAY` / `GET_DELAY` (`L0123` / `L0126`)

Delay before auto-repeat starts (in frames).

```
Input:  A = value (SET_DELAY)
Output: (GET) A = value
```
Default is `16` (≈320 ms at 50 Hz). `INIT` explicitly sets `16`.

---

## Key sound

### `CLICKON` / `CLICKOFF` (`L0129` / `L012C`)

Enable/disable audible feedback (bit 5 of `MODECUR`).

```
Input:  —
Output: —
Modifies: AF
```
The sound is emitted in `INPUT` via the AY8910 (channel A, registers `08H`/`09H`).

---

## Internal structure (for understanding)

### `KEYB_SCAN`

Scans the whole matrix and writes the result into `NEWKEY` (11 bytes). Called from `KEY_SCAN`.

### `KEY_SCAN`

Compares `NEWKEY` with `OLDKEY`, determines **new** presses (a bit that was `1` became `0`), and for each new press calls `KEY_SCN`. Also updates `KEYMOD` (modifiers) and `REPCNT` (auto-repeat delay).

### `KEY_SCN`

For one matrix row, iterates over 8 bits. If a bit = 0 (press), calls `KEY_SCN2`.

### `KEY_SCN2`

Checks whether it is a modifier (`Alt`, `Shift`, `Ctrl`, `CAPS`, `RUS`). If so — handles it specially (`CAPS`/`RUS` toggle flags in `KEYMOD` and the LED/sound). Otherwise places the **virtual code** (index `C`) into `KEYBUF` via `GETKEY`.

### `INP_KEY`

Takes a code from the buffer, selects the table by `KEYMOD` (RUS/Shift), reads ASCII via `RDSLT` (the table may be in another memory page), applies `Ctrl` (subtracts `40H`) and `CAPS` (inverts the case).

---

## Driver variables

| Address   | Name       | Purpose                    |
|-----------|------------|----------------------------|
| `0FE8FH`  | `OLDKEY`   | Previous matrix state (11 bytes) |
| `0FE9AH`  | `NEWKEY`   | New matrix state (11 bytes) |
| `0FEA5H`  | `KEYBUF`   | Ring buffer of pressed keys (40 bytes) |
| `0FECDH`  | `INTFLAG`  | Frame interrupt flag       |
| `0FECEH`  | `SCNCNT`   | Scan counter               |
| `0FECFH`  | `REPCNT`   | Auto-repeat counter        |
| `0FED0H`  | `BEEPCNT`  | Key sound counter          |
| `0FED1H`  | `GETKEY`   | Write pointer into `KEYBUF` |
| `0FED3H`  | `PUTKEY`   | Read pointer from `KEYBUF` |
| `0FED5H`  | `TABCOD1`  | `NORMTAB` table            |
| `0FED8H`  | `TABCOD2`  | `SHIFTAB` table            |
| `0FEDBH`  | `TABCOD3`  | `RUSTAB` table             |
| `0FEDEH`  | `TABCOD4`  | `SHRUSTAB` table           |
| `0FEE1H`  | `SCAN`     | Scan rate                  |
| `0FEE2H`  | `REPEAT`   | Auto-repeat rate           |
| `0FEE3H`  | `DELAY`    | Auto-repeat delay          |
| `0FEE4H`  | `KEYMOD`   | Modifier state: bit3 CAPS, bit4 RUS, bit5 Shift, bit6 Ctrl, bit7 Alt |

---

## Hooks

| Address   | Name     | When called |
|-----------|----------|-------------|
| `0FDBDH`  | `XFDBD`  | Keyboard Interrupt hook — in `KEY_REPEAT`, before processing |
| `0FDCCH`  | `XFDCC`  | INKEY hook — in `INKEY`, before reading |
| `0FDD1H`  | `XFDD1`  | INPUT hook — in `INPUT`, before waiting |

---

## See also

- [README.md](README.md) — overview and memory map
- [03-mouse.md](03-mouse.md) — mouse (uses the same `KEYMOD`)
- [08-errata.md](08-errata.md) — known issues