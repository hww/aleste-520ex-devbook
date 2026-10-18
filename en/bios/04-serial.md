# 04-serial.md — Serial Port / RS-232 Driver (BIOS.DRV)

## Purpose

Manages the built-in **KR580WW51A** USART (a clone of the Intel 8251). The port is used both for communication with external devices and for the serial mouse. Baud rate timing is provided by the **KR580WI53** timer (8253).

**Critical limitation of the package:** the tail of the driver (`COM_OUT`, `COM_IN`, `COM_OUT_ST`, `COM_IN_ST`, `RX_INT`, `TX_INT`, `TEST_TX`) is **missing** from the provided sources. The vectors `L0156`–`L015F` reference undefined symbols. Below is described what these calls **should** do, based on the visible part of `COM_INI`, `CTS_INT`, and the 8251 architecture. This is a **reconstruction**, not documentation of the actual code.

**Source:** `BIOS.DRV` (truncated).

---

## Initialization

### `COM_INI` (`L0153`) — **present in the package**

Configures the 8251 and the 8253. Installs the RS-232 interrupt handlers (`XFDA4`, `XFDA9`, `XFDAE`, `XFDB3`) and resets the buffers.

```
Input:  A = frame format:
           bit2-3: character length (00=5, 01=6, 10=7, 11=8 bits)
           bit4-5: parity (00=none, 01=odd, 11=even)
           bit6-7: stop bits (01=1, 10=1.5, 11=2)
        B = baud rate: 0=300, 1=600, 2=1200, 3=2400 baud
Output: —
Modifies: all registers
```

**What it does:** writes the `Mode Instruction` to the 8251 control register (port `0EFxxH`), configures channels A and B of the 8253 timer to generate TxC/RxC, and writes the `Command Instruction` (`TxEN=1, RxEN=1, DTR=1`). If `A` bit0 = 0, `RS_MODE` = RTS/CTS; otherwise XON/XOFF.

**Example:**
```asm
    LD   A,4EH      ; 8 bits, no parity, 1 stop bit
    LD   B,2        ; 1200 baud
    CALL L0153      ; COM_INI
```

---

## Transmission (reconstruction)

### `COM_OUT_ST` (`L0156`) — **missing**

Check readiness to transmit. It should read the 8251 `Status Register` (port `0EFxxH`) and check bit 0 (`TxReady` / `DB Buffer Empty`).

```
Input:  —
Output: ZF=1 if it is possible to write (buffer empty)
        ZF=0 if busy
Modifies: AF
```

### `COM_OUT` (`L0159`) — **missing**

Output a byte. It should either write directly to the `Data Register` (port `0EExxH`) if the buffer is empty, or put the byte into `TX_BUF` and wait for the `TxRDY` interrupt.

```
Input:  A = byte to transmit
Output: CF=1 if the buffer is full (byte not sent)
        CF=0 if accepted
Modifies: AF
```

**Logic from context:** in `COM_INI` there are `TX_HEAD`/`TX_TAIL` (pointers into `TX_BUF`), and `CTS_INT` reads `TX_HEAD` and writes to the port. So `COM_OUT` is most likely **buffered**: the byte is put into `TX_BUF`, `TX_TAIL` is advanced, and the actual transmission happens in `TX_INT` on the `TxRDY` interrupt. `CF=1` — if the buffer is overflowed (`TX_TAIL` caught up with `TX_HEAD`).

---

## Reception (reconstruction)

### `COM_IN_ST` (`L015C`) — **missing**

Check for received data. It should read the 8251 `Status Register` and check bit 1 (`RxReady`), or compare `RX_HEAD` and `RX_TAIL` (if reception is buffered via `RX_INT`).

```
Input:  —
Output: ZF=1 if there is data to read
        ZF=0 if there is no data
Modifies: AF
```

### `COM_IN` (`L015F`) — **missing**

Receive a byte. It should either read the `Data Register` directly or take a byte from `RX_BUF` via `RX_TAIL`. It also checks `Ctrl+C` via `BREAK` (by analogy with `LPTOUT`).

```
Input:  —
Output: A = received byte
        CF=1 if Ctrl+C is pressed (interrupt)
Modifies: AF
```

**Logic from context:** `RX_BUF` (40h bytes), `RX_HEAD`/`RX_TAIL` are initialized in `COM_INI`. `RX_INT` (missing) should receive a byte on the `RxRDY` interrupt and put it into `RX_BUF`, advancing `RX_HEAD`. `COM_IN` reads from `RX_BUF` via `RX_TAIL`.

---

## Interrupt handlers (partially present)

### `RS_ERR` — **present**

Error handler (vector `XFDA4`). Sets the error reset bit (`RS_COM |= 10H`) and writes it back to the control port.

### `CTS_INT` — **present (truncated at the `TEST_TX` call)**

CTS handler (vector `XFDA9`). In RTS/CTS mode it checks the CTS line and, if there is data in `TX_BUF`, sends it directly to the port. **Does not link** because `TEST_TX` is missing.

### `RX_INT` — **missing**

Should read the `Data Register` on the `RxRDY` interrupt, put the byte into `RX_BUF` via `RX_HEAD`, handle XON/XOFF (flags `RX_XOFF`/`TX_XOFF`), check for buffer overflow, and call the `XFDAE` hook.

### `TX_INT` — **missing**

Should take a byte from `TX_BUF` via `TX_HEAD` and write it to the `Data Register` on the `TxRDY` interrupt, advancing `TX_HEAD`. In XON/XOFF mode it checks `TX_XOFF` (if set — do not transmit).

### `TEST_TX` — **missing**

Called from `CTS_INT`. Probably checks the `TX_XOFF` flag or readiness to transmit in XON/XOFF mode.

---

## Driver variables

| Address   | Name       | Purpose                    |
|-----------|------------|----------------------------|
| `0FF00H`  | `RX_BUF`   | Receive buffer (40H bytes) |
| `0FF40H`  | `TX_BUF`   | Transmit buffer (40H bytes) |
| `0FF80H`  | `RX_HEAD`  | Write pointer into `RX_BUF` |
| `0FF82H`  | `RX_TAIL`  | Read pointer from `RX_BUF` |
| `0FF84H`  | `TX_HEAD`  | Read pointer from `TX_BUF` |
| `0FF86H`  | `TX_TAIL`  | Write pointer into `TX_BUF` |
| `0FF88H`  | `RS_COM`   | Shadow 8251 command register |
| `0FF89H`  | `RS_STAT`  | Shadow 8251 status register |
| `0FF8AH`  | `RS_MODE`  | `0` = RTS/CTS, `1` = XON/XOFF |
| `0FF8BH`  | `RX_XOFF`  | XOFF flag (receive)        |
| `0FF8CH`  | `TX_XOFF`  | XOFF flag (transmit)       |

---

## Ports

| Port      | Purpose |
|-----------|---------|
| `0EExxH`  | 8251 Data Register (read/write) |
| `0EFxxH`  | 8251 Control/Status Register (write/read) |

---

## Limitations

1. **Mouse and RS-232 are incompatible.** Both use the same USART and the same buffers. For RS-232, first call `MOUS_OFF`.
2. **The tail of the driver is missing.** Without restoring `COM_OUT`/`COM_IN`/`COM_OUT_ST`/`COM_IN_ST`/`RX_INT`/`TX_INT`/`TEST_TX` the build is impossible.
3. **Baud rate only up to 2400** (per `RATE_TAB`: 300/600/1200/2400).

---

## See also

- [README.md](README.md) — overview and memory map
- [03-mouse.md](03-mouse.md) — mouse (shares the port)
- [08-errata.md](08-errata.md) — known issues