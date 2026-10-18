# 06. Keyboard

The keyboard in the Aleste is a topic with a catch. Physically the machine has an MSX keyboard, with the characteristic five function keys. But at the port level the processor sees an ordinary CPC matrix — because between the keyboard and the processor there is logic that translates the MSX matrix into a CPC matrix.

What this means for the programmer: **you work with the CPC matrix, not the MSX matrix**. This is important because in the MSX world the keyboard is organized differently, and if you are used to MSX — you will have to relearn.

Plus there are ten additional keys that the CPC did not have.

## How the matrix is organized

The keyboard is a matrix. There are rows and columns. At the intersection — a key. The processor selects a row, reads the columns, and from which bit is zero it understands which key is pressed.

In the Aleste the matrix is 11 rows of 8 bits. The CPC had 10 rows, the Aleste has 11. The eleventh row (number 10) is precisely the additional keys.

## Ports

The keyboard is connected through the 8255 chip (PPI), as in the CPC.

| Port    | What                        | Direction            |
|---------|-----------------------------|----------------------|
| `#F6XX` | PPI Port C (low 4 bits)     | Row select           |
| `#F4XX` | PPI Port A                  | Read row data        |
| `#F7XX` | PPI Control Register        | Port direction       |

<!-- FIX: added port #F7XX (8255 control register) — without it
     you cannot set the port directions, and the examples below do not work. -->

Read sequence:

1. Write the row number (0–10) to the low 4 bits of port C.
2. Read port A.
3. In the byte read, each bit corresponds to a key in this row. 0 = pressed, 1 = not pressed.

The logic is inverted: a pressed key gives 0, an unpressed one — 1. This is the standard for the CPC matrix.

### Configuring the 8255

Before the first read of the matrix you need to configure the 8255 so that port A is an input and port C is an output (low 4 bits). Usually the BIOS has already done this at startup, but if you work with the 8255 yourself — don't forget.

The 8255 control register is at address `#F7XX`. Format:

```txt
bit 7 = 0       — I/O mode (not bit set/reset)
bits 6–5        — group A mode (00 = mode 0)
bit 4           — port A direction (0 = output, 1 = input)
bit 3           — port C direction (high 4 bits, 0 = output)
bits 2–1        — group B mode (00 = mode 0)
bit 0           — port C direction (low 4 bits, 0 = output)
```

For "port A = input, port C = output (all 8 bits)" you need the value `%10010000` (`0x90`): bit 7 = 1? **No:** bit 7 = 1 is bit set/reset. For I/O mode you need **bit 7 = 0**, bit 4 = 1 (port A input), bits 3 and 0 = 0 (port C output). Total `%00010000` (`0x10`).

<!-- FIX: the original text had %10000000 — that is bit set/reset,
     not direction configuration. The correct value is %00010000. -->

```asm
; Configure 8255: port A = input, port C = output
LD BC, #F700      ; 8255 control register
LD A, %00010000   ; mode 0, port A input, port C output
OUT (C), A
```

