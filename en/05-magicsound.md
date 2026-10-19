# 05. Magic Sound Board

The Magic Sound Board is an expansion board for the Aleste 520EX, developed by the same company, Patisonic. It provides what the base machine lacks: four-channel digital sound with DMA.

It's a rare thing. The board was produced in limited quantities, and finding one now is difficult. But if you have one — this section explains how to work with it.

If you don't have the board — you can skip this section. The base Aleste handles sound through the AY-3-8910, and that is enough for most tasks.

## What the Magic Sound can do

The board is a four-channel digital audio player. Not a synthesizer, but specifically a sampler: it plays back ready-made digital recordings.

Specifications:

- **4 channels** of independent playback.
- **8 bits per sample** — the standard depth for that era.
- **7 bits of volume** per channel (D0–D6). The working range is **1..63**; the values **0 and 1 are special** (treated as `40H` = 64, "maximum/special value," see below).
- **16-bit frequency timer** per channel — the playback rate can be set with high precision.
- **Two 8254 chips** (programmable timers), not one: channels A/B/C are served by the first, channels D/E by the second (see the "Ports" section).

The board works via DMA: it reads data directly from Aleste memory, without loading the CPU. The CPU only configures the channels and starts playback.

This is precisely why the board requires the Aleste's extended expansion port with additional DMA pins. It will not work on a regular CPC.

## Why this is needed

The main application is playing music in the **STM** (Scream Tracker) format. This is a tracker music format popular in the MSX world and on PC.

STM files contain samples (recorded sounds) and a score: which channel, when, what plays. The Magic Sound reads this data and plays it back.

Besides music, the board is suitable for:

- High-quality sound effects (gunshots, explosions, voice).
- Speech playback.
- Any task where you need to play a recorded sound rather than generate it.

The AY-3-8910 cannot do this: it generates simple waves. The Magic Sound plays what is recorded.

## Ports

The board uses several I/O ports. The addresses are chosen so as not to conflict with the Aleste's base devices.

| Port    | What                  | Chip                            | register select                     | Data bits         | RW |
|---------|-----------------------|---------------------------------|-------------------------------------|-------------------|----|
| `#FXDX` | Board select          |                                 |                                     |                   | —  |
| `#F8DX` | DMA controller        | [8237](../datasheets/M8257.PDF) | A[3..0]                             |                   | RW |
| `#F9DX` | Timers                | [8254](../datasheets/8254.PDF)  | A[2] timer number, A[1..0] register |                   | W  |
| `#FADX` | Volume control        |                                 | A[1..0] channel                     | D[6..0] volume    | W  |
| `#FBDX` | Mapper                |                                 | A[1..0] channel, A[3..2] channel byte | D[4..0] page    | W  |

Let's go through each.

### `#FXDX` — board select

This port activates the board. Until a certain value is written to it, the board does not respond to accesses. This is done so as not to interfere with other devices.

The exact value that must be written depends on the board implementation. In the original documentation it is not fully specified.

> **From the code:** in the `.Z80` source there is **not a single write to `#FXDX`**. Initialization (`INI_PRT`) touches only `#F9Dx`, `#F8Dx`, `#FA`/`#FB` through macros. That is, either in this firmware version board select is not needed, or it is done at the hardware/extended port level. **Do not rely on `#FXDX` as a mandatory step** — it is not used in the code given.

### `#F8DX` — 8237 DMA controller

This is the 8237 chip — the standard DMA controller known from the PC. It manages direct memory access: it reads data from Aleste RAM and passes it to the sound path without CPU involvement.

The low 4 bits of the address (`X` in `#F8DX`) select the controller register. Data goes through the low 8 bits.

The 8237 is a complex chip. The full description is in the datasheet. The main registers, **as they are wired in the code**:

| Address | Purpose                           |
| ------- | --------------------------------- |
| `#F8D0` | channel A address (2 bytes, LSB/MSB) |
| `#F8D1` | channel A length (2 bytes, LSB/MSB)  |
| `#F8D2` | channel B address                 |
| `#F8D3` | channel B length                  |
| `#F8D4` | channel C address                 |
| `#F8D5` | channel C length                  |
| `#F8D6` | channel D address                 |
| `#F8D7` | channel D length                  |
| `#F8D8` | command / status (DMACOM)         |
| `#F8DA` | channel mask (DMAMASK)            |
| `#F8DB` | mode (DMAMOD)                     |
| `#F8DD` | reset (DMARES)                    |

