# 07. Disk Drive

The disk drive in the Aleste is a 765 FDC controller, the same one that was in the Amstrad CPC 6128 and a bunch of other machines (PC, MSX, and so on). The chip is standard, its documentation is publicly available, and it is well studied.

This section covers the essentials: what the controller is, what the ports are, how to read a sector. A full description of all 765 FDC commands is a separate large topic and will not be covered here.

## What the controller is

The **NEC µPD765** (or its equivalent) — a floppy disk controller. It can read and write sectors, format tracks, seek a track, and position the head.

In the Aleste it is connected to a 3.5" drive, 80 tracks, 720 KB. Up to two drives are possible.

The controller has two modes of operation: **execution mode** and **result mode**. Commands are sent in execution mode, results are read in result mode. Switching between modes is automatic, based on the controller's state.

## Ports

| Port    | What             | RW |
|---------|------------------|----|
| `#FA7E` | Drive motor      | W  |
| `#FB7E` | Status (Main Status Register) | R  |
| `#FB7F` | Data (Data Register)          | RW |

<!-- FIX: clarified that #FB7E is read-only (Main Status Register),
     while data/commands/parameters/results go through #FB7F. -->

**`#FA7E`** — motor control. Bit 0: 0 — motor off, 1 — on.

**`#FB7E`** — Main Status Register (read-only). Shows the controller's state: whether it is ready for exchange, the direction of exchange, the mode, busy state, and drive busy state.

**`#FB7F`** — Data Register. All information goes through it: commands, parameters, results, sector data.

## How it works

The general scheme is as follows.

1. Turn on the motor (`#FA7E`).
2. Wait until the controller is ready (RQM=1, DIO in the required state — see below).
3. Send a command through `#FB7F`.
4. Send the command parameters (also through `#FB7F`).
5. The controller executes the command.
6. Read the result (through `#FB7F`).
7. Read or write the sector data (if the command was read/write).

Every step requires checking the status — the controller is not instantaneous, and if you write to it when it is not ready, the data will be lost.

## Status register (Main Status Register)

Register `#FB7E` returns a byte with **fixed** bit meanings (this is the 765 FDC Main Status Register; its bits do not change meaning depending on the mode):

| Bit | What                                                          |
|-----|---------------------------------------------------------------|
| 7   | RQM — Request for Master (ready for exchange)                 |
| 6   | DIO — Data Input/Output: 0 — from processor, 1 — to processor |
| 5   | NDMA — Non-DMA mode: 1 — execution mode, 0 — result mode      |
| 4   | CB — Controller Busy (controller is busy)                     |
| 3–0 | D0B–D3B — Drive Busy (busy state of drives 0–3)               |

<!-- FIX: corrected. It said "bits mean different things depending on the mode" —
     incorrect, the Main Status Register has fixed bits.
     It said "bits 3–0 — error code" — incorrect, these are Drive Busy.
     The error code is read from the Result Register (ST0–ST3), not from the status. -->

**RQM (bit 7)** — the most important. While it is 0, the controller is busy and not ready for exchange. You must wait until it becomes 1.

**DIO (bit 6)** — direction. If 0 — the controller is waiting for data from the processor (you can write to `#FB7F`). If 1 — the controller is giving data (you can read from `#FB7F`).

**NDMA (bit 5)** — mode. 1 — execution mode (commands), 0 — result mode (results).

**CB (bit 4)** — the controller is busy executing a command.

**D0B–D3B (bits 3–0)** — busy state of drives 0–3 (1 = drive busy). Not an error code.

## Example: wait for readiness

Before any exchange you need to wait until the controller is ready. Here is a simple routine.

```asm
; Wait until the controller is ready for exchange (RQM=1)
WaitFDC:
    LD BC, #FB7E
    IN A, (C)          ; read the Main Status Register
    BIT 7, A           ; check RQM
    JR Z, WaitFDC      ; if 0 — keep waiting
    RET
```

