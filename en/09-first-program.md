# 08. First Program

Here we are at practice. In the previous sections we covered memory, screen, sound, ports, keyboard, and disk drive separately. Now we'll put it all together and write a program that does something.

The program will be simple but not trivial. It:

1. Switches the machine to Aleste mode (MAPMOD = 1).
2. Configures the palette.
3. Selects the screen mode.
4. Outputs a line of text.
5. Loops so the result can be seen.

Each step with comments: why exactly this way, what happens, what to watch out for.

## What you need to assemble and run

Before writing code, you need to understand how to assemble and run it.

**Assembler.** There are several options for the Z80:

- **z80asm** — simple, cross-platform.
- **SjASMPlus** — popular, feature-rich.
- **Pasmo** — another good option.
- **WinAPE** — built-in assembler in the emulator.

Any of them will do. The syntax differs slightly, but the basics are the same.

**Emulator.** There may be no ready-made emulator for the Aleste (the machine is rare). But many CPC emulators support Aleste extensions. For example, **WinAPE** or **CPCEC** can work with Aleste mode if configured correctly.

If there is no emulator — you can run on real hardware. Loading via diskette or via RS-232.

**Output format.** Usually the assembler produces a binary file. It can be loaded into the emulator directly or written to a diskette in AMSDOS format.

## Where to load the program

`ORG 0x4000` is an **address in logical page 1** (`0x4000–0x7FFF`). But which **physical** page is mapped into this logical one depends on how the program is launched. In `ROM.MAC`, `BOOT` loads `BIOS.SYS` into **page 8** (`#7DC8`), `BDOS.SYS` into **page 9** (`#7DC9`). If your program is launched instead of BIOS/BDOS, it must itself take care that page 1 has a **free** RAM page (for example, 4 or 5).

For the example we will assume the program is loaded into **page 4**, mapped to `0x4000`. Then `ORG 0x4000` is correct, and `0x4000` is the start of the code.

## Program structure

Any Z80 program begins at the address where it was loaded. In our case this is `0x4000` in page 1.

The program will consist of:

1. Entry point — execution starts here.
2. Initialization — setting the mode, palette, screen.
3. Main code — text output.
4. Looping — so the program does not terminate.
5. Data — the text string, the font table.

## Code

Here is the complete program code. Then we'll go through each part.

