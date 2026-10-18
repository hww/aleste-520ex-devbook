# 09. What's Next

We have come a long way from the big picture to a working program. What follows is independent work. This section is a short reference: tools, documentation, topics for deeper study.

## Tools

### Assemblers

- **SjASMPlus** — popular, feature-rich, macros. For large projects.
- **Pasmo** — cross-platform, simple syntax. For small programs.
- **z80asm** — minimalist, included in many tools.
- **vasm** — powerful, many architectures.
- **WinAPE** — CPC emulator with a built-in assembler (Windows).

Start with SjASMPlus or Pasmo.

### Emulators

There may be no ready-made Aleste emulator. CPC emulators usually support Aleste extensions if configured.

- **WinAPE** — Windows, CPC + extensions.
- **CPCEC** — cross-platform.
- **Caprice32** — open source.
- **MAME** — universal, CPC driver; Aleste extensions may not be fully supported.

If the emulator does not support Aleste extensions — you can emulate only the CPC part. That is enough for debugging basic things.

### Working with DSK images

- **iDSK** — cross-platform utility (add/extract files, format).
- **CPCDiskXP** — Windows.
- **ManageDsk** — cross-platform manager.

## Documentation

### On the Aleste and CPC

- [CPCWiki](https://www.cpcwiki.eu) — the main resource. Pages
- [Gate Array](https://www.cpcwiki.eu/index.php/Gate_Array)
  [I/O Ports](https://www.cpcwiki.eu/index.php/I/O_Ports),
  [Expansions](https://www.cpcwiki.eu/index.php/Expansions).
- [Amstrad CPC User Instructions](../library/AmstradCPC6128-hypertext-en-Sinewalker.pdf) —
  official documentation.
  [Aleste 520EX](https://www.cpcwiki.eu/index.php/Aleste_520EX),
- [Soft968: The Amstrad CPC Firmware Guide](../library/The_Amstrad_CPC_Firmware_Guide.txt) —
  description of the BIOS and firmware. Useful when working with the BIOS.
- [The Amstrad CPC Memory Map](https://www.cpcalive.com/docs/amstrad_cpc_6128_memory_map.html) — memory map.
- [Understanding the Amstrad CPC Video, RAM and Gate Array Subsystem](https://bread80.com/2021/06/03/understanding-the-amstrad-cpc-video-ram-and-gate-array-subsystem/)
- [Notes on Video Display Units in Amstrad CPC](https://neuro-sys.github.io/2019/10/01/amstrad-cpc-crtc.html)

### File archive

- [Aleste Files](https://github.com/hww/Aleste520EX)

### Datasheets

- [Z80](../datasheets/z80.pdf) — processor.
- [AY-3-8910](../datasheets/generalinstrument_ay-3-8910.pdf) — sound chip.
- [AY-3-8910 Programming Manual](../datasheets/AY-3-8910-8912-Programmable-Sound-Generator-Data-Manual.pdf) —
  programmer's manual.
- [MC6845](../datasheets/HD6845S.pdf) — video chip.
- [NEC µPD765](../datasheets/uPD765A.pdf) — disk controller.
- [8255 PPI](../datasheets/m82c55a.pdf) — parallel interface.
- [8253 PIT](../datasheets/8253.PDF) — timer (basic).
- [8254 PIT](../datasheets/8254.PDF) — timer (Magic Sound).
- [8257 DMA](../datasheets/M8257.PDF) — DMA controller (Magic Sound).

## Where to dig deeper

**BIOS.** Ready-made functions: character output, keyboard reading, disk, sound. The list of functions and entry point addresses is in the original documentation. Studying the BIOS speeds up development.

**AMSDOS.** Disk OS: open/read/write/close a file. If the program works with files — use AMSDOS, don't write your own disk driver. Documentation — on CPCWiki.

**Interrupts.** In the CPC and Aleste — **50 Hz** (PAL, always). Used for music (AY updates), animation, multitasking. Synchronization — via VSYNC + HALT (see section 12).

**Memory.** The extended mapper gives 512 KB (32 banks of 16 KB). Topics: separating code and data, bank switching, saving context, RAM disk.

**Graphics.** Sprites (software only), scrolling, double buffering, effects (plasma, tunnel).

**Sound.** Trackers and players, music formats, effects (arpeggio, vibrato), envelope.

## Community

- **CPCWiki Forum** — the main forum on the CPC and Aleste.
- **Push'n'Pop** — French forum, lots of technical content.
- **Amstrad ESP** — Spanish forum.
- **IRC/Discord** — CPC channels.
- **GitHub/GitLab** — tags `amstrad`, `cpc`, `z80`, `aleste`.

## What we did not cover

- **CP/M** (BDOS.SYS) — the Aleste disk OS. Not MSX-DOS.
  If you write for CP/M — study it separately.
- **Magic Sound Board** — the board with DMA (see section 05).
- **Foton Expansion Board** — a light control board
  (a specific application; not mentioned in the BIOS sources).
- **Turbo Mode** — processor acceleration. The scheme is undocumented;
  not implemented in `BIOS.MAC`/`ROM.MAC`.
- **2 MB RAM** — expansion to 2 MB. **Not supported** by default
  (in `ROM.MAC` `LIMIT` limits it to 512 KB / 32 banks).

## Last piece of advice

Start small: a program that outputs text. Then —
sound, keyboard, disk. Add one element at a time,
test, debug. The Aleste is a rare machine; if you write
for it, you are in the minority, but it is interesting.

---

*If you find an error or want to add something — tell
the community.*
