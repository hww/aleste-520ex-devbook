# 06. Port Reference

This section is a reference. There are no long explanations here, but there is a complete table of ports and warnings about where the Aleste differs from the CPC.

If you have already read the sections on memory, screen, and sound — much here will be familiar. This section is meant as a reference to come back to.

## How to read the table

A port address is written as `#XXXX`, where `X` is a hexadecimal digit. But remember: **decoding is partial**. A device responds not to the whole address but only to certain bits. Therefore the notation `#F4XX` means "all addresses whose high byte is F4." `XX` is any value.

The "Decoded as" column shows which bits matter. The pattern is written as **16 bits** (A15…A0): for example, `%11110100 xxxxxxxx` means:

- A15–A8 = `11110100` (`0xF4`) — the high byte of the address;
- A7–A0 — any (`x`).

The "Status" column shows what the Aleste does with this port:

- **keep** — the port works the same as in the CPC;
- **modify** — the port exists but works differently;
- **reserved** — the port is reserved (in the CPC there was something there, in the Aleste there isn't);
- **remove** — the port is removed, the functionality is absent.

## Official CPC ports

First — what was in the CPC 6128. This is the base on which everything else is built.

| I/O     | Decoded as           | Port                       | RW |
|---------|----------------------|----------------------------|----|
| `#7FXX` | `%01111111 xxxxxxxx` | Gate Array                 | W  |
| `#BCXX` | `%10111100 xxxxxxxx` | 6845 CRTC Index            | W  |
| `#BDXX` | `%10111101 xxxxxxxx` | 6845 CRTC Data Out         | W  |
| `#BEXX` | `%10111110 xxxxxxxx` | 6845 CRTC Status           | R  |
| `#BFXX` | `%10111111 xxxxxxxx` | 6845 CRTC Data In          | R  |
| `#DFXX` | `%11011111 xxxxxxxx` | Upper ROM Bank Number      | W  |
| `#EFXX` | `%11101111 xxxxxxxx` | Printer Port               | W  |
| `#F4XX` | `%11110100 xxxxxxxx` | 8255 PPI Port A (PSG Data) | RW |
| `#F5XX` | `%11110101 xxxxxxxx` | 8255 PPI Port B            | R  |
| `#F6XX` | `%11110110 xxxxxxxx` | 8255 PPI Port C            | W  |
| `#F7XX` | `%11110111 xxxxxxxx` | 8255 PPI Control           | W  |
| `#FA7E` | `%11111010 01111110` | Floppy Motor Control       | W  |
| `#FB7E` | `%11111011 01111110` | 765 FDC Status             | R  |
| `#FB7F` | `%11111011 01111111` | 765 FDC Data               | RW |

This is the standard. Any program written for the CPC expects exactly these ports.

## Aleste ports

Now — what the Aleste does with this list.

| I/O               | Decoded as             | Status | Port                          | RW |
|-------------------|------------------------|--------|-------------------------------|----|
| `#7CXX`           | `%01111100 xxxxxxxx`   | keep   | RAM Mapper page 0             | RW |
| `#7DXX`           | `%01111101 xxxxxxxx`   | keep   | RAM Mapper page 1             | RW |
| `#7EXX`           | `%01111110 xxxxxxxx`   | keep   | RAM Mapper page 2             | RW |
| `#7FXX`           | `%01111111 xxxxxxxx`   | keep   | RAM Mapper page 3 / Gate Array| RW |
| `#BCXX`–`#BFXX`   | —                      | keep   | CRTC 6845                     | —  |
| `#DFXX`           | `%11011111 xxxxxxxx`   | keep   | Upper ROM (bank 3 = Bootmenu) | W  |
| `#EEXX`           | `%11101110 xxxxxxxx`   | modify | 8251 USART Data (RS232/Mouse) | RW |
| `#EFXX`           | `%11101111 xxxxxxxx`   | modify | 8251 USART Control/Status     | RW |
| `#F4XX`–`#F7XX`   | —                      | keep   | PPI 8255                      | —  |
| `#FA7E`           | `%11111010 01111110`   | keep   | Floppy Motor Control          | W  |
| `#FABF`           | `%11111010 10111111`   | modify | EXTPORT                       | W  |
| `#FB7E` / `#FB7F` | —                      | keep   | 765 FDC                       | —  |

## Conflicts: where the Aleste breaks compatibility

This is important. Three groups of ports that worked in the CPC but do not in the Aleste.

| I/O     | Decoded as             | Status   | Port                         | RW |
|---------|------------------------|----------|------------------------------|----|
| `#EFXX` | `%11101111 xxxxxxxx`   | reserved | Printer Port (CPC)           | W  |
| `#FAD0` | `%11111010 11010000`   | reserved | (CPC: free; Aleste+MS: VOL_A) | W |
| `#FAD1` | `%11111010 11010001`   | reserved | (CPC: free; Aleste+MS: VOL_B) | W |
| `#FAD2` | `%11111010 11010010`   | reserved | (CPC: free; Aleste+MS: VOL_C) | W |
| `#FAD3` | `%11111010 11010011`   | reserved | (CPC: free; Aleste+MS: VOL_D) | W |
| `#FADC` | `%11111010 11011100`   | reserved | Amstrad SIO/DART port A Data | RW |
| `#FADD` | `%11111010 11011101`   | reserved | SIO/DART port A Control      | RW |
| `#FADE` | `%11111010 11011110`   | reserved | SIO/DART port B Data         | RW |
| `#FADF` | `%11111010 11011111`   | reserved | SIO/DART port B Control      | RW |
| `#FBDC` | `%11111011 11011100`   | reserved | (CPC: 8253 counter 0; Aleste+MS: DMAP_D+0) | RW |
| `#FBDD` | `%11111011 11011101`   | reserved | (CPC: 8253 counter 1; Aleste+MS: DMAP_D+1) | RW |
| `#FBDE` | `%11111011 11011110`   | reserved | (CPC: 8253 counter 2; Aleste+MS: DMAP_D+2) | RW |
| `#FBDF` | `%11111011 11011111`   | reserved | (CPC: 8253 Mode Select; Aleste+MS: DMAP_D+3) | W |

What this means in practice.

**Port `#EFXX`.** In the CPC this is the printer. In the Aleste the 8251 USART lives at the same address. An old CPC program that prints to the printer will hit the USART. This is not a bug, it's a hardware decision. The printer in the Aleste works differently (see below).

**Ports `#FAD0`–`#FAD3`.** In the CPC these addresses are free. In the Aleste with the Magic Sound Board installed — these are the volume registers of channels A/B/C/D (`VOL_A`–`VOL_D` in `mag.txt`). If the board is not present — the addresses are free.

**Ports `#FADC`–`#FADF`.** In the CPC this is the Z80-SIO/DART chip — a serial interface that was fitted in some models. The Aleste doesn't have it. Programs that use it will not work.

**Ports `#FBDC`–`#FBDF`.** In the CPC this is the 8253 timer, which worked together with the SIO. In the Aleste without Magic Sound — absent; with Magic Sound — this is the channel D mapper (`DMAP_D = #FBDC`, `#FBDC`–`#FBDF`). That is, if the board is installed, these ports are **occupied** and are not "reserved."

## Ext Port (port #FABF)

A separate port that the CPC did not have. It controls several Aleste functions.

Per `BIOS.MAC` (`EXTPORT EQU 0FDF5H`, contents of `#FABF`):

| Bit | Status | Action                      |
|-----|--------|-----------------------------|
| 7–6 | —      | Not used                    |
| 5   | modify | 0 = AY8910, 1 = 512WI1      |
| 4   | modify | 580WI53 (timer)             |
| 3   | modify | MAP Page 0/1 (256K)         |
| 2   | modify | MAPMOD (0 = Amstrad, 1 = Yamaha) |
| 1   | modify | HIGHX (0 = norm, 1 = high resolution) |
| 0   | modify | VRAM Bank 0/1 (64K)         |

### Bit 5: AY8910 / 512WI1

0 = AY-3-8910 (standard PSG), 1 = 512WI1 (alternative sound chip). Default 0.

### Bit 4: 580WI53

Selects the 580WI53 timer (used for RTC, mouse, RS-232). Default 0.

### Bit 3: MAP Page

Selects the memory page (0 or 1) for the 256K expansion. Affects which memory bank is visible in the page. Details — in the memory section.

### Bit 2: MAPMOD

The main switch. 0 — CPC mode (Amstrad), 1 — Aleste mode (Yamaha mapper). Details — in the memory section.

### Bit 1: HIGHX

Enables high-resolution modes (32 KB video buffer). Affects frequencies and video address decoding. Details — in the screen section.

### Bit 0: VRAM Bank

Selects the video bank (0 or 1) for 64K VRAM. Used for double buffering and scrolling.

## Multiport (port #7FXX)

This is the analogue of the CPC Gate Array, but with extensions. Four registers, selected via bits 7 and 6 of the byte being written.

| D7 | D6 | Register | What                   |
|----|----|----------|------------------------|
| 0  | 0  | 0        | Palette index          |
| 0  | 1  | 1        | Palette data           |
| 1  | 0  | 2        | Mode, ROM enable, LEDs |
| 1  | 1  | 3        | RAM banking            |

### Register 0: Palette index

Selects the palette index (which color to change). Bits 4–0 — the index number.

| Index   | What                      |
|---------|---------------------------|
| 00h–0Fh | Ink 0–15 (pixel colors)   |
| 10h     | Border                    |
| 11h–1Fh | Same as 10h               |

### Register 1: Palette data

Data for the selected index. Six bits: two for red, two for green, two for blue.

Details — in the screen section.

### Register 2: Mode, ROM enable, LEDs

| Bit | What                     |
|-----|--------------------------|
| 7   | Always 1                 |
| 6   | Always 0                 |
| 5   | CAPS LED                 |
| 4   | RUS LED (Aleste) / Interrupt reset (CPC) |
| 3   | Upper ROM enable/disable (1 = disable, 0 = enable) |
| 2   | Lower ROM enable/disable (1 = disable, 0 = enable) |
| 1–0 | Mode                     |

Bits 5 and 4 control two LEDs: CAPS (uppercase) and RUS (Russian mode). This is an Aleste feature; the CPC does not have it.

**Important:** in the classic CPC, RMR bit 4 is **Interrupt reset** (HSYNC counter reset). In the Aleste, RMR bit 4 is **RUS LED** (the Russian-mode LED), and the HSYNC counter reset occurs **only on VSYNC**. This difference matters: a program that relies on a software reset of the counter via RMR will not work on the Aleste.

### Register 3: RAM banking

In CPC mode (MAPMOD = 0) it works as the CPC6128 bank register. In Aleste mode (MAPMOD = 1) it is used for the extended mapper.

Details — in the memory section.

## Upper ROM banks

Port `#DFXX` selects the upper ROM bank.

| Value | Name     | What                     |
|-------|----------|--------------------------|
| 00h   | BASIC    | BASIC and part of the BIOS |
| 03h   | BOOTMENU | Aleste boot menu         |
| 07h   | AMSDOS   | Disk OS                  |

The remaining values (01, 02, 04, 05, 06, 08–FF) also select BASIC. This is a hardware feature.

## Printer in the Aleste

Since the USART took over the old printer address (`#EFXX`), the printer is done differently:

- Data (8 bits) goes through PSG register 15 (port B of the AY-3-8910).
- Strobe — through PPI Port C, bit 4.
- Busy — through PPI Port B, bit 6.

This is not the CPC scheme. A program that writes to `#EFXX` as if it were the printer will hit the USART on the Aleste.

## Keyboard

The keyboard is connected through the PPI:

- Port C (low 4 bits) — matrix row select (0–10).
- Port A — read data of the selected row.

The matrix is 11 rows of 8 bits. Details — in the keyboard section.

## Disk drive

765 FDC controller.

| Port    | What   | RW |
|---------|--------|----|
| `#FA7E` | Motor  | W  |
| `#FB7E` | Status | R  |
| `#FB7F` | Data   | RW |

Details — in the disk section.

## Practical tips

**Remember about `#EFXX`.** This is the main trap for CPC software. The printer there is no longer a printer.

**`#FABF` is for the BIOS only.** The documentation says that only the BIOS should write to this port. If you write to it yourself — be careful, you can break video or memory.

**MAPMOD affects everything.** Palette, banking, modes. Check its value when something doesn't work.

**Read the Status.** If a port is marked as reserved — don't expect it to work as in the CPC. It simply isn't there.

**Remember RMR bit 4.** In the CPC it is Interrupt reset; in the Aleste — RUS LED. The HSYNC counter reset on the Aleste is only via VSYNC. See the interrupts section.

## What's next

Ports are covered. The next section is [about the disk drive: the 765 FDC controller, ports, reading a sector.](./07-keyboard.md)