**Modes (`DMAMOD`) used in the code:** `48H`, `49H`, `4AH`, `4BH` for channels A/B/C/D respectively. 8237 byte layout: `01 0 0 10 cc` — single mode, address increment, no autoinit, transfer type "read" (memory → device), channel number `cc` (00=A, 01=B, 10=C, 11=D).

**Modes when reprogramming via NMI (`MA_NMI`):** `58H`, `59H`, `5AH`, `5BH` for A/B/C/D respectively. They differ from `48H..4BH` by **bit 4 = 1 (autoinit enable)** — so that the 8237 automatically restarts after a chain.

**Mask (`DMAMASK`):** in `INI_PRT` the values `05H, 04H, 07H, 06H` are written in sequence. This is the **prohibition of channels B, A, D, C** (in that order):

- `05H` = set mask, channel 1 (B);
- `04H` = set mask, channel 0 (A);
- `07H` = set mask, channel 3 (D);
- `06H` = set mask, channel 2 (C).

The order doesn't matter (all four are prohibited anyway), but **the comment "prohibit channels 0,1,2,3" would be incorrect** — the actual order is B, A, D, C.

Before starting a channel, the channel number (`DST` = 0,1,2,3) is written to it, which **clears** the mask.

**Command (`DMACOM`):** initialized to zero.

**Reset (`DMARES`):** write 0 during initialization.

The programmer configures the 8237 so that it reads sample data from memory and sends it to the DAC.

**Length limitation:** the size of a continuous sample is 64 KB (16-bit counter). For longer samples, reprogramming via NMI is required (see below).

### `#F9DX` — 8254 timers

> **Important:** the source uses **two 8254 chips**, not one.

Port layout from the code:

| Port    | Purpose                                      |
| ------- | -------------------------------------------- |
| `#F9D8` | channel 0 (A) of the first 8254              |
| `#F9D9` | channel 1 (B) of the first 8254              |
| `#F9DA` | channel 2 (C) of the first 8254              |
| `#F9DB` | control register of the first 8254 (`TIMUP0`) |
| `#F9D4` | channel 0 (D) of the second 8254             |
| `#F9D5` | channel 1 (E) of the second 8254             |
| `#F9D7` | control register of the second 8254 (`TIMUP1`) |

**Address formula:** `A[2]` — 8254 number (0 = first, 1 = second), `A[1..0]` — register (00 = channel 0, 01 = channel 1, 10 = channel 2, 11 = control). Hence:

- `#F9D8` = `1000` → A[2]=0, A[1..0]=00 → channel 0 of the first;
- `#F9D4` = `0100` → A[2]=1, A[1..0]=00 → channel 0 of the second;
- `#F9DB` = `1011` → A[2]=0, A[1..0]=11 → control of the first;
- `#F9D7` = `0111` → A[2]=1, A[1..0]=11 → control of the second.

That is, sound channels A/B/C are clocked by the first 8254, channel D by channel 0 of the second 8254, and channel E (`#F9D5`) by channel 1 of the second. Channel E is initialized in the code with the value `4` and, apparently, serves the DAC/a service function.

**Initialization (`INI_PRT`):**

- first 8254: `34H`, `74H`, `B4H` — channels 0,1,2, **mode 2** (rate generator), LSB then MSB;
- second 8254: `34H`, `76H` — channels 0,1. Note that `34H` is **mode 2**, while `76H` is **mode 3** (square wave), not mode 2.
- channel E: value `4`.

**Important:** after reset the timers do not work until initial values are written into them. The 8254 must be initialized before use.

Each timer channel sets the playback rate for the corresponding sound channel. The higher the rate, the higher the sound quality (and the more data per second).

**Frequency formula (from the code `RET_DIV`/`IDIV_1`):** the channel frequency is obtained by dividing the sample frequency by the note divisor. The divisors are fixed by the `ST_DIV` table (12 values per octave):

```
766H, 6FCH, 697H, 639H, 5DFH, 58BH,
53BH, 4F0H, 4A9H, 466H, 427H, 3EBH
```

The high nibble of the note sets the shift (octave), the low nibble — the index in the table. This specific detail was not in the previous documentation.

