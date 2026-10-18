# 11. Expansion Port

The Aleste has an expansion port — a connector to which external devices are connected: expansion boards, cartridges, additional interfaces. It is through this port that the Magic Sound Board and other boards work.

This section covers what this connector is, how it differs from the CPC version, and what you need to know if you are going to build your own device or connect a ready-made one.

## What the expansion port is

It is a physical connector on the back of the machine to which devices not included in the base configuration are connected.

Through it go:

- Address bus (A0–A15) — 16 lines.
- Data bus (D0–D7) — 8 lines.
- Z80 control signals: `/MREQ`, `/IORQ`, `/RD`, `/WR`, `/M1`, `/RFSH`, `/HALT`, `/INT`, `/NMI`, `/BUSRQ`, `/BUSAK`, `/RESET`, `/WAIT`.
- Power: +5V, GND.
- Clock signal 4 MHz.
- Video chip signals: `CURSOR`, `L.PEN`.
- ROM/RAM signals: `/ROMEN`, `ROMDIS`, `RAMDIS`, `/RAMRD`.
- Sound (mono).
- Special signals: `/EXP`, `/BRST`.

This is the standard set for CPC-compatible machines. Through such a connector you can connect practically anything: memory, ROM cartridges, sound boards, controllers, debugging devices.

## CPC: 50 pins

In the original Amstrad CPC the expansion port is a 50-pin connector (Delta range).

| Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|
| 1   | Sound  | 2   | GND    |
| 3   | A15    | 4   | A14    |
| 5   | A13    | 6   | A12    |
| 7   | A11    | 8   | A10    |
| 9   | A9     | 10  | A8     |
| 11  | A7     | 12  | A6     |
| 13  | A5     | 14  | A4     |
| 15  | A3     | 16  | A2     |
| 17  | A1     | 18  | A0     |
| 19  | D7     | 20  | D6     |
| 21  | D5     | 22  | D4     |
| 23  | D3     | 24  | D2     |
| 25  | D1     | 26  | D0     |
| 27  | VCC    | 28  | /MREQ  |
| 29  | /M1    | 30  | /RFSH  |
| 31  | /IORQ  | 32  | /RD    |
| 33  | /WR    | 34  | /HALT  |
| 35  | /INT   | 36  | /NMI   |
| 37  | /BUSRQ | 38  | /BUSAK |
| 39  | READY  | 40  | /BRST  |
| 41  | /RSET  | 42  | /ROMEN |
| 43  | ROMDIS | 44  | /RAMRD |
| 45  | RAMDIS | 46  | CURSOR |
| 47  | LPEN   | 48  | /EXP   |
| 49  | GND    | 50  | CLK4   |

The `/` prefix means active low level (the signal is active when equal to 0).

## Aleste: 62 pins

The Aleste connector is larger — 62 pins instead of 50. The first 50 pins match the CPC (with one exception), and the additional 12 are Aleste extensions.

The connector is a male edge connector, that is, a pin/edge-type connector.

### Main pins

| Pin     | Signal                                |
|---------|---------------------------------------|
| A1–A25  | Same as the odd pins of CPC 1–49      |
| B1–B25  | Same as the even pins of CPC 2–50     |

That is, if you have a device for the CPC with a 50-pin connector, it can be connected to the Aleste via a 62→50 adapter. Most signals match.

**Exception:** pin **B20** (in CPC numbering — **pin 40**). In the CPC this is **`/BRST`** (Burst, used in the CPC+; not used in the classic CPC), in the Aleste — **NC** (not connected). This means that devices using the CPC+ burst mode will not work on the Aleste.

### Additional pins

| Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|
| A26 | MAP14  | B26 | MAP15  |
| A27 | MAP16  | B27 | MAP17  |
| A28 | MAP18  | B28 | MAPBLK |
| A29 | /INTA  | B29 | /DISP  |
| A30 | Agnd   | B30 | /CPU   |
| A31 | Aucc   | B31 | HIGH   |

Let's go through what these are. **Important:** the pinout of the Aleste additional pins is incompletely documented. Below is the most plausible interpretation based on community observations; it is **not verified against the BIOS sources** (in `BIOS.MAC`/`ROM.MAC`/`mag.txt` there are no direct references to these signals).

**MAP14–MAP18 (A26–A28, B26–B27)** — additional address lines for extended memory. They allow devices on the expansion port to address more memory than the standard 64 KB. (Hypothesis; not verified against the code.)

**MAPBLK (B28)** — mapper block signal. Allows an external device to temporarily disable the Aleste's internal mapper and take over memory management. (Hypothesis.)

