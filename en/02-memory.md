# 02. Memory

In the first section, we discussed what banks, pages, and mappers are. Now, the specifics. How to switch banks from the code, what the difference is between CPC banking and the extended Aleste mapper, and what to do with ROM.

The section is long because the topic is central. But everything is to the point.

## Recap: Banks and Pages

Let me remind you of the terminology to avoid confusion.

**Physical memory** is the 512 KB that actually resides in the machine. It is divided into 32 banks of 16 KB each. Each bank has a number: 0–31. These numbers never change.

**Logical pages** are the four windows that the Z80 sees: page 0 (`0x0000–0x3FFF`), page 1 (`0x4000–0x7FFF`), page 2 (`0x8000–0xBFFF`), page 3 (`0xC000–0xFFFF`).

**Mapper** is the device that decides which physical bank is placed in each logical page right now.

Changing the mapper content changes what the processor sees at the corresponding address. The data in the banks themselves do not disappear; they wait to be placed in the window again.

## Two Ways to Manage Memory

Aleste has two banking modes, and they are switched by the MAPMOD flag (port `#FABF`, bit 2).

- **MAPMOD = 0** — CPC banking. Compatible with Amstrad CPC 6128.
- **MAPMOD = 1** — extended Aleste mapper. Provides access to all 512 KB and all 32 banks.

It's important to understand: this is not an "old way" and a "new way." These are two different tools for different tasks. CPC banking is needed to run old software. The extended mapper is needed to write new software that uses all of the memory.

You can switch between them on the fly, but you need to understand that switching changes the behavior of memory and the palette (see the section on the screen).

## Port #7F00: Gate Array

The memory banking in CPC is handled by the Gate Array. This chip has only four registers, all located at the same address `#7F00` and accessible only for writing.

Which register is written to is determined by the two most significant bits of the data `D[7..6]`:

| Data bit 7 | Data bit 6 | Name   | Action                     |
|------------|------------|--------|----------------------------|
| 0          | 0          | `PENR` | Palette color index        |
| 0          | 1          | `INKR` | Color for current index    |
| 1          | 0          | `RMR`  | Mode, ROM control, LEDs    |
| 1          | 1          | `MMR`  | RAM banking                |

## CPC Banking (MAPMOD = 0)

This is the scheme from Amstrad CPC 6128, designed for 128 KB of memory (8 banks), but Aleste can expand it through an additional port.

Important: in CPC banking, **all four pages are controlled**, just through different mechanisms. Pages 1–3 are controlled through the `MMR` register (format `%11BBBRRR`). Page 0 is controlled through the `RMR` register, which physically coincides with the port `#7CXX` (more on this in the section about the extended mapper). Therefore, page 0 behaves just like the others: it can be switched, but not through `MMR`, but through `RMR`.

Here is a shortened version:

### RMR Register for ROM Configuration

This register has a large functionality: it handles the graphics mode and the keyboard LEDs, but now the main thing is to understand the bits controlling ROM.

| Bits | Value | Function                                                      |
|------|-------|---------------------------------------------------------------|
| 7,6  | 1,0   | Constant selection of the RMR register                        |
| 5    | -     | CAPS LED                                                      |
| 4    | x     | RUS LED                                                       |
| 3    | x     | 1=Upper ROM area disable, 0=Upper ROM area enable             |
| 2    | x     | 1=Lower ROM area disable, 0=Lower ROM area enable             |
| 1,0  | x     | Graphics Mode selection                                       |

Bits 4 and 5 on Aleste differ from CPC. Bit 4 instead of controlling interrupts controls the RUS LED on the keyboard. While bit 5, which should always be 0 on CPC, controls the CAPS LED on Aleste.

Bits 2 and 3 simply **enable and disable** the ROM areas: bit 2 for the lower area (`0x0000–0x3FFF`), bit 3 for the upper area (`0xC000–0xFFFF`). Value 0 means ROM is enabled, 1 means disabled, and reading goes from the RAM underneath.

This is not a bank selection. *Which specific* bank of the upper ROM is placed in `0xC000–0xFFFF` is set by the `DFxxh` port (Upper ROM Bank Number). Typical sequence: first select the bank through `DFxxh`, then enable or disable the upper ROM with bit 3 of RMR.

By default, if no peripheral device is outputting ROMDIS=HIGH, BASIC is displayed in all ROM banks `00h..FFh`. On a "bare" CPC, only ROM 0 (BASIC) and ROM 7 (AMSDOS, except CPC464) are available. On Plus, the logic of port `DFxxh` is more complex and depends on bit 7.

