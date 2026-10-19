# INDEX.md — Complete Documentation Table of Contents

## What this is

This file is the map of all documentation for the Aleste 520 EX BIOS. If you are opening the package for the first time — start with [README.md](README.md), then move on to the driver you need.

---

## Documentation structure

### Overview

| Document               | What's inside                                    |
|------------------------|----------------------------------------------------------|
| [README.md](README.md) | What the Aleste BIOS is, memory map (vectors, work area, hooks), driver table, build, brief errata |

### Drivers

| Document                         | Driver     | Source     | Key calls                                                                                                                                                                                                             |
|----------------------------------|------------|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [01-screen.md](01-screen.md)     | Screen     | `BIOS.SCR` | `SYMBOL`, `MESSAGE`, `SET_SCRMOD`, `SET_SIZE`, `SET_MODE`, `SET_INK`, `SET_PAPER`, `SET_BORDER`, `SET_PAL`, `CUR_INIT`, `ENA_CUR`, `DIS_CUR`, `PLACE_CUR`, `ERASE_CUR`, `SET_CUR`, `GET_CUR`, `SCROLL`, `CLS`, `BEEP` |
| [02-keyboard.md](02-keyboard.md) | Keyboard   | `BIOS.DRV` | `READ_KEY`, `INPUT`, `INKEY`, `TEST_KEY`, `BREAK`, `SNSMAT`, `TST_KEYBUF`, `CLR_KEYBUF`, `SET_NORM`…`GET_SHRUS`, `SET_SCAN`…`GET_DELAY`, `CLICKON`, `CLICKOFF`                                                        |
| [03-mouse.md](03-mouse.md)       | Mouse      | `BIOS.DRV` | `MOUS_INIT`, `MOUS_ON`, `MOUS_OFF`, `GET_MOUS`, `SET_MOUS`, `SET_MLIM`, `GET_MLIM`, `SET_MSCAL`, `GET_MSCAL`                                                                                                          |
| [04-serial.md](04-serial.md)     | RS-232     | `BIOS.DRV` | `COM_INI`, `COM_OUT_ST`, `COM_OUT`, `COM_IN_ST`, `COM_IN` (the last 4 are a reconstruction)                                                                                                                           |
| [05-printer.md](05-printer.md)   | Printer    | `BIOS.DRV` | `LPTOUT`, `LPTSTT`                                                                                                                                                                                                    |
| [06-graphics.md](06-graphics.md) | Graphics   | `BIOS.GRP` | `GRAPH_INIT`, `SET_WRITE_MODE`, `PUT_PIXEL`, `GET_PIXEL`, `GR_LINE`, `HORIZ_LINE`, `VERT_LINE`, `FILL_RECTANGLE`                                                                                                      |
| [07-sprites.md](07-sprites.md)   | Sprites    | `BIOS.SPR` | `COPY_M_TO_V`, `COPY_V_TO_M`, `COPY_V_TO_V`, `DRAW_SPRITE`, `UNDRAW_SPRITE`                                                                                                                                           |

### Issues

| Document | What's inside |
|----------|-----------|
| [08-errata.md](08-errata.md) | What is missing/truncated: the tail of `BIOS.DRV` (7 RS-232 symbols), `ALEST`, `DATA`, `COLORS`, the unwired `BIOS.GRP`/`BIOS.SPR`, the simplified `SNSMAT` in `ROM.MAC`, the debug output of `MOUSE1.MAC`, the sound in `LPTOUT_3`. What **is** there and works. How to restore it. |

---

## Quick call search

### Screen