**/INTA (A29)** — Interrupt Acknowledge. The interrupt acknowledge signal. Used when an external device handles an interrupt. (Hypothesis; the Z80 does not have a standard `/INTA` — possibly the Aleste added it for DMA/external controllers.)

**/DISP (B29)** — Display. A signal related to video. The purpose is not precisely documented.

**/CPU (B30)** — a signal related to the processor. The purpose is not precisely documented.

**Agnd (A30)** and **Aucc (A31)** — "analog" ground and power. These are cleaner versions of GND and VCC intended for audio devices: less noise, better sound quality.

**HIGH (B31)** — a high-level signal. Possibly just a pull-up to VCC for compatibility.

### What this means

The Aleste additional pins are probably DMA extensions. The signals MAP14–MAP18, MAPBLK and `/INTA` allow external devices to:

- Address memory beyond 64 KB.
- Control the mapper directly.
- Work with interrupts.

This is precisely why the Magic Sound Board works only on the Aleste, not on the CPC: it needs these additional signals for DMA access to memory. (This is an **inference**, not a fact from the sources: in `mag.txt` the player works through the ports `#F8Dx`/`#F9Dx`/`#FADx`/`#FBDx`, not through the expansion port signals directly. But DMA physically requires address/data/control signals that the CPC does not have.)

The analog Agnd/Aucc are for audio boards. If you are building a sound device, use them instead of ordinary GND/VCC to avoid picking up noise from the digital part.

## Other machines

For reference: other machines of that era had their own variants of the expansion port.

**Amstrad PCW** — a 50-pin connector, but the pinout is completely different. Not compatible with the CPC.

**KC Compact** — a 58-pin connector of a special type. The pinout partially matches the CPC (pins 1B–26B and 1A–26A), but there are additional pins for video, printer, and test mode.

**CPC+** — 50-pin, compatible with the CPC, but with some additions inside the machine.

If you have a device for one of these machines — check the pinout before connecting it to the Aleste. A power mismatch can burn the device.

## What can be connected

Through the expansion port the following are connected to the Aleste:

**ROM cartridges.** External ROMs with programs. The ROMDIS and /ROMEN signals allow the cartridge to substitute the machine's internal ROM.

**RAM expansions.** External memory. The RAMDIS and /RAMRD signals allow the internal RAM to be disabled and external RAM to be used.

**Sound boards.** The Magic Sound Board and similar.

**Controllers.** Additional disk drives, hard disks, network interfaces.

**Debugging devices.** Logic analyzers, in-circuit emulators.

**Home-made devices.** Anything at all, if you know what you are doing.

## If you are building your own device

A few things worth keeping in mind.

**Power.** The +5V on the expansion port is weak. It is intended to power chips and signal circuits, not heavy peripherals. If your device consumes a lot — use external power.

**Level matching.** All signals are TTL level (0V and +5V). Do not feed anything above +5V into the port.

**Don't occupy others' addresses.** Check the port map (see the "Port Reference" section) before choosing addresses for your device. Otherwise you will conflict with existing ones.

**Use /EXP.** This signal allows a device to inform the machine of its presence. It is connected to bit 5 of PPI port B. If your device can do this — use it.

**Be careful with /NMI and /INT.** These are interrupt signals. If your device pulls them — it can break the operation of the whole system. Use them only if you know exactly what you are doing.

**Check the pinout.** 62 pins is not 50. Make sure your adapter or device is correctly matched.

## Documentation

A full description of the CPC expansion port signals is available on the internet. Look for:

- **CPCWiki: Expansion port** — pinout and description.
- **Amstrad CPC Technical Reference Manual** — official documentation.
- **Z80 Datasheet** — for understanding the control signals (`/MREQ`, `/IORQ`, `/RD`, `/WR`, `/M1`, `/RFSH`, `/HALT`, `/INT`, `/NMI`, `/BUSRQ`, `/BUSAK`, `/RESET`, `/WAIT`).

For the Aleste-specific signals (MAP14–MAP18, MAPBLK, /INTA, /DISP, /CPU) the documentation is less complete. Some information is in the original manuals, some only in the form of community observations. **Do not rely on these signals without verification on real hardware.**

<!-- FIX: added the caveat "do not rely without verification on real hardware." -->

## Practical tips

**Start simple.** If you want to build your own device for the expansion port — start with something simple: for example, a ROM cartridge or a simple I/O interface. Don't take on DMA right away.

**Use ready-made adapters.** If you need to connect a CPC device to the Aleste — buy or make a 62→50 adapter. Don't resolder the connector.

**Check the power.** Before connecting a device — check how much it consumes. The weak +5V on the expansion port is a common limitation.

**Read the datasheets.** All Z80 signals are described in the processor datasheet. If something is unclear — start there.

## What's next

This is the last reference section. Next — the first program, where we put everything together.