I got it now. You're right: port `#7F00` (in the sense of "RAM configuration register") controls **all four pages**, just page 0 is "special." Below is the corrected fragment taking this into account.

### MMR Register for RAM Configuration

Port `#7F00` is the register that controls which banks are placed **in all four pages**. But it does so differently: pages 1–3 are set directly by the `RMR_CONF` field (format `%11BBBRRR`, see below), while page 0 is "special": it physically coincides with the `RMR` register, so its bank is determined by what is written to `RMR` (details in the section about the extended mapper).

The format of the written byte:

```txt
%11BBBRRR
```

Here:

- Bits 7–6 are always `11`. This is a marker that we are writing to the RAM configuration register, not to the Gate Array (they share one address, details in the next section, dedicated to the screen).
- Bits 5–3 are **RMR_BANK**, the 64 KB bank number.
- Bits 2–0 are **RMR_CONF**, the memory configuration number.

The configuration changes all pages according to a certain pattern, which, however, is well thought out. At the same time, the pattern uses the **RMR_BANK** bits as a shift `b` with a step of 64 KB.
Below is the table of dependency of the 16KB page number on **RMR_CONF** and **RMR_BANK**, where `b` is one of the 64KB banks selected by the bits **RMR_BANK**. Page 3 means the last 16KB in the 64KB computer memory, and `b[3]` means the last 16KB page in one selected 64KB bank of memory expansion.

| RMR_CONF | 0000-3FFF | 4000-7FFF | 8000-BFFF | C000-FFFF |
|----------|-----------|-----------|-----------|-----------|
| 0        | 0         | 1         | 2         | 3         |
| 1        | 0         | 1         | 2         | b[3]      |
| 2        | b[0]      | b[1]      | b[2]      | b[3]      |
| 3        | 0         | 3         | 2         | b[3]      |
| 4        | 0         | b[0]      | 2         | 3         |
| 5        | 0         | b[1]      | 2         | 3         |
| 6        | 0         | b[2]      | 2         | 3         |
| 7        | 0         | b[3]      | 2         | 3         |

As can be seen, there are some patterns:

- **RMR_CONF = 0** — it is just a 64KB computer.
- **RMR_CONF = 1** — connects the last 16KB of the selected bank to `0xC000–0xFFFF`.
- **RMR_CONF = 2** — connects all pages of the selected bank.
- **RMR_CONF = 3** — connects the last 16KB of the selected bank to `0xC000–0xFFFF`, but page 3 is replaced by page 3 of the base memory.
- **RMR_CONF = 4..7** — connect one of the 16KB pages of the bank to the space `0x4000–0x7FFF`.

### Port #DF00: Upper Bank ROM

When the upper page `0xC000–0xFFFF` is connected to ROM (bit 3 of the `RMR` register = 0), the port `#DF00` controls which specific ROM page is connected in this area.

Format of the written byte:

```txt
%BBBBBBBB
```

The diagram below shows how the registers control the connection of ROM.

![Control of ROM in Amstrad CPC](../images/Aleste%20ROM%20MAP.webp)

### Example: Set ROM 5 in the upper area (`0xC000–0xFFFF`)

Suppose we want the addresses `0xC000–0xFFFF` to show the physical bank 5.

```txt
; Enable the upper ROM and disable the lower one.
; RMR format: %10xxxxxx. Bit 3 = 0 → upper ROM is enabled.
; Bit 2 = 1 → lower ROM is disabled.
LD A, %10000100
OUT (#7F00), A

; Now select the number of the upper ROM bank.
LD A, 5            ; bank 5
OUT (#DF00), A
```

After this, the addresses `0xC000–0xFFFF` will show bank 5.

### Most Common ROM Page Numbers

In Aleste 520EX, there is a built-in ROM bank — **BOOTMENU** (number `03h`). It contains the OS loader and the system settings menu, but does not contain system code. BASIC and AMSDOS in Aleste are fully identical (1:1) to the corresponding banks in CPC6128, while BIOS (lower ROM bank) is almost the same as in CPC6128 — only the startup message and printer handling are changed.

The table below lists the known ROM page numbers where the Aleste BOOTMENU is included.

