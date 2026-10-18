# 05-printer.md — Printer Driver (BIOS.DRV)

## Purpose

Outputs characters to the printer via the parallel port (Centronics) or the serial port (RS-232), depending on the `SETUP` settings. The driver checks printer readiness, handles `Ctrl+C` to interrupt lengthy printing, and emits a short beep via the AY8910 when sending a byte (for diagnostics).

This is **not the CPC printer** via the PPI. The Aleste uses a separate control port, and the choice of interface (parallel/serial) is determined by a bit in `SETUP+18H` (see `ROM.MAC`). The printer driver in `BIOS.DRV` works **only with the parallel port** — serial output was probably done via `COM_OUT` (missing).

**Source:** `BIOS.DRV` (included via `INCLUDE BIOS.DRV` in `BIOS.MAC`).

---

## Output

### `LPTOUT` (`L012F`)

Output a single character to the printer. Waits for readiness (`LPTSTT`), checks `Ctrl+C` (`BREAK`), sends the byte, and emits a short beep via the AY8910.

```
Input:  A = character code
Output: CF=1 if Ctrl+C is pressed (character not sent, CR sent instead)
        CF=0 if sent
Modifies: AF
```

**Logic:**
1. Calls the `XFDDB` hook (LPTOUT hook).
2. In a loop: checks `BREAK` (if `Ctrl+C` — sends `CR` and exits with `CF=1`), checks `LPTSTT` (if busy — repeats).
3. Sends the byte via `LPTOUT_3`: writes `0FH` to the AY8910 (register 0FH — channel A volume?), then manipulates port `0F6xxH` (the `STB` strobe).
4. Returns `CF=0`.

**Example:**
```asm
    LD   A,'H'
    CALL L012F      ; LPTOUT
    JR   C,ABORTED  ; Ctrl+C
    LD   A,'i'
    CALL L012F
```

**Example (print a string):**
```asm
PRINT_STR:
    LD   A,(DE)
    AND  A
    RET  Z
    CALL L012F
    RET  C          ; Ctrl+C — abort
    INC  DE
    JR   PRINT_STR
```

---

## Readiness check

### `LPTSTT` (`L0132`)

Check printer readiness. Reads port `0F5xxH` (status) and checks the `BUSY` bit.

```
Input:  —
Output: A = 00, ZF=0 if ready
        A = FF, ZF=1 if busy
Modifies: AF
```

**Logic:** reads `0F5xxH`, does `RLCA` twice (shifts the `BUSY` bit into bit 0), `CCF` (inverts), `SBC A,A` (turns it into `00` or `FF`). If `BUSY=0` (ready) — `A=00, ZF=0`; if `BUSY=1` (busy) — `A=FF, ZF=1`.

**Example:**
```asm
WAIT_READY:
    CALL L0132
    JR   Z,WAIT_READY   ; ZF=1 — busy, wait
    ; printer is ready
```

---

## Internal structure

### `LPTOUT_3`

Low-level byte transmission. Writes `0FH` to the AY8910 (register 0FH), then manipulates port `0F6xxH`:

```
    LD   D,0FH
    CALL WR_PSG      ; AY8910 reg 0Fh = 0Fh
    DI
    LD   E,B
    LD   B,0F6H
    IN   A,(C)       ; read the current port state
    AND  30H         ; keep bits 4-5
    OR   10H         ; set STB (bit 4)
    OUT  (C),A       ; STB = 1
    EX   (SP),HL     ; delay
    EX   (SP),HL
    AND  20H         ; clear STB, keep bit 5
    OUT  (C),A       ; STB = 0 (strobe)
    LD   B,E
    EI
    RET
```

**What is happening here:** bit 4 of port `0F6xxH` is the Centronics `STB` (strobe). Bit 5 is probably `AUTO LF` or `INIT`. The sequence `STB=1 → delay → STB=0` is a standard strobe pulse.

**Why `WR_PSG`?** Probably for diagnostics: if the printer does not respond, the AY8910 sound confirms that the driver reached the send step. Or it is part of a circuit where the AY8910 controls something related to the printer (unlikely, but possible).

---

## Variables

The printer driver **has no variables of its own** in the work area. All state is in the ports and in `SETUP` (interface selection).

---

## Hooks

| Address   | Name     | When called |
|-----------|----------|-------------|
| `0FDDBH`  | `XFDDB`  | LPTOUT hook — at the start of `LPTOUT` |

---

## Limitations

1. **Parallel port only.** `LPTOUT` works with Centronics via `0F6xxH`. Serial output probably went via `COM_OUT` (missing).
2. **`Ctrl+C` sends `CR`.** When `LPTOUT` is interrupted it sends `0DH` (CR) so the printer does not remain in the middle of a line.
3. **Sound on every send.** `LPTOUT_3` writes `0FH` to the AY8910 — this may be undesirable if you use the AY8910 for music. It is probably a diagnostic signal that can be disabled by replacing `WR_PSG` with `NOP`/`RET`.
4. **No error checking.** The driver does not read `ERROR`/`PE`/`SLCT` — only `BUSY`.

---

## See also

- [README.md](README.md) — overview and memory map
- [04-serial.md](04-serial.md) — RS-232 (alternative interface)
- [08-errata.md](08-errata.md) — known issues