**Clarification:** `RET_DIV` reads **not** `ST_DIV` directly, but `I_DIV` — a table obtained by multiplying `ST_DIV` by the instrument coefficient (`IDIV_1`/`MUL`). `ST_DIV` are the "standard" divisors, while `I_DIV` are the divisors "adjusted" to the frequency of a specific instrument.

### `#FADX` — volume control

This port sets the volume of each of the four channels.

- The low 2 bits of the address (`X` in `#FADX`) — channel number (0–3).
- Data bits **D0–D6** (7 bits) — volume.

> **Clarification from the code:** the port accepts **7 bits** (D0–D6), not 6. The working range is **1..63**; the values **0 and 1 are treated as `40H` (64)** — "maximum/special value," not silence. In `MA_START`:
>
> ```
> LD A,(SNG_VOL+SEG)
> SUB 1
> JR Z,MA_5      ; SNG_VOL = 1 -> 40H
> JR NC,MA_4     ; SNG_VOL >= 2 -> as is
> MA_5: LD A,40H ; SNG_VOL = 0 -> 40H
> MA_4: OUT (PVOL),A
> ```
>
> That is:
>
> - `SNG_VOL = 0` → `40H` (64);
> - `SNG_VOL = 1` → `40H` (64);
> - `SNG_VOL >= 2` → `SNG_VOL` (as is).
>
> For comparison with the peak indicator (`PIK_VOL`), `AND 3FH` is used, i.e. the low 6 bits are the volume, and bit 6 is a special flag.
>
> In practice: **use 2..63 for normal volume; 0 and 1 will give "maximum"**.

Volume 2 — quiet, 63 — loud, 0/1 — "maximum" (special value).

### `#FBDX` — mapper

This port controls which memory bank the data for each channel is read from.

- The low 2 bits of the address (`A[1..0]`) — channel number (0–3).
- Bits `A[3..2]` — byte number within the channel (0–3).
- The low 5 bits of data (`D[4..0]`) — memory page number (in inverted form).

Base addresses for the channels:

- channel A: `#FBD0..#FBD3`;
- channel B: `#FBD4..#FBD7`;
- channel C: `#FBD8..#FBDB`;
- channel D: `#FBDC..#FBDF`.

> **Clarification from the code:** the write to the mapper goes **4 bytes per channel** (and not "4 bytes for all channels"), and moreover **inverted** (`CPL`) and **decrementing by 1**:
>
> ```
> LD A,(S_MAP)
> CPL
> OUT (#FBD0),A   ; byte 0 of channel A
> DEC A
> OUT (#FBD1),A   ; byte 1 of channel A
> DEC A
> OUT (#FBD2),A   ; byte 2 of channel A
> DEC A
> OUT (#FBD3),A   ; byte 3 of channel A
> ```
>
> That is, the mapper sets **4 consecutive pages per channel**, starting from the inverted base. For channel B — the same, but in `#FBD4..#FBD7`; for C — in `#FBD8..#FBDB`; for D — in `#FBDC..#FBDF`.

Note: the page number is **inverted**. That is, if you want to specify page 5, you must write not 5 but the inverse value. This is a board feature, and it is easy to forget.

After reset the timers do not work until the first write to the mapper is made. This is a kind of "launch" of the board.

## NMI on DMA completion

When the 8237 DMA controller finishes a transfer (the TC — Terminal Count — signal), it generates an **NMI** — a non-maskable interrupt.

This means that after a sample finishes playing, the processor receives an interrupt. The program can react to this: start the next sample, update state, stop the channel.

> **Mechanics from the code:** in the `NMI` handler, register `#F8D8` (`DMACOM`, also the status) is read into `E`. Then the `MA_NMI` macro is called **four times** (for channels A, B, C, D), and each time `RRC E` is done — this checks **bits 0, 1, 2, 3** of the status (TC of channels A, B, C, D respectively). If the corresponding bit is not set — exit the macro. If it is set and the channel has the `F_RESTART` flag — the address and length are rewritten from `NMI_START`/`NMI_LENGHT`, `F_RESTART` is cleared, the mode is set (`58H..5BH`, autoinit) and the mask is cleared. This is how a **chain of samples** is implemented (continuing playback beyond 64 KB).