```txt
 00h       BASIC (or AMSDOS — depends on LK1 on the DDI-1 board.
           On CPC, if AMSDOS sees itself displayed in bank 0,
           it automatically loads and runs the boot sector from disk A after being turned on.
           On Plus, there is a bug in the system cartridge that causes the machine to crash instead.)
 03h       Aleste BOOTMENU (bytes in C000h..FFFFh in the 64K EPROM Aleste)
 07h       AMSDOS (or BASIC — depends on LK1 on the DDI-1 board)
 00h..07h  Boot ROMs on CPC 464/664/6128 (KL_ROM_WALK)
 08h..0Fh  Boot ROMs on CPC 664/6128 (KL_ROM_WALK)
 10h..FFh  Non-boot ROMs (or secondary boot ROM banks)
 FCh..FFh  Can be used, but they are not accessible by BIOS functions
 FFh       BASIC (or ROM with similar ID; for rough determination
           of the 128K RAM volume in CP/M+)
 FFh       BASIC (or ROM with similar ID; for determining key scanning
           in AMSDOS+)
```

## Advanced Aleste Mapper (MAPMOD = 1)

When MAPMOD = 1, another mechanism comes into play. It is simpler and more powerful: for each logical page, there is a separate port. But the lowest one, which controls page 0, is physically the **RMR** register. This means that the content of **RMR** and **MAP0** is the same and changing **MAPMOD** does not change it, but the effect of this content is different.

When **MAPMOD = 0**, writing to **any** of the ports `#7CXX–#7FXX` actually writes to **RMR**. So `#7CXX`, `#7DXX`, `#7EXX`, and `#7FXX` in this mode are the same register RMR, just at different addresses. And when **MAPMOD = 1**, each of these ports becomes a separate register MAP0–MAP3.

| Port    | Page     | Name  | Addresses        |
|---------|----------|-------|------------------|
| `#7CXX` | Page 0   | MAP0  | 0x0000–0x3FFF    |
| `#7DXX` | Page 1   | MAP1  | 0x4000–0x7FFF    |
| `#7EXX` | Page 2   | MAP2  | 0x8000–0xBFFF    |
| `#7FXX` | Page 3   | MAP3  | 0xC000–0xFFFF    |

Write the bank number to the port — the bank is inserted into the corresponding page. That's it.

Full byte format:

```txt
%11BBBBBB
```

Where `BBBBBB` is the bank number (0–31, because there are only 32 banks; values 32–63 are reserved or unused).

Example: Set bank 10 in page 2.

```txt
LD A, %11001010    ; bits 6,7 = 11, bank number = 001010 = 10
OUT (#7E00), A     ; page 2
```

The diagram below shows how the mapper registers control the connection of ROM.

![Control of ROM in Amstrad CPC](../images/Aleste%20RAM%20MAP.webp)

### Reading from the Mapper

Like the Gate Array registers, the mapper is only accessible for writing. The software should save the mapper content in memory to effectively manage it.

## Choose CPC-Banking or Advanced Mapper

The practical rule is simple.

**Write new software that uses all Aleste memory** — enable MAPMOD = 1 and work through `#7CXX–#7FXX`. This is simpler, clearer, and gives full access to 512 KB.

**Run old CPC-software that manages memory itself** — leave MAPMOD = 0. The program will write to `#7F00` and `#DF00` as expected. Just don't interfere.

**Write something that should work in both places** — you will need to support both modes. Usually, this is not needed; it is easier to choose one and stick to it.

## Maximum Allowed Memory Volume for Aleste 520EX


The bank number in the extended mapper occupies 5 bits (bits 5–0 in byte `%11BBBBBB`), which addresses **32 banks of 16 KB = 512 KB**. This is the default Aleste 520EX volume. Further expansion to 1 MB would require 6 bits for the bank number (64 banks), but this is not provided in the current architecture.

## Important Warning: MAPMOD Rearranges Memory Blocks

There's a subtlety that manuals barely mention, but it's crucial.

Switching MAPMOD is not just a flag change. It involves **rearranging address lines**: A14 and A11 swap places. Additionally, banking is switched. Each of these elements affects the program's functionality.

### Switching Banking

When MAPMOD is enabled, the mapper controls memory, and when disabled, the CPC memory manager does. This results in changes to the displayed pages. Thus, immediately after an `OUT` command, the memory page from which the code is executed may change, causing the program to crash.

### Address Line Rearrangement

What this means. If the code that performs the MAPMOD switch resides in an area dependent on lines A14 and A11— which swap places—the processor will go to the wrong place after the switch. The program will crash or behave unpredictably.

### Solution

Therefore, BIOS performs the mode switch itself, from ROM. If you need to switch MAPMOD in your program, do it via a BIOS call or place the switch code in ROM. Additionally, in the basic Aleste paradigm, the computer should boot in one of two modes and remain in that mode until reboot.

## Next

We've covered memory. The next section is [about the screen: modes, palette, how video memory is addressed, and how to output the first pixel.](./03-screen.md)