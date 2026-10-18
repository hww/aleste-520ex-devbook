# Aleste 520EX — Programming for the Z80 Developer

## What this document is

This is a guide for a programmer who knows how to work with the Z80 but has never dealt with the Amstrad CPC or the Aleste 520EX.

The goal is to provide the sufficient minimum to understand how the machine is structured and to write a first program. Not "everything about everything," but answers to the questions "what is this, what is it for, and how do I use it."

The document describes **legacy mode** — that is, the machine's behavior compatible with the Amstrad CPC 6128, plus the Aleste extensions that are available in this mode. Native/protected modes, slots, MMIO, and the rest of the next-generation architecture are not covered here.

## What the Aleste 520EX is

The Aleste 520EX is a clone of the Amstrad CPC 6128, developed in 1993 by the company Patisonic in Omsk (Siberia). Only a few dozen units were produced, some as build-it-yourself kits.

The machine is compatible with the CPC 6128 at the level of software and peripherals, but has a number of extensions:

- **512 KB of RAM** instead of 128 KB. The standard amount is exactly 512 KB (32 banks of 16 KB). Theoretically the mapper allows up to 1 MB (6 bits of bank number), but machines with that amount never existed in nature.
- **64-color palette** in Aleste mode (MAPMOD=1); in CPC mode (MAPMOD=0) — 27 colors, as on the CPC.
- Non-volatile real-time clock.
- Extended keyboard matrix (11 rows instead of 10, 10 additional keys).
- Two software-controlled LEDs (CAPS, RUS).
- Printer port (8 bits) — via AY-3-8910 register 15 + PPI (strobe/Busy), not via `#EFXX` (that is the USART 8251).
- Extended expansion port with DMA support (pinout is incompletely documented, see section 11).
- Ability to run **MSX-DOS** (in addition to CP/M and AMSDOS).

## How to read this document

The sections go in order from general to specific. If you have never seen a CPC — start from the first section and go in order. If you know the CPC but not the Aleste — you can start from the section on memory and ports.

Each section is a separate file. Links below.

## Table of contents

1. [The big picture](01-overview.md) — Z80, 64 KB, pages, banks, MAPMOD, ports in general terms
2. [Memory](02-memory.md) — banks, pages, CPC banking, extended Aleste mapper, ROM
3. [Screen](03-screen.md) — modes, palette, video memory addressing, pixel and character output
4. [Sound](04-sound.md) — AY-3-8910, registers, access via PPI
5. [Magic Sound](05-magicsound.md) — sampler synthesis sound card
6. [Port reference](06-ports.md) — port table and warnings about conflicts
7. [Keyboard](07-keyboard.md) — matrix, additional keys, reading key presses
8. [Disk drive](08-disk.md) — 765 FDC, ports, reading a sector
9. [First program](09-first-program.md) — end-to-end example with comments
10. [Interrupts](10-interrupts.md) — interrupts
11. [Expansion port](11-expansion-port.md) — for expansion boards
12. [What's next](12-next-steps.md) — assembler, emulator, where to look
13. [Aleste BIOS](./bios/README.md) — base software documentation

## Translated articles

1. [Gate Array](./gate-array/index.md) — translation of an article from the Amstrad CPC Wiki
2. [Notes on video display units in the Amstrad CPC](./amstrad-cpc-crtc/index.md) — translation of an article

## What is not in this document

- Native/protected mode, slots, Wishbone, MMIO — this is the architecture of the **Aleste 520EX LX**, not of the base 520EX.
- SD card, Ethernet, SoundMagic 2, blitter, LX DMA controller — also LX.
- Full description of the BIOS and AMSDOS.
- Full description of MSX-DOS.

These are separate topics. Here — only what is needed to start in legacy mode.

## Conventions

- Addresses and ports are written in hexadecimal: `#7F00` (or `0x7F00`).
- `XX` in a port address means "any value," because decoding is partial.
- Code examples are in Z80 assembly, with comments.
- If something in the original manuals is contradictory or unclear, this is noted explicitly.