# 01. The World View

Before diving into ports and registers, it's crucial to understand how the machine is structured in general. Otherwise, things will get messy: manuals are full of terms like "bank," "page," "mapper," "MAPMOD," and without a general picture, they don't make sense.

This section is that very general picture. We won't delve into details; we'll just put everything in its place. The details will come in the following sections.

## Z80 and Its 64 Kilobytes

The Z80 processor can address exactly 64 kilobytes of memory. This is its physical limit, and no tricks can bypass it. The address bus is 16 bits wide, meaning addresses range from 0x0000 to 0xFFFF.

Within these 64 kilobytes, the processor sees four 16-kilobyte windows:

| Window       | Addresses        | Size |
|--------------|------------------|------|
| Page 0       | 0x0000–0x3FFF    | 16 KB |
| Page 1       | 0x4000–0x7FFF    | 16 KB |
| Page 2       | 0x8000–0xBFFF    | 16 KB |
| Page 3       | 0xC000–0xFFFF    | 16 KB |

The term "page" here refers to a window in the processor's address space. This is important: later, we'll use the term "bank," and it means something different.

## Banks: How to Fit 512 Kilobytes into 64 Kilobytes

The Aleste 520EX has 512 kilobytes of physical RAM. But the Z80 only sees 64. How is this possible?

Memory is sliced into 16-kilobyte chunks, each called a **bank**. 512 KB is 32 banks. Each bank has a number: 0, 1, 2, … 31.

The processor still sees four windows (pages 0–3). But each window is not a fixed chunk of memory, but a **switch**. Any bank can be placed into any window. Want to put bank 5 into window 1? Fine. Want to put bank 17? Fine.

This switching is called **mapping**, and the device that controls it is called a **mapper**.

Think of it like a wardrobe with 32 drawers. You have a table with four slots. You can pull out any drawer and place it in any slot. Look at the slot, and you see the contents of the drawer. Swap out a drawer, and you see something else. The drawers themselves don't go anywhere; they just aren't visible on the table at any given time.

That's how Aleste's memory works. Physically, it has 512 KB, but the processor sees only 64 KB — the four banks currently in the windows.

## Why This Matters

Three reasons.

First: **more memory for programs**. A program on CPC usually runs in 64 KB. On Aleste, you can keep several screens, buffers, and data in memory and switch them as needed.

Second: **RAM disk**. Part of the memory can be allocated as a virtual disk: programs read and write to it as if it were a regular disk drive, but it happens instantly because it's just memory.

Third: **compatibility with CPC**. Old software expects the CPC memory mapping scheme. Aleste can pretend to be CPC — for this, there's a separate mode.

## Two Worlds: CPC Mode and Aleste Mode

This is an important point that is poorly explained in the manuals.

The Aleste 520EX can operate in two modes, and they are toggled by a single bit. This bit is called **MAPMOD** and lives in port `#FABF` (details in the ports section). For now, just remember: there's a flag that changes the machine's behavior.

**When MAPMOD = 0 (CPC mode):**

The machine behaves like the Amstrad CPC 6128. Palette — 27 colors. Memory banking — CPC scheme (via port `#7F00`). Old software works as expected.

**When MAPMOD = 1 (Aleste mode):**

The machine enables extensions. Palette — 64 colors. Memory banking — extended, via four ports `#7CXX`–`#7FXX`, one for each page. This is where all 512 KB and all 64 colors become available.

This is not "or forever." The mode can be switched on the fly. But you need to understand which mode you're in because it affects how memory works and how the screen looks.

Later in the documentation, we'll explicitly indicate which mode we're talking about.

## Input/Output Ports: Briefly

Besides memory, the Z80 has a separate address space for input/output ports. Commands `IN` and `OUT`. The port address is also 16 bits, ranging from 0x0000 to 0xFFFF.

There's a subtlety that confuses many. In CPC and Aleste, **the port is decoded partially**. This means the device responds not to the entire address but only to certain bits of it. The rest are ignored.

Example: the Gate Array in CPC listens to port `#7FXX`. Here, `XX` can be any value. So `OUT #7F00` and `OUT #7FAB` both go to the same device because the Gate Array only looks at the upper byte of the address, and the lower byte doesn't matter.

This is done intentionally: it allows addressing multiple devices simultaneously with different masks that don't overlap. But it's also the source of confusion: two different devices can share the same address.

What this means for a programmer: **a port address is not a single number but a mask**. When the documentation says `#F4XX`, it means "all addresses where the upper byte is F4." When it says `%xxxx0x00 xxxxxxxx`, it means the device looks at specific bits: bit 11 should be 0, bits 9 and 8 should be 00. The rest of the bits don't matter.

A detailed table of ports is in the "Port Reference" section. For now, it's important to understand the principle: **in CPC and Aleste, a port is not a fixed address but a set of bits that must match**.

## What Lies Where by Default

To complete the picture, here's a simplified memory map immediately after booting, in CPC mode:

| Addresses        | What's There                                           |
|------------------|-------------------------------------------------------|
| 0x0000–0x3FFF    | Lower ROM (BIOS) or RAM, depending on the flag         |
| 0x4000–0x7FFF    | Upper ROM (BASIC) or RAM                               |
| 0x8000–0xBFFF    | RAM                                                   |
| 0xC000–0xFFFF    | RAM (usually AMSDOS or BOOTMENU resides here)         |

The exact map depends on whether ROM or RAM is enabled in each window. These are controlled by individual bits in the Gate Array and port `#DFXX`. Details are in the "Memory" section.

For now, just remember: **by default, ROM is in the higher addresses, and RAM starts somewhere in the middle**. Programs typically live in RAM, while BASIC and BIOS reside in ROM.

## Important Hardware Features to Know Right Away


Three things that set Aleste apart from a regular CPC. We will discuss them in detail later, but it's worth knowing about them from the start.

**First: USART instead of a printer.** In CPC, port `#EFXX` is the printer port. In Aleste, the same address houses the 8251 USART — a serial port for RS-232, mice, and similar devices. If you bring an old CPC program to Aleste that prints to the printer, it will go to the wrong place. This is not a bug, but a hardware solution.

**Second: the printer is implemented differently.** Since the USART took over the old address, the printer in Aleste is connected via other chips: data goes through the sound chip AY-3-8910, and the strobes go through PPI 8255. This is important for a programmer writing a printer driver.

**Third: MSX keyboard.** Physically, the keyboard is from an MSX with its characteristic five functional keys. However, at the port level, the processor sees a regular CPC matrix — because there is logic between the keyboard and the processor that translates the MSX matrix into a CPC matrix. Additionally, there are ten extra keys that CPC did not have.

## What's Next

The first section is on [memory management.](./01-memory.md)