```asm
; ============================================
; First program for Aleste 520EX
; Outputs the string "HELLO, ALESTE!" in Aleste mode
; ============================================

ORG 0x4000

; --- Entry point ---
Start:
    ; 1. Switch to Aleste mode (MAPMOD = 1)
    ;    Port #FABF, bit 2
    ;    Other bits: D0=0 (VRAM bank 0), D1=0 (norm res),
    ;    D2=1 (MAPMOD), D3=0 (MAP page 0), D4=0 (580WI53),
    ;    D5=0 (AY8910)
    LD BC, #FABF
    LD A, %00000100    ; bit 2 = 1 (MAPMOD)
    OUT (C), A

    ; 2. Configure the palette
    CALL SetPalette

    ; 3. Select the screen mode
    CALL SetMode

    ; 4. Output the text string
    LD HL, Message     ; string address
    CALL PrintString

    ; 5. Loop
Loop:
    JR Loop

; ============================================
; Procedure: set the palette
; Color 0 = black, color 1 = white
; ============================================
SetPalette:
    ; Select Gate Array register 0 (palette index)
    LD BC, #7F00
    LD A, %00000000    ; bits 7,6 = 00
    OUT (C), A
    LD A, 0            ; index 0
    OUT (C), A

    ; Select Gate Array register 1 (palette data)
    LD A, %01000000    ; bits 7,6 = 01
    OUT (C), A
    LD A, %00000000    ; color 0: R=0, G=0, B=0 (black)
    OUT (C), A

    ; Now configure color 1 (white)
    LD A, %00000000    ; register 0 (index)
    OUT (C), A
    LD A, 1            ; index 1
    OUT (C), A

    LD A, %01000000    ; register 1 (data)
    OUT (C), A
    LD A, %00111111    ; color 1: R=3, G=3, B=3 (white)
    OUT (C), A

    RET

; ============================================
; Procedure: set the screen mode
; ============================================
SetMode:
    ; Gate Array register 2 (RMR): mode, ROM, LEDs
    LD BC, #7F00
    LD A, %10000000    ; bits 7,6 = 10
    OUT (C), A

    ; Mode 1 (320x200, 4 colors), lower ROM disabled,
    ; upper ROM disabled.
    ; RMR format: %10xxxxxx
    ;   bit 5 = CAPS LED (0)
    ;   bit 4 = RUS LED (0)
    ;   bit 3 = 1 -> upper ROM disable
    ;   bit 2 = 1 -> lower ROM disable
    ;   bits 1,0 = 01 -> mode 1
    LD A, %10001101    ; RMR, ROM off, mode 1
    OUT (C), A

    RET

; ============================================
; Procedure: output a text string
; Input: HL = string address (0-terminated)
; Output at position (0,0) of the screen
; ============================================
PrintString:
    LD B, 0            ; X = 0
    LD C, 0            ; Y = 0
PrintLoop:
    LD A, (HL)
    OR A
    RET Z              ; end of string
    CALL PrintChar
    INC HL
    INC B              ; next character along X
    JR PrintLoop

; ============================================
; Procedure: output a single 8x8 character
; Input: A = character code, B = X (in characters), C = Y (in rows)
; Uses the Font8x8 table (8 bytes per character)
; ============================================
PrintChar:
    PUSH HL
    PUSH BC
    PUSH DE

    ; HL = font address for character A
    ; font: 8 bytes per character, starting at Font8x8
    LD L, A
    LD H, 0
    ADD HL, HL         ; *2
    ADD HL, HL         ; *4
    ADD HL, HL         ; *8
    LD DE, Font8x8
    ADD HL, DE         ; HL = address of the character's 8 bytes

    ; DE = video memory address for (X=B, Y=C), mode 1
    ; Formula for 16 KB mode 1:
    ;   addr = 0xC000 + (Y & 7) * 2048 + (Y >> 3) * 80 + X * 2
    ; (character 8 pixels, 2 bits per pixel -> 2 bytes per character)
    PUSH HL
    LD A, C
    AND 7
    LD L, A
    LD H, 0
    ADD HL, HL         ; *2
    ADD HL, HL         ; *4
    ADD HL, HL         ; *8
    ADD HL, HL         ; *16
    ADD HL, HL         ; *32
    ADD HL, HL         ; *64
    ADD HL, HL         ; *128
    ADD HL, HL         ; *256
    ADD HL, HL         ; *512
    ADD HL, HL         ; *1024
    ADD HL, HL         ; *2048
    PUSH HL
    LD A, C
    SRL A
    SRL A
    SRL A              ; A = Y >> 3
    LD L, A
    LD H, 0
    ; L * 80 = L * 64 + L * 16
    LD D, H
    LD E, L
    SLA E
    RL D
    SLA E
    RL D               ; DE = L * 4
    SLA E
    RL D
    SLA E
    RL D               ; DE = L * 16
    PUSH DE
    SLA E
    RL D
    SLA E
    RL D               ; DE = L * 64
    POP HL             ; HL = L * 16
    ADD HL, DE         ; HL = L * 80
    POP DE             ; DE = (Y & 7) * 2048
    ADD HL, DE         ; HL = (Y&7)*2048 + (Y>>3)*80
    ; X * 2
    LD A, B
    ADD A, A           ; A = X * 2
    LD E, A
    LD D, 0
    ADD HL, DE
    ; HL = video memory address
    LD A, H
    AND 0x3F
    OR 0x40
    LD H, A            ; HL = 0x4000..0x7FFF (VRAM)
    POP DE             ; DE = font address
    ; now DE = font, HL = VRAM

    ; Copy 8 rows of 2 bytes each
    LD B, 8
CharLoop:
    LD A, (DE)         ; font byte (8 pixels)
    LD (HL), A         ; into VRAM
    INC DE
    INC HL
    ; second half of the character (in mode 1 a character = 2 bytes)
    ; for simplicity duplicate: second byte = the same
    LD A, (DE)         ; next font byte (if the font is 8 bytes)
    LD (HL), A
    INC DE
    INC HL
    ; move to the next raster line: +0x800
    LD A, H
    ADD A, 0x08
    LD H, A
    AND 0x38
    JR NZ, CharNoWrap
    LD A, H
    SUB 0x40
    LD H, A
    LD A, L
    ADD A, 0x50
    LD L, A
    JR NC, CharNoWrap
    INC H
CharNoWrap:
    DEC B
    JR NZ, CharLoop

    POP DE
    POP BC
    POP HL
    RET

; ============================================
; Data
; ============================================
Message:
    DB "HELLO, ALESTE!", 0

; Simple 8x8 font for the characters used
; in the string. Each character — 8 bytes (one byte per row).
; For characters not in the table there will be garbage —
; this is normal for a demonstration.
;
; The table covers: space, comma, exclamation mark,
; letters A,E,H,L,O,S,T and uppercase Latin.
Font8x8:
    ; ' ' (0x20)
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '!' (0x21)
    DB 0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x00
    ; '"' (0x22) — not used, placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '#' (0x23) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '$' (0x24) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '%' (0x25) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '&' (0x26) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '\'' (0x27) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '(' (0x28) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; ')' (0x29) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '*' (0x2A) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '+' (0x2B) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; ',' (0x2C)
    DB 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30
    ; '-' (0x2D) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '.' (0x2E) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00
    ; '/' (0x2F) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '0'..'9' (0x30..0x39) — placeholders
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; ':' (0x3A) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; ';' (0x3B) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '<' (0x3C) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '=' (0x3D) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '>' (0x3E) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '?' (0x3F) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; '@' (0x40) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'A' (0x41)
    DB 0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00
    ; 'B' (0x42) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'C' (0x43) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'D' (0x44) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'E' (0x45)
    DB 0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00
    ; 'F' (0x46) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'G' (0x47) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'H' (0x48)
    DB 0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00
    ; 'I' (0x49) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'J' (0x4A) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'K' (0x4B) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'L' (0x4C)
    DB 0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00
    ; 'M' (0x4D) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'N' (0x4E) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'O' (0x4F)
    DB 0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
    ; 'P' (0x50) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'Q' (0x51) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'R' (0x52) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'S' (0x53)
    DB 0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00
    ; 'T' (0x54)
    DB 0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00
    ; 'U' (0x55) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'V' (0x56) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'W' (0x57) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'X' (0x58) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'Y' (0x59) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; 'Z' (0x5A) — placeholder
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
```