<!-- FIX: fixed IN syntax (was IN A,(#FB7E) — does not assemble). -->

After this you can write to or read from `#FB7F`. **But** for a correct exchange you also need to check DIO: if you are going to write — DIO must be 0; if read — DIO must be 1. `WaitFDC` checks only RQM; for a full check add `BIT 6,A` and compare with the expected direction.

<!-- FIX: added a clarification about DIO — RQM alone is not enough. -->

## Example: read a sector

Suppose we want to read a sector from the disk. This is the READ DATA command.

READ DATA command parameters (8 bytes after the command code):

- **HD/US** — head (bit 2) and drive number (bits 1–0).
- **C** — cylinder (track) number.
- **H** — head number (0/1).
- **R** — sector number (1..9 for 720 KB).
- **N** — sector size (2 = 512 bytes; size = 128 × 2^N).
- **EOT** — last sector number (for a single sector = R).
- **GPL** — gap length (usually `0x2A` for 3.5").
- **DTL** — data length (usually `0xFF` if reading to the end of the sector).

<!-- FIX: clarified that the first parameter is HD/US (head + drive number),
     not "drive and head." Also added the sector size formula. -->

A full example is a lot of code. Here is a skeleton.

```asm
; Assume the parameters are already prepared
; in variables: drive, track, head, sector

    ; Turn on the motor
    LD BC, #FA7E
    LD A, 1
    OUT (C), A

    ; Wait for readiness
    CALL WaitFDC

    ; Send the READ DATA command
    ; Command code: 0x06 (read data, MFM, single-sector)
    ;               0x66 (read data, MFM, multi-sector)
    ; ROM.MAC uses 0x66 (multi-sector).
    LD BC, #FB7F
    LD A, 0x06
    OUT (C), A
    CALL WaitFDC

    ; Send the parameters
    LD A, (drive)      ; HD/US: bits 1-0 = unit, bit 2 = head
    OUT (C), A
    CALL WaitFDC

    LD A, (track)      ; C — cylinder
    OUT (C), A
    CALL WaitFDC

    LD A, (head)       ; H — head
    OUT (C), A
    CALL WaitFDC

    LD A, (sector)     ; R — sector
    OUT (C), A
    CALL WaitFDC

    LD A, 2            ; N — sector size (512 bytes)
    OUT (C), A
    CALL WaitFDC

    LD A, (sector)     ; EOT — last sector (reading one)
    OUT (C), A
    CALL WaitFDC

    LD A, 0x2A         ; GPL — gap length (usually 0x2A for 3.5")
    OUT (C), A
    CALL WaitFDC

    LD A, 0xFF         ; DTL — data length
    OUT (C), A
    CALL WaitFDC

    ; Now read the result (7 bytes: ST0, ST1, ST2, C, H, R, N)
    LD B, 7
    LD HL, ResultBuf
ReadResult:
    CALL WaitFDC
    LD BC, #FB7F
    IN A, (C)
    LD (HL), A
    INC HL
    DJNZ ReadResult

    ; Check the status: ST0 bits 7-6 = IC (00 = normal, 01 = abnormal)
    LD A, (ResultBuf)  ; ST0
    AND 0xC0           ; bits 7,6 — IC
    JR NZ, ReadError

    ; Read the sector data (512 bytes)
    LD B, 0            ; 256 bytes at a time, then another 256
    LD HL, SectorBuf
ReadData1:
    CALL WaitFDC
    LD BC, #FB7F
    IN A, (C)
    LD (HL), A
    INC HL
    DJNZ ReadData1

    LD B, 0
ReadData2:
    CALL WaitFDC
    LD BC, #FB7F
    IN A, (C)
    LD (HL), A
    INC HL
    DJNZ ReadData2

    ; Turn off the motor
    LD BC, #FA7E
    XOR A
    OUT (C), A
    RET
```

<!-- FIX: fixed IN/OUT syntax (was OUT (#FA7E),A etc.).
     Clarified the command code: 0x06 — single-sector, 0x66 — multi-sector
     (ROM.MAC uses 0x66).
     Clarified that the result is 7 bytes (ST0, ST1, ST2, C, H, R, N).
     Clarified that ST0 bits 7-6 = IC (00 = normal, 01 = abnormal),
     not "bits 7,6 — error flags, bits 5-0 — code". -->

This is long and tedious, but that's how the hardware works. In a real program all of this is hidden inside a single `ReadSector` function.

## What the BIOS does

If you don't want to deal with the 765 FDC directly — use the BIOS or AMSDOS. AMSDOS provides file operations: open, read, write, close. This is far more convenient than poking sectors by hand.

The standard way to work with the disk in the CPC world is through AMSDOS. It takes care of all the low-level work.

If you are writing your own OS or bootloader — you will have to work with the 765 FDC directly. But for most tasks AMSDOS is enough. An example of direct FDC work is in `ROM.MAC` (`BOOT`, `INPFILE`, `DSKIO`, `FDCRD`, `RD1SEC`).

## Disk format

The Aleste uses 3.5" disks, 720 KB. This is the standard format for CPC-compatible machines.

Parameters:

- 80 tracks (cylinders).
- 2 sides.
- 9 sectors per track.
- 512 bytes per sector.

Total: 80 * 2 * 9 * 512 = 737280 bytes ≈ 720 KB.

**The AMSDOS and MSX-DOS formats are incompatible** in the layout of the directory/FAT, although the geometry (80×2×9×512) may coincide. A disk formatted under AMSDOS will not be readable in MSX-DOS, and vice versa.

<!-- FIX: corrected. It said "AMSDOS (180 KB per side)" — incorrect for 3.5".
     180 KB is the single-sided 3" format of the CPC 6128 (40×1×9×512).
     On 3.5" AMSDOS gives 720 KB (80×2×9×512). -->

## Two drives

The Aleste supports up to two drives. The second drive is connected to the same connector as the first but is selected by a separate signal.

In SETUP you can configure how many drives are connected and how they are used. If there is no second drive, it can be emulated logically — the system will consider drive B: to exist but will physically access A:.

## Write protection

A diskette has a write-protect switch. If it is set, the controller cannot write to the disk. This is hardware protection; it cannot be bypassed in software.

When attempting to write to a protected disk, the controller returns an error (ST1 bit 6 = WP — Write Protected). The program must handle it.

<!-- FIX: clarified that WP is ST1 bit 6. -->

## Errors

The 765 FDC returns the command result as 7 bytes: **ST0, ST1, ST2, C, H, R, N**.

- **ST0** (first byte): bits 7–6 = IC (Interrupt Code: 00 = normal, 01 = abnormal), bit 5 = SE (Seek End), bit 4 = EC (Equipment Check), bit 3 = NR (Not Ready), bit 2 = HD (Head), bits 1–0 = US (Unit Select).
- **ST1** (second byte): bit 0 = MA (Missing Address Mark), bit 1 = NW (Not Writable), bit 2 = ND (No Data), bit 3 = OR (Over Run), bit 4 = DE (Data Error / CRC), bit 5 = EN (End of Cylinder), bit 6 = WP (Write Protected).
- **ST2** (third byte): bit 0 = CM (Control Mark), bit 1 = DD (Data Error in Data Field), bit 2 = WC (Wrong Cylinder), bit 3 = SH (Scan Equal Hit), bit 4 = SN (Scan Not Satisfied), bit 5 = BC (Bad Cylinder).

<!-- FIX: corrected. It said "error code — bits 7,6 of the result,
     bits 5-0 — code." Incorrect: ST0 bits 7-6 = IC, and the error code
     is in ST1/ST2. -->

Main errors:

- **No disk** — ST0 bit 3 = NR (Not Ready), or ST3 bit 2 = Ready.
- **Not ready** — ST0 bit 3 = NR.
- **Data error** — ST1 bit 4 = DE (CRC Error).
- **Write protection** — ST1 bit 6 = WP.
- **Sector not found** — ST1 bit 2 = ND (No Data).

## Practical tips

**Use AMSDOS.** Don't write your own disk driver unless you want to spend weeks. AMSDOS works, is debugged, and is enough for most tasks.

**Wait for RQM (and DIO).** Always. The 765 FDC does not tolerate haste. If you write to it when it is not ready — the data will be lost, and you will get an incomprehensible error. Check not only RQM (bit 7) but also DIO (bit 6): for writing DIO must be 0, for reading — 1.

<!-- FIX: added about DIO. -->

**Don't forget to turn off the motor.** The drive motor should not spin constantly. Turn it on before an operation, turn it off after.

**Check for errors.** The 765 FDC returns error codes in ST0/ST1/ST2. If you don't check them, the program will behave strangely.

**Remember the format.** AMSDOS and MSX-DOS are different formats. Don't mix them up.

## What's next

The disk drive is covered. The next section is [the first program: an end-to-end example with comments.](./09-first-program.md)