| Call         | Vector  | Document                                                     |
|--------------|---------|--------------------------------------------------------------|
| `SYMBOL`     | `L0018` | [01-screen.md](01-screen.md#symbol-l0018)                    |
| `WR_SYMBOL`  | `L0072` | [01-screen.md](01-screen.md#wr_symbol-l0072)                 |
| `MESSAGE`    | `L007B` | [01-screen.md](01-screen.md#message-l007b)                   |
| `MESSAGE1`   | `L0075` | [01-screen.md](01-screen.md#message1-l0075)                  |
| `FMESSXY`    | `L0162` | [01-screen.md](01-screen.md#fmessxy-l0162)                   |
| `SET_SCRMOD` | `L0081` | [01-screen.md](01-screen.md#set_scrmod-l0081)                |
| `GET_SCRMOD` | `L0084` | [01-screen.md](01-screen.md#get_scrmod-l0084)                |
| `SET_SIZE`   | `L0093` | [01-screen.md](01-screen.md#set_size-l0093)                  |
| `GET_SIZE`   | `L0096` | [01-screen.md](01-screen.md#get_size-l0096)                  |
| `SET_MODE`   | `L008D` | [01-screen.md](01-screen.md#set_mode-l008d)                  |
| `GET_MODE`   | `L0090` | [01-screen.md](01-screen.md#get_mode-l0090)                  |
| `SET_INK`    | `L00B1` | [01-screen.md](01-screen.md#set_ink-l00b1)                   |
| `SET_PAPER`  | `L00B7` | [01-screen.md](01-screen.md#set_paper-l00b7)                 |
| `SET_BORDER` | `L00BD` | [01-screen.md](01-screen.md#set_border-l00bd)                |
| `SET_PAL`    | `L00C6` | [01-screen.md](01-screen.md#set_pal-l00c6)                   |
| `CUR_INIT`   | `L00CC` | [01-screen.md](01-screen.md#cur_init-l00cc)                  |
| `ENA_CUR`    | `L00CF` | [01-screen.md](01-screen.md#ena_cur-dis_cur-l00cf-l00d2)     |
| `DIS_CUR`    | `L00D2` | [01-screen.md](01-screen.md#ena_cur-dis_cur-l00cf-l00d2)     |
| `SET_CUR`    | `L00DB` | [01-screen.md](01-screen.md#set_cur-get_cur-l00db-l00de)     |
| `GET_CUR`    | `L00DE` | [01-screen.md](01-screen.md#set_cur-get_cur-l00db-l00de)     |
| `PLACE_CUR`  | `L00E7` | [01-screen.md](01-screen.md#place_cur-erase_cur-l00e7-l00ea) |
| `ERASE_CUR`  | `L00EA` | [01-screen.md](01-screen.md#place_cur-erase_cur-l00e7-l00ea) |
| `SCROLL`     | `L0078` | [01-screen.md](01-screen.md#scroll-l0078)                    |
| `CLS`        | `L007E` | [01-screen.md](01-screen.md#cls-l007e)                       |
| `BEEP`       | `L00A2` | [01-screen.md](01-screen.md#beep-l00a2)                      |

### Keyboard

| Call         | Vector  | Document                                          |
|--------------|---------|---------------------------------------------------|
| `READ_KEY`   | `L00F6` | [02-keyboard.md](02-keyboard.md#read_key-l00f6)   |
| `INPUT`      | `L0010` | [02-keyboard.md](02-keyboard.md#input-l0010)      |
| `INKEY`      | `L0008` | [02-keyboard.md](02-keyboard.md#inkey-l0008)      |
| `TEST_KEY`   | `L00F9` | [02-keyboard.md](02-keyboard.md#test_key-l00f9)   |
| `BREAK`      | `L00FC` | [02-keyboard.md](02-keyboard.md#break-l00fc)      |
| `SNSMAT`     | `L014D` | [02-keyboard.md](02-keyboard.md#snsmat-l014d)     |
| `TST_KEYBUF` | `L00F0` | [02-keyboard.md](02-keyboard.md#tst_keybuf-l00f0) |
| `CLR_KEYBUF` | `L00F3` | [02-keyboard.md](02-keyboard.md#clr_keybuf-l00f3) |

### Mouse

| Call        | Vector  | Document                                                |
|-------------|---------|---------------------------------------------------------|
| `MOUS_INIT` | `L0135` | [03-mouse.md](03-mouse.md#mous_init-l0135)              |
| `MOUS_ON`   | `L0138` | [03-mouse.md](03-mouse.md#mous_on-mous_off-l0138-l013b) |
| `MOUS_OFF`  | `L013B` | [03-mouse.md](03-mouse.md#mous_on-mous_off-l0138-l013b) |
| `GET_MOUS`  | `L013E` | [03-mouse.md](03-mouse.md#get_mous-l013e)               |
| `SET_MOUS`  | `L0150` | [03-mouse.md](03-mouse.md#set_mous-l0150)               |
| `SET_MLIM`  | `L0141` | [03-mouse.md](03-mouse.md#set_mlim-l0141)               |
| `GET_MLIM`  | `L0144` | [03-mouse.md](03-mouse.md#get_mlim-l0144)               |
| `SET_MSCAL` | `L0147` | [03-mouse.md](03-mouse.md#set_mscal-l0147)              |
| `GET_MSCAL` | `L014A` | [03-mouse.md](03-mouse.md#get_mscal-l014a)              |

### RS-232

| Call         | Vector  | Document                                      |
|--------------|---------|-----------------------------------------------|
| `COM_INI`    | `L0153` | [04-serial.md](04-serial.md#com_ini-l0153)    |
| `COM_OUT_ST` | `L0156` | [04-serial.md](04-serial.md#com_out_st-l0156) |
| `COM_OUT`    | `L0159` | [04-serial.md](04-serial.md#com_out-l0159)    |
| `COM_IN_ST`  | `L015C` | [04-serial.md](04-serial.md#com_in_st-l015c)  |
| `COM_IN`     | `L015F` | [04-serial.md](04-serial.md#com_in-l015f)     |

### Printer

| Call     | Vector  | Document                                    |
|----------|---------|---------------------------------------------|
| `LPTOUT` | `L012F` | [05-printer.md](05-printer.md#lptout-l012f) |
| `LPTSTT` | `L0132` | [05-printer.md](05-printer.md#lptstt-l0132) |

### Graphics

| Call             | Document                                                       |
|------------------|----------------------------------------------------------------|
| `GRAPH_INIT`     | [06-graphics.md](06-graphics.md#graph_init)                    |
| `SET_WRITE_MODE` | [06-graphics.md](06-graphics.md#set_write_mode-get_write_mode) |
| `PUT_PIXEL`      | [06-graphics.md](06-graphics.md#put_pixel)                     |
| `GET_PIXEL`      | [06-graphics.md](06-graphics.md#get_pixel)                     |
| `GR_LINE`        | [06-graphics.md](06-graphics.md#gr_line)                       |
| `HORIZ_LINE`     | [06-graphics.md](06-graphics.md#horiz_line)                    |
| `VERT_LINE`      | [06-graphics.md](06-graphics.md#vert_line)                     |
| `FILL_RECTANGLE` | [06-graphics.md](06-graphics.md#fill_rectangle)                |

### Sprites

| Call            | Document                                     |
|-----------------|----------------------------------------------|
| `COPY_M_TO_V`   | [07-sprites.md](07-sprites.md#copy_m_to_v)   |
| `COPY_V_TO_M`   | [07-sprites.md](07-sprites.md#copy_v_to_m)   |
| `COPY_V_TO_V`   | [07-sprites.md](07-sprites.md#copy_v_to_v)   |
| `DRAW_SPRITE`   | [07-sprites.md](07-sprites.md#draw_sprite)   |
| `UNDRAW_SPRITE` | [07-sprites.md](07-sprites.md#undraw_sprite) |

---

## Memory map (summary)

| Address           | What is there               | Document                                                      |
|-------------------|-----------------------------|---------------------------------------------------------------|
| `0000H`–`0165H`   | BIOS vectors                | [README.md](README.md#1-bios-vectors-0000h0165h)              |
| `0FC00H`          | `GR` — graphics table       | [06-graphics.md](06-graphics.md#graphics-parameter-table-gr-0fc00h) |
| `0FCE2H`          | `WORKSPC` — BIOS stack      | [README.md](README.md)                                        |
| `0FD90H`–`0FDDBH` | Hooks                       | [README.md](README.md#3-hooks-0fd90h0fddbh)                   |
| `0FDF5H`          | `EXTPORT`                   | [README.md](README.md)                                        |
| `0FE05H`–`0FE16H` | Window, cursor, modes, colors | [01-screen.md](01-screen.md#driver-variables)               |
| `0FE8FH`–`0FEE4H` | Keyboard                    | [02-keyboard.md](02-keyboard.md#driver-variables)             |
| `0FEE5H`–`0FEF3H` | Mouse                       | [03-mouse.md](03-mouse.md#driver-variables)                   |
| `0FEF4H`–`0FEFEH` | Timer, screen bases         | [README.md](README.md)                                        |
| `0FF00H`–`0FF8CH` | RS-232                      | [04-serial.md](04-serial.md#driver-variables)                 |
| `0FFE0H`–`0FFFFH` | `PAGEMAP`                   | [README.md](README.md)                                        |

---

## What to do next

1. **Study the code** — start with [README.md](README.md), then [01-screen.md](01-screen.md) and [02-keyboard.md](02-keyboard.md).
2. **Build the firmware** — read [08-errata.md](08-errata.md), restore the tail of `BIOS.DRV`, find `ALEST`/`DATA`, add `INCLUDE BIOS.GRP`/`BIOS.SPR`.
3. **Use the BIOS** — each document contains Z80 assembly call examples.

---

## See also

- [README.md](README.md) — overview and memory map
- [08-errata.md](08-errata.md) — known issues