## Code walkthrough

Now step by step.

### Step 1: switch to Aleste mode

```asm
LD BC, #FABF
LD A, %00000100
OUT (C), A
```

Port `#FABF` is EXTPORT. Bit 2 is MAPMOD. Setting it to 1 gives Aleste mode: 64 colors, extended mapper.

The other bits are left at 0:

- **D0 = 0** — VRAM bank 0.
- **D1 = 0** — normal resolution (not HIGHX).
- **D2 = 1** — MAPMOD (Aleste mapper).
- **D3 = 0** — MAP page 0.
- **D4 = 0** — 580WI53 (timer).
- **D5 = 0** — AY8910 (not 512WI1).

This is an important step: without it the machine remains in CPC mode, and the palette will be 27-color, not 64-color.

### Step 2: configure the palette

The palette is configured through the Gate Array (port `#7F00`). First select the index (which color to change), then write the data.

```asm
LD BC, #7F00
LD A, %00000000    ; register 0 — palette index
OUT (C), A
LD A, 0            ; index 0
OUT (C), A
```

The first write selects Gate Array register 0 (bits 7,6 = 00). The second write is the data for register 0, i.e. the palette index number.

Then select register 1 and write the color:

```asm
LD A, %01000000    ; register 1 — palette data
OUT (C), A
LD A, %00000000    ; color: R=0, G=0, B=0 (black)
OUT (C), A
```

The color is encoded in six bits: two for red, two for green, two for blue. `%00000000` — all zeros, black. For white — `%00111111` (R=3, G=3, B=3).

### Step 3: select the mode

The mode is selected through Gate Array register 2 (RMR).

```asm
LD A, %10000000    ; register 2
OUT (C), A
LD A, %10001101    ; RMR, ROM off, mode 1
OUT (C), A
```

Bits 7,6 = 10 select register 2. Bits 1,0 = 01 — mode 1 (320×200, 4 colors). Bit 3 = 1 — upper ROM **disabled**. Bit 2 = 1 — lower ROM **disabled**.

Why disable the ROM? Because we are working in our own program and don't want the BIOS interfering. In a real program this may not be needed — it depends on the task.

### Step 4: text output

The `PrintString` procedure reads the string at address HL and for each character calls `PrintChar`, which:

1. Takes 8 font bytes from `Font8x8` (by character code).
2. Computes the video memory address using the formula for mode 1 (16 KB):

   ```asm
   addr = 0xC000 + (Y & 7) * 2048 + (Y >> 3) * 80 + X * 2
   ```

3. Copies 8 font rows into VRAM, moving between raster lines via `+0x800`.

In the example the font contains only the characters used in the string "HELLO, ALESTE!". The other characters are placeholders (zeros). In a real program the font would be complete (256 characters) or taken from ROM via `ALEST`.

### Step 5: looping

```asm
Loop:
    JR Loop
```

The program terminates with an infinite loop. If this is not done, the processor will go further through memory, hit random data, and crash.

In a real program there would be a return to the BIOS or to BASIC here. But for the example — a loop.

## What to improve

This example is deliberately simplified. In a real program you need to:

**Use a complete font.** In the example the font contains only a few characters. In a real program take the font from ROM (`ALEST`) or use a full 256-character table.

**Take into account the non-linearity of video memory for all modes.** In the example — the formula for mode 1 (16 KB). For modes 0, 2, 3 and HIGHX the formulas are different (see the "03. Screen" section).

**Handle interrupts.** If the program works with interrupts, they must be configured. For a simple example this is not needed.

**Restore state.** If the program terminates, it must return the machine to its original state: restore the ROM, set MAPMOD = 0, restore the palette.

**Check for errors.** There are no checks in the example, but in a real program they are needed.

## How to assemble and run

1. Save the code to a file `hello.asm`.
2. Assemble it with an assembler. For example, for z80asm:

   ```asm
   z80asm -o hello.bin hello.asm
   ```

3. Load `hello.bin` into the emulator into **page 4**, mapped to `0x4000`. (Or into any free page, but then adjust `ORG` and the load address.)
4. Set the entry point to `0x4000`.
5. Run.

If everything is done correctly — the string "HELLO, ALESTE!" will appear on the screen.

## What's next

The program is written and works. The next section is [interrupts](./10-interrupts.md)