NMI is not an ordinary interrupt. It cannot be masked, and it has priority over all others. The NMI handler must be short and careful.

## How this is programmed

The general scheme for working with the Magic Sound is as follows.

1. **Initialization.** Configure the board's ports, enable it (if `#FXDX` is required — see the caveat above), and initialize both 8254s.
2. **Data preparation.** Load the samples into Aleste memory. Usually they lie in separate banks.
3. **Channel configuration.** For each channel set:
   - the sample address in memory (in the 8237 registers),
   - the sample length,
   - the playback rate (via the 8254),
   - the volume (via `#FADX`),
   - the memory pages (via `#FBDX`, 4 bytes per channel).
4. **Start DMA.** Configure the 8237 to read from memory and write to the DAC. Issue the start command (clear the mask).
5. **Handle NMI.** When the sample ends, an NMI arrives. In the handler — start the next one or stop.

The exact sequences of port writes are in the datasheets for the 8237 and 8254. These are standard chips, and there is plenty of documentation on them.

## Difficulties

The Magic Sound is not a device for beginners. Here is why.

**The 8237 is a complex chip.** Programming DMA requires understanding registers, modes, priorities, and address alignment. An error in one bit — and the transfer won't happen or will go to the wrong place. The size of a continuous sample is 64 KB; for longer samples reprogramming via NMI is required.

**NMI is a dangerous interrupt.** The NMI handler must be very short and must not use resources that may be busy. If an NMI occurs during disk access or a critical section — there can be problems.

**Inverted page number.** It is easy to forget that the page number in `#FBDX` is inverted, and moreover is written **4 bytes per channel** (not one). As a result the channel reads from the wrong place.

**Timers do not work after reset.** Both 8254s must be initialized, otherwise nothing will sound.

**Two 8254 chips.** Channels A/B/C and D/E are served by different chips with different bases (`#F9D8` vs `#F9D4`) and different control registers (`#F9DB` vs `#F9D7`). Don't mix them up.

**`76H` is mode 3, not mode 2.** Channel E is clocked by a square wave, not a rate generator. This matters for frequency calculation.

## What to do if you don't have the board

If you don't have a Magic Sound — don't worry. The AY-3-8910 gives three synthesis channels, and for most tasks that is enough. Music, sound effects, simple melodies — all of this is done on the AY.

The Magic Sound is a step forward in quality, but not a mandatory condition for programming on the Aleste.

If you want to experiment with digital sound without the board — you can try a software mixer on the AY. It is slower and the quality is worse, but it works on any machine.

## STM format (from the loader code)

- File extension — `.STM` (forced in the FCB in the code: `S`,`T`,`M`).
- Checks on load: byte `DATA+1EH == 2` (version) and `DATA+1DH == 2` (number of patterns); on mismatch — error.
- `DATA+32` (`20H`) — tempo (used for `TEMP_CONT`/`TEMP_PE`).
- `DATA+33` (`21H`) — number of instruments (used to compute the number of blocks to load).
- `DATA+34` (`22H`) — master volume (`VOL_1234`).
- Instruments: 32 bytes per entry (`INST`), **31 instruments** processed (`B=31` in `INI_DIV`).
- Pattern: **64 rows** (`CP 40H` in `NEXT_NOT`), 4 channels, offset **4 bytes per channel** within a row.
- Loading goes in blocks of 32 records (`BDOS 27H`), buffer address — `DATA` (`#2000`).

Вот готовый параграф на русском и английском — с исправленной опечаткой и нормальной пунктуацией.

## Magic Sound Player Source Code

For experiments with the board, studying how it works, or integrating the player into your own project, you can use the working source code of a music player for this board. It is built with a modern assembler and can be launched in an emulator or on real hardware straight from the command line.