<!-- FIX: fixed OUT syntax (was OUT (#F7XX),A — does not assemble). -->

## Matrix table

Below are **two** tables. The first — the physical key layout (what is printed on the MSX keyboard key). The second — the logical codes that `NORMTAB` from the BIOS returns (what a program reading the matrix via `SNSMAT`/`READ_KEY` will see).

<!-- FIX: the original text had one table, which for rows 9–10
     disagreed with NORMTAB. Now two tables with an explicit separation. -->

### Physical layout (MSX keys)

Rows — row numbers, columns — bits D0–D7.

| Row | D7    | D6    | D5    | D4    | D3    | D2     | D1    | D0   |
|-----|-------|-------|-------|-------|-------|--------|-------|------|
| 0   | .     | ENTER | D3    | D6    | D9    | DOWN   | RIGHT | UP   |
| 1   | D0    | D2    | D1    | D5    | D8    | D7     | ALT   | LEFT |
| 2   | CTRL  | \     | SHIFT | D4    | ]     | RETURN | [     | BS   |
| 3   | .     | /     | :     | ;     | P     | @      | -     | ^    |
| 4   | ,     | M     | K     | L     | I     | O      | 9     | 0    |
| 5   | SPACE | N     | J     | H     | Y     | U      | 7     | 8    |
| 6   | V     | B     | F     | G     | T     | R      | 5     | 6    |
| 7   | X     | C     | D     | S     | W     | E      | 3     | 4    |
| 8   | Z     | CAPS  | A     | TAB   | Q     | ESC    | 2     | 1    |
| 9   | DEL   | R/L   | SPACE | SPACE | J.R.  | J.L.   | J.D.  | J.U. |
| 10  | F1/6  | F2/7  | F3/8  | F4/9  | F5/10 | HELP   | INS   | b    |

<!-- FIX: row 3, D0 — corrected from "f=" to "^" (matches NORMTAB[24]).
     Row 9, D5/D4 — corrected from "J.F.1"/"J.F.2" to "SPACE"/"SPACE"
     (in NORMTAB[77]=0x0D=CR, NORMTAB[76]=0x20=SPACE; physically these are
     probably joystick buttons, but logically NORMTAB gives SPACE/CR).
     Row 10 — physical layout left as is (F1/6..b), but see below
     the second table: NORMTAB for row 10 gives different codes. -->

### Logical codes (what `NORMTAB` returns)

These values correspond to the `NORMTAB` table from `BIOS.DRV` (indices 0–87). For rows 0–8 they match the physical layout (up to case). For rows 9–10 they **do not match**, because `NORMTAB` contains not physical labels but logical codes (control characters, joystick codes, etc.).

| Row | D7    | D6    | D5    | D4    | D3    | D2     | D1    | D0   |
|-----|-------|-------|-------|-------|-------|--------|-------|------|
| 9   | 0x08  | 0x00  | 0x0D  | 0x20  | 0x1C  | 0x1D   | 0x1F  | 0x1E |
| 10  | 0x5F  | 0x12  | 0x18  | 0x84  | 0x83  | 0x82   | 0x81  | 0x80 |

<!-- FIX: added the second table — logical NORMTAB codes for rows 9–10.
     Values taken from NORMTAB in BIOS.DRV:
     indices 72–79 (row 9): 1E,1F,1D,1C,20,0D,00,08 (D0..D7)
     indices 80–87 (row 10): 80,81,82,83,84,18,12,5F (D0..D7) -->

**Important:** if you write a program that reads the matrix directly via `SNSMAT`, you get **bits** (0 = pressed). If you want to get a **character**, use `READ_KEY`/`INPUT`/`INKEY` from the BIOS — they convert the logical code themselves via `NORMTAB` (or `SHIFTAB`/`RUSTAB`/`SHRUSTAB` depending on the mode).

## Additional keys

Ten keys that the CPC did not have.

In row 10:

- **F1/6, F2/7, F3/8, F4/9, F5/10** — MSX-style function keys. Each combines two functions: F1 and F6, F2 and F7, and so on. Which one actually fires depends on whether SHIFT or another modifier is pressed.
- **HELP** — the help key.
- **INS** — insert.
- **b** — an additional key (purpose depends on the program).

In row 9:

- **R/L** — Russian/Latin mode. Bit 6.

There is also the **RES** key — reset. It is not in the matrix but is connected directly to the processor's `/RESET` signal.

And four keys above the numeric keypad whose purpose is unknown. Possibly they are unused or duplicate others.

## JCUKEN layout

The Aleste keyboard is not QWERTY and not AZERTY, but **JCUKEN** — the Russian layout. This means the keys are not arranged the way they are on a familiar keyboard.

For example, the key that on a QWERTY keyboard would be "Q" is "Й" on JCUKEN. The "A" key is "Ф". And so on.

But there is a subtlety here. At the port level the processor sees the CPC matrix, and the BIOS assigns values to the keys depending on the selected mode (Russian/Latin). In Latin mode one layout works, in Russian — another.

Switching between modes — the **R/L** key (row 9, bit 6). The same key is used as Fire3 for the joystick (because the CPC joystick had an undocumented third fire, and it was decided to combine it with R/L).

## Example: read a key press

Suppose we want to find out whether the "1" key is pressed (row 8, bit 0).

```asm
; Configure 8255: port A = input, port C = output
; (if the BIOS has already configured it — can be skipped)
LD BC, #F700      ; 8255 control register
LD A, %00010000   ; mode 0, port A input, port C output
OUT (C), A

; Select row 8
LD BC, #F600      ; port C
LD A, 8
OUT (C), A        ; low 4 bits = 8

; Read port A
LD BC, #F400      ; port A
IN A, (C)

; Check bit 0
BIT 0, A
JR Z, KeyPressed  ; if 0 — key is pressed
```

<!-- FIX: fixed OUT/IN syntax (was OUT (#F7XX),A etc.).
     Fixed control register value: %10000000 -> %00010000.
     Added a comment that 8255 configuration can be skipped if the BIOS has already done it. -->

Note: before reading port A you need to configure the 8255 so that port A is an input. Usually the BIOS has already done this, but if you work with the 8255 yourself — don't forget.

## Example: read all keys

Usually a program has a routine that runs through all rows and collects the keyboard state into a buffer.

```asm
; Buffer of 11 bytes, one per row
ReadKeyboard:
    LD HL, KeyBuffer
    LD B, 11           ; 11 rows
    LD C, 0            ; row number (low byte of BC)
    LD D, #F6          ; high byte of port C
ReadLoop:
    LD A, C
    LD C, D            ; C = #F6, but we need BC = #F6xx
    ; ...
```

<!-- FIX: in the original example C was used both as the row counter
     and as the low byte of BC for OUT (C),A — a conflict. Here the correct
     approach is shown: the row counter is in a separate register (e.g. E),
     and BC is used only for the port. -->

**Correct version:**

```asm
; Buffer of 11 bytes, one per row
ReadKeyboard:
    LD HL, KeyBuffer
    LD E, 0            ; row number (counter)
    LD B, 11           ; total rows
ReadLoop:
    LD A, E
    LD BC, #F600       ; port C
    OUT (C), A         ; select row
    LD BC, #F400       ; port A
    IN A, (C)          ; read
    LD (HL), A         ; save
    INC HL
    INC E
    DJNZ ReadLoop
    RET
```

<!-- FIX: rewrote the example — row counter in E, BC only for the port.
     OUT/IN syntax fixed. -->

After this, `KeyBuffer` holds the state of all keys. A zero in a bit — pressed, a one — not pressed.

## Auto-repeat and delay

In SETUP (the Aleste setup menu) you can set the key auto-repeat parameters:

- **Delay** — the delay before auto-repeat starts.
- **Repeat** — the auto-repeat rate.

These parameters are handled by the BIOS. If you write your own program and want your own auto-repeat — implement it yourself, don't rely on the BIOS.

## RESET key

The **RES** key is connected directly to the processor's `/RESET` signal. This is a hardware reset, not a software one. When pressed, the machine reboots.

You cannot press RESET in software — but you can initiate a reset through other means (for example, through the FDC or through special ports). Usually this is not needed.

## Notes for the programmer

**You work with the CPC matrix.** Not MSX. Forget the MSX layout if you knew it.

**Eleven rows, not ten.** Row 10 is new. Old CPC software does not know it and will not see it.

**R/L is combined with Fire3.** If your program reads the joystick and expects Fire3 — it will get a signal from R/L.

**JCUKEN layout.** The keys are not arranged as on QWERTY. If you write something where physical position matters — keep this in mind.

**The BIOS handles the layout.** If you don't want to deal with the layout yourself — use the BIOS keyboard reading functions. They return an already-prepared character taking the mode into account.

**Rows 9–10 in `NORMTAB` are not physical labels.** If you read the matrix directly via `SNSMAT`, you get bits. If you want a character — use `READ_KEY`/`INPUT`/`INKEY`, they convert the logical code via `NORMTAB`.

## What's next

The keyboard is covered. The next section is [about the disk drive: the 765 FDC controller, ports, reading a sector.](./08-disk.md)