[Magic Sound Player Source Code](https://github.com/hww/magic-sound-player)


## What's next

The Magic Sound is covered. The next section is [the port reference: the full table and warnings about conflicts.](./06-ports.md)

---

## Appendix A. Short examples (from the source)

### A.1. Port initialization (`INI_PRT`)

```asm
; Timers: two 8254
LD BC,#F9DB        ; control of 8254 #1
LD A,#34
OUT (C),A          ; channel 0 (A), mode 2, LSB/MSB
LD A,#74
OUT (C),A          ; channel 1 (B), mode 2
LD A,#B4
OUT (C),A          ; channel 2 (C), mode 2
LD BC,#F9D7        ; control of 8254 #2
LD A,#34
OUT (C),A          ; channel 0 (D), mode 2
LD A,#76
OUT (C),A          ; channel 1 (E), mode 3 (square wave)
LD BC,#F9D5        ; channel E
LD A,4
OUT (C),A
SUB A
OUT (C),A

; DMA 8237: reset, command, mask
LD BC,#F8DD
OUT (C),A          ; reset
LD BC,#F8D8
OUT (C),A          ; command = 0
LD BC,#F8DA
LD HL,#0405
OUT (C),L          ; mask 5 (channel B)
OUT (C),H          ; mask 4 (channel A)
LD HL,#0607
OUT (C),L          ; mask 7 (channel D)
OUT (C),H          ; mask 6 (channel C)
```

### A.2. Starting channel A (`MA_START`, simplified)

```asm
; sample address and length
LD BC,#F8D0
LD HL,(START_0+SEG_A)
OUT (C),L
OUT (C),H
INC C
LD HL,(LENGHT_0+SEG_A)
OUT (C),L
OUT (C),H

; frequency (timer A)
LD BC,#F9D8
LD HL,(SNG_DIV+SEG_A)
OUT (C),L
OUT (C),H

; volume (0/1 -> 40H, otherwise as is)
LD A,(SNG_VOL+SEG_A)
SUB 1
JR Z,vol_max
JR NC,vol_ok
vol_max:
LD A,#40
vol_ok:
LD BC,#FAD0
OUT (C),A

; mapper: 4 inverted decrementing pages per channel A
LD A,(S_MAP+SEG_A)
CPL
LD BC,#FBD0
OUT (C),A
INC C
DEC A
OUT (C),A
INC C
DEC A
OUT (C),A
INC C
DEC A
OUT (C),A

; mode and mask clearing
LD BC,#F8DB
LD A,#48
OUT (C),A
LD BC,#F8DA
LD A,0
OUT (C),A          ; channel 0 enabled
```

### A.3. NMI handler (`NMI`)

```asm
NMI:
  PUSH HL
  PUSH DE
  PUSH BC
  PUSH AF
  LD BC,#F8D8
  IN E,(C)         ; DMA status
  ; four MA_NMI calls — one per channel
  MA_NMI SEG_A,DMA_A,58H,0
  MA_NMI SEG_B,DMA_B,59H,1
  MA_NMI SEG_C,DMA_C,5AH,2
  MA_NMI SEG_D,DMA_D,5BH,3
  POP AF
  POP BC
  POP DE
  POP HL
  RETN
```

Inside `MA_NMI` (macro):

```asm
  RRC E            ; carry = next status bit (TC of the channel)
  JR NC,MA_QUIT
  LD A,(F_RESTART+SEG1)
  OR A
  JR Z,MA_QUIT
  LD HL,(NMI_START+SEG1)
  LD BC,DMA1
  OUT (C),L
  OUT (C),H
  INC C
  LD HL,(NMI_LENGHT+SEG1)
  OUT (C),L
  OUT (C),H
  SUB A
  LD (F_RESTART+SEG1),A
  LD BC,DMAMOD
  LD A,DMOD1       ; 58H..5BH (autoinit)
  OUT (C),A
  LD BC,DMAMASK
  LD A,DST1        ; 0..3
  OUT (C),A
MA_QUIT:
```

### A.4. Note divisor calculation (`RET_DIV`)

```asm
; A = note (low nibble — index, high — octave)
; IX = channel; result HL = divisor
RET_DIV:
  PUSH AF
  AND #0F
  LD L,A
  LD H,0
  ADD HL,HL          ; *2
  LD E,(IX+SEK_SAMP)
  LD D,(IX+SEK_SAMP+1)
  ADD HL,DE          ; + instrument address
  LD DE,490H-30H
  ADD HL,DE
  LD E,(HL)
  INC HL
  LD D,(HL)
  EX DE,HL           ; HL = divisor from I_DIV
  POP AF
  SRL A
  SRL A
  SRL A
  SRL A              ; A = octave
  AND 7
  RET Z
  LD B,A
RED_0:
  SRL H
  RR L
  DJNZ RED_0
  RET
```

---

