; =============================================================================
; MAGIC SOUND — STM player for ALESTE MC 520 EX
; =============================================================================
; Build: sjasmplus --raw=magic.com magic.asm
; 
; This is a fully annotated disassembly of the Magic Sound player.
; It is 100% byte-identical to the original mag.com.
; =============================================================================

; =============================================================================
; CONSTANTS
; =============================================================================

; --- Magic Sound board ports ---
DMA_A       EQU     0F8D0H          ; 8237 DMA base address, channel A
DMA_B       EQU     0F8D2H          ; channel B
DMA_C       EQU     0F8D4H          ; channel C
DMA_D       EQU     0F8D6H          ; channel D
LEN_A       EQU     DMA_A+1          ; 8237 count register, channel A
LEN_B       EQU     DMA_B+1
LEN_C       EQU     DMA_C+1
LEN_D       EQU     DMA_D+1
DMACOM      EQU     0F8D8H          ; 8237 command/status
DMAMOD      EQU     0F8DBH          ; 8237 mode register
DMARES      EQU     0F8DDH          ; 8237 reset (master clear)
DMAMASK     EQU     0F8DAH          ; 8237 single-channel mask
TIM_A       EQU     0F9D8H          ; 8254 #1 counter 0 (channel A)
TIM_B       EQU     0F9D9H          ; 8254 #1 counter 1 (channel B)
TIM_C       EQU     0F9DAH          ; 8254 #1 counter 2 (channel C)
TIM_D       EQU     0F9D4H          ; 8254 #2 counter 0 (channel D)
TIM_E       EQU     0F9D5H          ; 8254 #2 counter 1 (aux/DAC)
TIMUP0      EQU     0F9DBH          ; 8254 #1 control register
TIMUP1      EQU     0F9D7H          ; 8254 #2 control register
VOL_A       EQU     0FAD0H          ; volume register, channel A
VOL_B       EQU     0FAD1H          ; channel B
VOL_C       EQU     0FAD2H          ; channel C
VOL_D       EQU     0FAD3H          ; channel D
DMAP_A      EQU     0FBD0H          ; memory-page mapper, channel A
DMAP_B      EQU     0FBD4H          ; channel B
DMAP_C      EQU     0FBD8H          ; channel C
DMAP_D      EQU     0FBDCH          ; channel D

; --- Memory addresses ---
DATA        EQU     2000H           ; STM header / sample data base
INST        EQU     2030H           ; instrument table (32 bytes per entry)
ORDER       EQU     2410H           ; order list
I_DIV       EQU     2490H           ; per-instrument divisor table (12 words each)
T_VIBRATO   EQU     2D00H           ; vibrato waveform (runtime copy)
TEMP_CONT   EQU     2F80H           ; tick counter (row timing)
TEMP_PE     EQU     2F81H           ; ticks per row
F_N_PAT     EQU     2F82H           ; "advance to next order" flag
NEXT_ORD    EQU     2F84H           ; pointer to the next order byte
SEK_ORD     EQU     2F86H           ; pointer to the current order byte
NUM_PART    EQU     2F88H           ; current pattern number
VOL_1234    EQU     2F8CH           ; global volume
SOUND_ON    EQU     2F8EH           ; 0 = paused, 1 = playing
F_PRINT     EQU     2F90H           ; 0 = play, 1 = debug print
F_TEMP      EQU     2F92H           ; "new row just started" flag
STAR_S      EQU     2F94H           ; scroll position, top marquee
STAR_D      EQU     2F96H           ; scroll position, bottom marquee
STAR_M      EQU     2F98H           ; marquee bit-shift mask
D_POINT     EQU     2F9AH           ; pointer into the marquee text
D_POINT_1   EQU     2F9CH
D_POINT_2   EQU     2F9EH
S_MASK      EQU     2FA0H           ; current XOR mask for marquee
D_POINT2    EQU     2FA2H           ; second copy of marquee text pointer

; --- Per-channel state block bases ---
SEG_A       EQU     3078H           ; channel A state block
SEG_B       EQU     307AH           ; channel B
SEG_C       EQU     307CH           ; channel C
SEG_D       EQU     307EH           ; channel D

; --- Offsets within a channel state block ---
PAT_POINT   EQU     0-78H           ; row counter within the pattern
ADR_PAT     EQU     0-70H           ; pointer to the current row (16-bit)
SNG_DIV     EQU     0-68H           ; current timer divisor (16-bit)
SNG_VOL     EQU     0-60H           ; current volume
F_START     EQU     0-58H           ; "start DMA" flag
F_VOL       EQU     0-50H           ; "update volume" flag
F_DIV       EQU     0-48H           ; "reprogram timer" flag
F_LOOP      EQU     0-40H           ; "loop sample" flag
F_RESTART   EQU     0-38H           ; "reprogram DMA on NMI" flag
F_CH_ON     EQU     0-30H           ; "force channel off" flag
SEK_DIV     EQU     0-28H           ; saved divisor (portamento target)
SEK_VOL     EQU     0-20H           ; saved volume (tremor)
SEK_SAMP    EQU     0-18H           ; pointer to instrument header (16-bit)
TIM_TREM    EQU     0-10H           ; tremor timer
ON_OFF      EQU     0-08H           ; tremor on/off state
NMI_START   EQU     0               ; next sample start (16-bit)
NMI_LENGHT  EQU     8H              ; next sample length (16-bit)
START_0     EQU     10H             ; first half: address
START_1     EQU     18H             ; second half: address
LENGHT_0    EQU     20H             ; first half: length
LENGHT_1    EQU     28H             ; second half: length
S_MAP       EQU     30H             ; DMA memory page
N_COMAND    EQU     38H             ; effect command (0..15)
N_VOLUME    EQU     40H             ; volume (0x41 = "instrument default")
N_NOTE      EQU     48H             ; note byte (0xFF = none, 0xFE = key off)
N_SAMPLE    EQU     50H             ; instrument number
N_PARAM     EQU     58H             ; effect parameter
VIB_POINT   EQU     60H             ; vibrato phase
F_ARP       EQU     68H             ; arpeggio active flag
TIM_ARP     EQU     70H             ; arpeggio timer
PIK_VOL     EQU     78H             ; peak volume (VU-meter)

; --- VU-meter peak registers ---
PIK_A       EQU     30F0H
PIK_B       EQU     30F2H
PIK_C       EQU     30F4H
PIK_D       EQU     30F6H

; =============================================================================
                org     100h

; =============== S U B R O U T I N E =======================================

entry:
                jp      start
; ---------------------------------------------------------------------------

start:
                ld      sp, (6)                 ; restore SP from page-zero slot 6
                call    int_ptr                 ; init 8254 timers + 8237 DMA
                call    clear                   ; zero out the work area
                call    load_stm_file           ; open and parse the .STM file
                call    restore                 ; copy init tables, set flags
                call    init_div                ; precompute per-instrument divisors
                call    init_screen             ; init screen mode and VU-meter
                call    sub_2E0                 ; init marquee positions
                ld      hl, demo_text
                ld      (D_POINT2), hl          ; start of the marquee text
                call    set_interrupt_hook      ; hook INT 38h and NMI

; =========================== Player loop =====================================
;
; The main loop runs at whatever speed the CPU can manage; actual timing is
; driven by the 50 Hz INT 38h handler (PRG_INT).
;
; Two modes:
;   F_PRINT = 1  -> debug print: dump the four current notes to the screen
;   F_PRINT = 0  -> normal play: scroll the marquee, update the VU-meters
;
; Key handling:
;   20h (space)  -> toggle F_PRINT
;   0Dh (CR)     -> force "advance to next order" on the next tick
;   anything else-> stop playback, restore BIOS vectors, return to CP/M
; -----------------------------------------------------------------------------

loop:
                ei
                ld      a, (F_PRINT)
                or      a
                jr      z, update_player
                ; --- Debug-print mode: dump all four channels' current notes ---
                ld      a, (F_TEMP)
                or      a
                jp      z, loc_1ED                 ; no new row yet
                sub     a
                ld      (F_TEMP), a              ; consume the "new row" flag
                ld      ix, SEG_A
                call    print_curent_note
                ld      ix, SEG_B
                call    print_curent_note
                ld      ix, SEG_C
                call    print_curent_note
                ld      ix, SEG_D
                call    print_curent_note
                call    print_new_line
                jp      loc_1ED
; ---------------------------------------------------------------------------

update_player:
                ; --- Normal play mode: advance marquee, redraw VU-meters ---
                ld      a, (F_TEMP)
                or      a
                jp      z, loc_182                 ; no new row yet
                sub     a
                ld      (F_TEMP), a
                ld      hl, (D_POINT2)
                ld      a, (hl)
                inc     hl
                or      a
                jr      nz, loc_170
                ld      hl, 11BBh                  ; wrap to start of text
                ld      a, (hl)

loc_170:
                ld      (D_POINT2), hl
                ld      e, a
                ld      a, 2                       ; Graphics mode 2
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch                        ; BIOS: output character
                ei

loc_182:
                call    draw_vu_meter
                call    star_enable
                jp      loc_1ED
; End of function entry

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; LINE / draw_vu_meter
;   Draws four horizontal VU-meter bars at fixed VRAM addresses.
;
;   Each bar is drawn vertically across 8 raster lines (stride 0x800).
;   The bar is 16 cells wide; filled cells use color 0xFC, empty use 0x00.
;
; Input:  A  = peak volume (0..63)
;         HL = VRAM address of the bar's left edge
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
draw_vu_meter:
                ld      a, (PIK_A)
                ld      hl, 95F4h
                call    draw_line
                ld      a, (PIK_B)
                ld      hl, 9644h
                call    draw_line
                ld      a, (PIK_C)
                ld      hl, 9694h
                call    draw_line
                ld      a, (PIK_D)
                ld      hl, 96E4h
                call    draw_line
                ret
; End of function draw_vu_meter

; =============== S U B R O U T I N E =======================================

draw_line:
                ld      bc, 7EC0h                  ; Gate Array: select palette index
                out     (c), c
                rrca
                rrca
                and     0Fh
                ld      b, a
                inc     b
                ld      a, 0Ch                     ; VU-meter bar color
                ld      c, 0CCh
                ld      de, 800h

loc_1C2:
                ld      (hl), c
                add     hl, de
                ld      (hl), c
                add     hl, de
                ld      (hl), c
                or      a
                sbc     hl, de
                sbc     hl, de
                inc     hl
                dec     a
                jr      nz, loc_1D4
                ld      c, 0C0h
                ld      a, 5

loc_1D4:
                djnz    loc_1C2
                ld      b, a

loc_1D7:
                ld      (hl), 0
                add     hl, de
                ld      (hl), 0
                add     hl, de
                ld      (hl), 0
                or      a
                sbc     hl, de
                sbc     hl, de
                inc     hl
                djnz    loc_1D7
                ld      bc, 7EC6h                  ; Gate Array: restore normal mode
                out     (c), c
                ret
; End of function draw_line

; ---------------------------------------------------------------------------

loc_1ED:
                ld      ix, 8
                ld      iy, 800h
                call    1Ch
                or      a
                jp      z, loop
                jr      loc_227
; ---------------------------------------------------------------------------
                cp      20h                        ; space
                jr      nz, loc_227
                ld      a, (F_PRINT)
                cpl
                ld      (F_PRINT), a
                or      a
                jr      z, loc_21E
                sub     a
                ld      bc, 300h
                ld      ix, 81h
                ld      iy, 800h
                call    1Ch
                jp      loop
; ---------------------------------------------------------------------------

loc_21E:
                call    init_screen
                call    sub_2E0
                jp      loop
; ---------------------------------------------------------------------------

loc_227:
                cp      0Dh                        ; CR
                jr      nz, loc_233
                ld      a, 1
                ld      (F_N_PAT), a               ; force "advance to next order"
                jp      loop
; ---------------------------------------------------------------------------

loc_233:
                sub     a
                ld      (SOUND_ON), a              ; pause the player
                call    int_ptr                    ; silence all DMA channels
                call    remove_interrupt_hook      ; restore BIOS INT/NMI vectors
                ld      h, 40h
                ld      a, 5
                call    24h                        ; MSX-DOS: 0024h hook
                ld      a, 0
                ld      bc, 300h
                ld      ix, 81h
                ld      iy, 800h
                call    1Ch
                rst     0                          ; warm boot back to MSX-DOS

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; STAR_ENABLE
;   Animate the two scrolling marquees. Each call advances the marquee by
;   one pixel (by shifting the bit mask) and redraws it via SS_3 / SS_31.
;
;   STAR_ON  operates on the top marquee (STAR_S, XOR with STAR_M)
;   STAR_ON1 operates on the bottom marquee (STAR_D, XOR with 0x70)
;
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
star_enable:
                ld      hl, (STAR_M)
                push    hl
                ld      a, (D_POINT_2)
                ld      (S_MASK), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h                       ; keep within 0B800h..0BFFFh
                ld      h, a
                ld      (STAR_M), hl
                ld      de, 180h
                call    set_starts
                pop     hl
                ld      de, 180h
                call    set_starts
                ld      hl, (STAR_D)
                push    hl
                ld      a, (D_POINT_1)
                push    af
                rrca
                rrca
                ld      (S_MASK), a
                ld      (D_POINT_1), a
                jr      nc, loc_29A
                ld      a, 0Ch                     ; marquee shift mask update
                ld      (S_MASK), a
                ld      (D_POINT_1), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      (STAR_D), hl

loc_29A:
                ld      de, 140h
                call    set_starts
                pop     af
                ld      (S_MASK), a
                pop     hl
                ld      de, 140h
                call    set_starts
                ld      hl, (STAR_S)
                push    hl
                ld      a, (D_POINT)
                push    af
                rrca
                ld      (S_MASK), a
                ld      (D_POINT), a
                jr      nc, loc_2CE
                ld      a, 8                       ; marquee shift mask update
                ld      (S_MASK), a
                ld      (D_POINT), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      (STAR_S), hl

loc_2CE:
                ld      de, 100h
                call    set_starts
                pop     af
                ld      (S_MASK), a
                pop     hl
                ld      de, 100h
                call    set_starts
                ret
; End of function star_enable

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; SET_STAR
;   Initialise the top marquee: position = HL, mask = 1.
; -----------------------------------------------------------------------------
sub_2E0:
                ld      hl, 0B800h
                ld      (STAR_S), hl
                ld      (STAR_D), hl
                ld      (STAR_M), hl
                ld      a, 8
                ld      (D_POINT), a
                ld      a, 0Ch
                ld      (D_POINT_1), a
                ld      a, 0Eh
                ld      (D_POINT_2), a
                ld      a, (D_POINT)
                ld      (S_MASK), a
                ld      hl, (STAR_S)
                ld      de, 100h
                call    set_starts
                ld      a, (D_POINT_1)
                ld      (S_MASK), a
                ld      hl, (STAR_D)
                ld      de, 140h
                call    set_starts
                ld      a, (D_POINT_2)
                ld      (S_MASK), a
                ld      hl, (STAR_M)
                ld      de, 180h
                call    set_starts
                ret
; End of function sub_2E0

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; SS_3
;   Draw the top marquee at (STAR_S) with the current STAR_M mask.
;   The marquee is 30 rows tall, 30 characters wide. Each row is XORed
;   with STAR_M at (HL) and its mirror address (HL XOR 0FFFFh).
;
; Input:  HL = start address (0B800h + row*0x??)
;         STAR_M = XOR mask (0..15)
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
set_starts:
                ld      bc, 7EC0h
                out     (c), c
                ld      b, 30h

loc_330:
                ld      a, (de)
                and     1Fh
                add     a, 20h
                ld      c, a
                ld      a, b
                ld      b, 0
                add     hl, bc
                ld      b, a
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      a, (S_MASK)
                xor     (hl)
                ld      (hl), a
                inc     de
                djnz    loc_330
                ld      bc, 7EC6h
                out     (c), c
                ret
; End of function set_starts

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; CLEAR
;   Zeroes the work area from DATA (2000h) up to 4000h.
;   This covers the STM header, instrument table, order list, divisor table,
;   and all per-channel state. Must run before LOAD and RESTORE.
; -----------------------------------------------------------------------------
clear:
                di
                ld      hl, DATA
                ld      de, DATA+1
                ld      bc, 4000H-DATA
                ld      (hl), 0
                ldir
                ret
; End of function clear

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; RESTORE
;   Copy initialisation tables into the work area and set up playback state.
; -----------------------------------------------------------------------------
restore:
                ld      a, (DATA+32)               ; tempo byte from STM header
                cp      10h
                jr      nc, loc_367
                ld      a, 10h                     ; clamp tempo to >= 16

loc_367:
                srl     a
                srl     a
                srl     a
                srl     a                          ; A = tempo / 16 = ticks per row
                ld      (TEMP_CONT), a
                ld      (TEMP_PE), a
                ld      hl, vibrato_table
                ld      de, T_VIBRATO
                ld      bc, 200h                   ; 512 bytes = 256 words
                ldir                               ; copy vibrato waveform
                ld      a, 1
                ld      (F_N_PAT), a               ; force order advance on first tick
                ld      hl, ORDER
                ld      (NEXT_ORD), hl             ; start at the first order
                ld      a, (DATA+34)               ; global volume from STM header
                ld      (VOL_1234), a
                ld      a, 1
                ld      (SOUND_ON), a              ; unpause
                ret
; End of function restore

; ---------------------------------------------------------------------------
; START OF CHANNEL SETUP BLOCK (A, B, C, D)
;
; This block programs one DMA channel from its state block.
; It is called once per tick (50 Hz) from the interrupt handler.
;
; C equivalent (conceptually):
;
;   void ma_start(chan_t *c, int stop, int dma, int tim,
;                 int dst, uint8_t bmod, int pvol, int dmap) {
;       if (c->force_off) {                // F_CH_ON
;           out(DMAMASK, stop);
;           out(pvol, 0x40);               // silence
;           goto done;
;       }
;       if (c->start) {                    // F_START
;           out(DMAMASK, stop);
;           c->restart = c->loop;          // F_RESTART = F_LOOP
;           if (c->loop) {
;               c->nmi_start  = c->start_1;
;               c->nmi_length = c->length_1;
;           }
;           out(dma,   c->start_0);        // 8237 base address
;           out(dma+1, c->length_0);       // 8237 count
;       }
;       if (c->div) {                      // F_DIV
;           out(tim, c->sng_div);          // 8254 divisor
;       }
;       if (c->vol) {                      // F_VOL
;           uint8_t v = c->sng_vol;
;           if (v == 0 || v == 1) v = 0x40; // special "max" value
;           out(pvol, v);
;           v &= 0x3F;
;           if (v > c->peak) c->peak = v;  // PIK_VOL for the VU-meter
;       }
;       if (c->start) {
;           // 4-byte page mapper, inverted and decrementing
;           uint8_t p = ~c->s_map;
;           out(dmap+0, p);
;           out(dmap+1, p-1);
;           out(dmap+2, p-2);
;           out(dmap+3, p-3);
;           out(DMAMOD, bmod);             // 48h/49h/4Ah/4Bh = single, inc, read
;           out(DMAMASK, dst);             // unmask this channel -> start
;       }
;   done:
;       c->start = c->div = c->vol = c->loop = c->force_off = 0;
;   }
; ---------------------------------------------------------------------------

; --- Channel A ---
                ld      a, (SEG_A+F_CH_ON)
                or      a
                jr      z, loc_3AC
                ld      a, 4
                ld      bc, DMAMASK
                ld      bc, VOL_A
                ld      a, 0
                out     (c), a
                jp      loc_440
; ---------------------------------------------------------------------------

loc_3AC:
                ld      a, (SEG_A+F_START)
                or      a
                jr      z, loc_3E0
                ld      a, 4
                ld      bc, DMAMASK
                out     (c), a
                ld      a, (SEG_A+F_LOOP)
                ld      (SEG_A+F_RESTART), a
                or      a
                jr      z, loc_3CE
                ld      hl, (SEG_A+START_1)
                ld      (SEG_A), hl                ; NMI_START
                ld      hl, (SEG_A+LENGHT_1)
                ld      (SEG_A+NMI_LENGHT), hl

loc_3CE:
                ld      bc, DMA_A
                ld      hl, (SEG_A+START_0)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_A+LENGHT_0)
                out     (c), l
                out     (c), h

loc_3E0:
                ld      a, (SEG_A+F_DIV)
                or      a
                jr      z, loc_3F0
                ld      bc, TIM_A
                ld      hl, (SEG_A+SNG_DIV)
                out     (c), l
                out     (c), h

loc_3F0:
                ld      a, (SEG_A+F_VOL)
                or      a
                jr      z, loc_417
                ld      a, (SEG_A+SNG_VOL)
                sub     1
                jr      z, loc_3FF
                jr      nc, loc_401

loc_3FF:
                ld      a, 0

loc_401:
                ld      bc, VOL_A
                sla     a
                sla     a
                out     (c), a
                and     3Fh
                ld      l, a
                ld      a, (PIK_A)
                cp      l
                jr      nc, loc_417
                ld      a, l
                ld      (PIK_A), a

loc_417:
                ld      a, (SEG_A+F_START)
                or      a
                jr      z, loc_440
                ld      bc, DMAP_A
                ld      a, (SEG_A+S_MAP)
                cpl
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                ld      bc, DMAMOD
                ld      a, 48h                     ; 8237 mode: single, inc, read (ch A)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 0
                out     (c), a

loc_440:
                sub     a
                ld      (SEG_A+F_START), a
                ld      (SEG_A+F_DIV), a
                ld      (SEG_A+F_VOL), a
                ld      (SEG_A+F_LOOP), a
                ld      (SEG_A+F_CH_ON), a

; --- Channel B ---
                ld      a, (SEG_B+F_CH_ON)
                or      a
                jr      z, loc_465
                ld      a, 5
                ld      bc, DMAMASK
                ld      bc, VOL_B
                ld      a, 0
                out     (c), a
                jp      loc_4F9
; ---------------------------------------------------------------------------

loc_465:
                ld      a, (SEG_B+F_START)
                or      a
                jr      z, loc_499
                ld      a, 5
                ld      bc, DMAMASK
                out     (c), a
                ld      a, (SEG_B+F_LOOP)
                ld      (SEG_B+F_RESTART), a
                or      a
                jr      z, loc_487
                ld      hl, (SEG_B+START_1)
                ld      (SEG_B), hl
                ld      hl, (SEG_B+LENGHT_1)
                ld      (SEG_B+NMI_LENGHT), hl

loc_487:
                ld      bc, DMA_B
                ld      hl, (SEG_B+START_0)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_B+LENGHT_0)
                out     (c), l
                out     (c), h

loc_499:
                ld      a, (SEG_B+F_DIV)
                or      a
                jr      z, loc_4A9
                ld      bc, TIM_B
                ld      hl, (SEG_B+SNG_DIV)
                out     (c), l
                out     (c), h

loc_4A9:
                ld      a, (SEG_B+F_VOL)
                or      a
                jr      z, loc_4D0
                ld      a, (SEG_B+SNG_VOL)
                sub     1
                jr      z, loc_4B8
                jr      nc, loc_4BA

loc_4B8:
                ld      a, 0

loc_4BA:
                ld      bc, VOL_B
                sla     a
                sla     a
                out     (c), a
                and     3Fh
                ld      l, a
                ld      a, (PIK_B)
                cp      l
                jr      nc, loc_4D0
                ld      a, l
                ld      (PIK_B), a

loc_4D0:
                ld      a, (SEG_B+F_START)
                or      a
                jr      z, loc_4F9
                ld      bc, DMAP_B
                ld      a, (SEG_B+S_MAP)
                cpl
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                ld      bc, DMAMOD
                ld      a, 49h                     ; 8237 mode: single, inc, read (ch B)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 1
                out     (c), a

loc_4F9:
                sub     a
                ld      (SEG_B+F_START), a
                ld      (SEG_B+F_DIV), a
                ld      (SEG_B+F_VOL), a
                ld      (SEG_B+F_LOOP), a
                ld      (SEG_B+F_CH_ON), a

; --- Channel C ---
                ld      a, (SEG_C+F_CH_ON)
                or      a
                jr      z, loc_51E
                ld      a, 6
                ld      bc, DMAMASK
                ld      bc, VOL_C
                ld      a, 0
                out     (c), a
                jp      loc_5B2
; ---------------------------------------------------------------------------

loc_51E:
                ld      a, (SEG_C+F_START)
                or      a
                jr      z, loc_552
                ld      a, 6
                ld      bc, DMAMASK
                out     (c), a
                ld      a, (SEG_C+F_LOOP)
                ld      (SEG_C+F_RESTART), a
                or      a
                jr      z, loc_540
                ld      hl, (SEG_C+START_1)
                ld      (SEG_C), hl
                ld      hl, (SEG_C+LENGHT_1)
                ld      (SEG_C+NMI_LENGHT), hl

loc_540:
                ld      bc, DMA_C
                ld      hl, (SEG_C+START_0)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_C+LENGHT_0)
                out     (c), l
                out     (c), h

loc_552:
                ld      a, (SEG_C+F_DIV)
                or      a
                jr      z, loc_562
                ld      bc, TIM_C
                ld      hl, (SEG_C+SNG_DIV)
                out     (c), l
                out     (c), h

loc_562:
                ld      a, (SEG_C+F_VOL)
                or      a
                jr      z, loc_589
                ld      a, (SEG_C+SNG_VOL)
                sub     1
                jr      z, loc_571
                jr      nc, loc_573

loc_571:
                ld      a, 0

loc_573:
                ld      bc, VOL_C
                sla     a
                sla     a
                out     (c), a
                and     3Fh
                ld      l, a
                ld      a, (PIK_C)
                cp      l
                jr      nc, loc_589
                ld      a, l
                ld      (PIK_C), a

loc_589:
                ld      a, (SEG_C+F_START)
                or      a
                jr      z, loc_5B2
                ld      bc, DMAP_C
                ld      a, (SEG_C+S_MAP)
                cpl
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                ld      bc, DMAMOD
                ld      a, 4Ah                     ; 8237 mode: single, inc, read (ch C)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 2
                out     (c), a

loc_5B2:
                sub     a
                ld      (SEG_C+F_START), a
                ld      (SEG_C+F_DIV), a
                ld      (SEG_C+F_VOL), a
                ld      (SEG_C+F_LOOP), a
                ld      (SEG_C+F_CH_ON), a

; --- Channel D ---
                ld      a, (SEG_D+F_CH_ON)
                or      a
                jr      z, loc_5D7
                ld      a, 7
                ld      bc, DMAMASK
                ld      bc, VOL_D
                ld      a, 0
                out     (c), a
                jp      loc_66B
; ---------------------------------------------------------------------------

loc_5D7:
                ld      a, (SEG_D+F_START)
                or      a
                jr      z, loc_60B
                ld      a, 7
                ld      bc, DMAMASK
                out     (c), a
                ld      a, (SEG_D+F_LOOP)
                ld      (SEG_D+F_RESTART), a
                or      a
                jr      z, loc_5F9
                ld      hl, (SEG_D+START_1)
                ld      (SEG_D), hl
                ld      hl, (SEG_D+LENGHT_1)
                ld      (SEG_D+NMI_LENGHT), hl

loc_5F9:
                ld      bc, DMA_D
                ld      hl, (SEG_D+START_0)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_D+LENGHT_0)
                out     (c), l
                out     (c), h

loc_60B:
                ld      a, (SEG_D+F_DIV)
                or      a
                jr      z, loc_61B
                ld      bc, TIM_D
                ld      hl, (SEG_D+SNG_DIV)
                out     (c), l
                out     (c), h

loc_61B:
                ld      a, (SEG_D+F_VOL)
                or      a
                jr      z, loc_642
                ld      a, (SEG_D+SNG_VOL)
                sub     1
                jr      z, loc_62A
                jr      nc, loc_62C

loc_62A:
                ld      a, 0

loc_62C:
                ld      bc, VOL_D
                sla     a
                sla     a
                out     (c), a
                and     3Fh
                ld      l, a
                ld      a, (PIK_D)
                cp      l
                jr      nc, loc_642
                ld      a, l
                ld      (PIK_D), a

loc_642:
                ld      a, (SEG_D+F_START)
                or      a
                jr      z, loc_66B
                ld      bc, DMAP_D
                ld      a, (SEG_D+S_MAP)
                cpl
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                inc     c
                dec     a
                out     (c), a
                ld      bc, DMAMOD
                ld      a, 4Bh                     ; 8237 mode: single, inc, read (ch D)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 3
                out     (c), a

loc_66B:
                sub     a
                ld      (SEG_D+F_START), a
                ld      (SEG_D+F_DIV), a
                ld      (SEG_D+F_VOL), a
                ld      (SEG_D+F_LOOP), a
                ld      (SEG_D+F_CH_ON), a

                ; --- Row tick counter ---
                ld      a, (TEMP_CONT)
                or      a
                jr      z, loc_6A4
                dec     a
                ld      (TEMP_CONT), a
                ; mid-row: run per-tick effects on all four channels
                ld      ix, SEG_A
                call    command
                ld      ix, SEG_B
                call    command
                ld      ix, SEG_C
                call    command
                ld      ix, SEG_D
                call    command
                jp      int_hook_buffer
; ---------------------------------------------------------------------------

loc_6A4:
                ld      a, (SOUND_ON)
                or      a
                jp      z, int_hook_buffer
                ld      a, (TEMP_PE)
                or      a
                jr      z, loc_6B2
                dec     a

loc_6B2:
                ld      (TEMP_CONT), a             ; reload tick counter
                ld      a, (F_N_PAT)
                or      a
                jr      z, loc_6C2
                sub     a
                ld      (F_N_PAT), a
                call    next_order                 ; advance to the next order

loc_6C2:
                ; --- Fetch next note for each channel ---
                ld      ix, SEG_A
                call    next_note
                ld      ix, SEG_B
                call    next_note
                ld      ix, SEG_C
                call    next_note
                ld      ix, SEG_D
                call    next_note
                ld      a, 0FFh
                ld      (F_TEMP), a                ; signal "new row" to main loop

int_hook_buffer:
                nop
                nop
                nop
                nop
                nop
                nop
                ret

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; NEXT_NOT
;   Advance one channel by one row: read the 4-byte note record from the
;   pattern, decode it into N_NOTE / N_SAMPLE / N_VOLUME / N_COMAND / N_PARAM,
;   call GET_NOT to prepare DMA parameters, and handle arpeggio setup.
;
; Pattern row format (4 bytes per channel, 4 channels = 16 bytes per row):
;   byte 0: note byte (with octave in high nibble; 0xFF = no note,
;           0xFE = key off)
;   byte 1: bits 7..3 = instrument number, bits 2..0 = high 3 bits of volume
;   byte 2: bits 7..3 = low 5 bits of volume, bits 3..0 = command
;   byte 3: command parameter
; -----------------------------------------------------------------------------
next_note:
                inc     (ix+PAT_POINT)
                ld      a, (ix+PAT_POINT)
                cp      40h                        ; 64 rows per pattern
                jr      c, loc_6F9
                ld      a, 1
                ld      (F_N_PAT), a               ; signal "advance order"

loc_6F9:
                ld      l, (ix+ADR_PAT)
                ld      h, (ix+ADR_PAT+1)
                push    hl
                pop     iy                         ; IY = pointer to the row
                ld      a, (iy+0)
                ld      (ix+N_NOTE), a
                ld      a, (iy+1)
                srl     a
                srl     a
                srl     a
                ld      (ix+N_SAMPLE), a
                ld      a, (iy+1)
                and     7
                ld      l, a
                ld      a, (iy+2)
                rrca
                and     78h
                or      l
                ld      (ix+N_VOLUME), a
                ld      a, (iy+2)
                and     0Fh
                ld      (ix+N_COMAND), a
                ld      a, (iy+3)
                ld      (ix+N_PARAM), a
                push    iy
                pop     hl
                ld      de, 10h
                add     hl, de                     ; advance to next row (16 bytes)
                ld      (ix+ADR_PAT), l
                ld      (ix+ADR_PAT+1), h
                call    get_note
                ld      a, (ix+N_COMAND)
                cp      9
                jp      nz, loc_74E
                call    command                    ; command 9 = tremor, run now
                ret
; ---------------------------------------------------------------------------

loc_74E:
                cp      0Ah
                ret     nz
                ld      (ix+F_ARP), 1              ; command 10 = arpeggio
                ld      a, (ix+N_PARAM)
                and     0F0h
                srl     a
                srl     a
                srl     a
                srl     a                          ; high nibble = arpeggio period
                ld      (ix+TIM_ARP), a
                ret
; End of function next_note

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; GET_NOT
;   Decode the current note into per-channel DMA parameters.
;
; Special note values:
;   0xFE -> key off (F_CH_ON = 1, channel will be silenced)
;   0xFF -> no note (skip frequency update, keep playing)
;
; Command 7 -> portamento (only update SEK_DIV, not SNG_DIV)
; -----------------------------------------------------------------------------
get_note:
                ld      a, (ix+N_VOLUME)
                cp      41h                        ; 0x41 = "use instrument default"
                jr      nc, loc_777
                ld      (ix+SNG_VOL), a
                ld      (ix+SEK_VOL), a
                ld      (ix+F_VOL), 1

loc_777:
                ld      a, (ix+N_COMAND)
                cp      7
                jp      z, loc_849                 ; command 7 = portamento
                ld      a, (ix+N_NOTE)
                cp      0FFh
                jp      z, loc_845                 ; no note -> just dispatch GOTO
                ld      a, (ix+N_SAMPLE)
                or      0
                jp      z, loc_820                 ; instrument 0 -> no sample
                ; --- Locate the instrument header (32 bytes per entry) ---
                ld      l, a
                ld      h, 0
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                ld      de, INST-32                ; start of the instrument table
                add     hl, de
                push    hl
                pop     iy
                ld      (ix+SEK_SAMP), l
                ld      (ix+SEK_SAMP+1), h
                ld      a, (ix+N_VOLUME)
                cp      41h
                jr      nz, loc_7B8
                ld      a, (iy+16h)                ; volume from the instrument
                ld      (ix+SNG_VOL), a
                ld      (ix+SEK_VOL), a
                ld      (ix+F_VOL), 1

loc_7B8:
                ; --- Sample start address (offset by 0x49 for the STM header) ---
                ld      l, (iy+0Eh)
                ld      h, (iy+0Fh)
                ld      de, 49h                    ; STM header size
                or      a
                sbc     hl, de
                ld      a, h
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                res     6, h
                res     7, h                       ; mask to page offset
                srl     a
                srl     a
                add     a, 0Ah                     ; page number for DMA
                ld      (ix+S_MAP), a
                ld      (ix+START_0), l
                ld      (ix+START_0+1), h
                ; --- Loop length and loop start ---
                ld      l, (iy+14h)
                ld      h, (iy+15h)                ; loop end
                inc     hl
                ld      a, l
                or      h
                jr      z, loc_810                 ; no loop
                dec     hl
                ld      (ix+LENGHT_0), l
                ld      (ix+LENGHT_0+1), h         ; first length = loop end
                ld      e, (iy+12h)
                ld      d, (iy+13h)                ; loop start
                or      a
                sbc     hl, de                     ; loop length = end - start
                ld      (ix+LENGHT_1), l
                ld      (ix+LENGHT_1+1), h
                ld      l, (ix+START_0)
                ld      h, (ix+START_0+1)
                add     hl, de                     ; loop start address = start + off
                ld      (ix+START_1), l
                ld      (ix+START_1+1), h
                ld      (ix+F_LOOP), 1
                jr      loc_81C
; ---------------------------------------------------------------------------

loc_810:
                ld      l, (iy+10h)
                ld      h, (iy+11h)                ; sample length
                ld      (ix+LENGHT_0), l
                ld      (ix+LENGHT_0+1), h

loc_81C:
                ld      (ix+F_START), 1

loc_820:
                ld      a, (ix+N_NOTE)
                cp      0FEh
                jr      nz, loc_82E
                ld      (ix+F_CH_ON), 1            ; key off -> disable the channel
                jp      loc_845
; ---------------------------------------------------------------------------

loc_82E:
                cp      0FFh
                jr      z, loc_845
                call    ret_div
                ld      (ix+SEK_DIV), l
                ld      (ix+SEK_DIV+1), h
                ld      (ix+SNG_DIV), l
                ld      (ix+SNG_DIV+1), h
                ld      (ix+F_DIV), 1

loc_845:
                call    goto
                ret
; ---------------------------------------------------------------------------

loc_849:
                ld      a, (ix+N_NOTE)
                cp      0FFh
                ret     z
                call    ret_div
                ld      (ix+SEK_DIV), l
                ld      (ix+SEK_DIV+1), h
                ret
; End of function get_note

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; RET_DIV
;   Compute the timer divisor for the current note.
;
;   The divisor table for each instrument is at (SEK_SAMP + 0x460).
;   Indexed by (note & 0x0F) * 2 (12 entries per octave). The octave part of
;   the note (high nibble) selects a right shift.
;
; Input:  IX = channel state, N_NOTE must be set
; Output: HL = timer divisor
; -----------------------------------------------------------------------------
ret_div:
                push    af
                and     0Fh
                ld      l, a
                ld      h, 0
                add     hl, hl
                ld      e, (ix+SEK_SAMP)
                ld      d, (ix+SEK_SAMP+1)
                add     hl, de
                ld      de, 460h
                add     hl, de
                ld      e, (hl)
                inc     hl
                ld      d, (hl)
                ex      de, hl
                pop     af
                srl     a
                srl     a
                srl     a
                srl     a
                and     7
                ret     z
                ld      b, a

loc_87C:
                srl     h
                rr      l
                djnz    loc_87C
                ret
; End of function ret_div

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; GOTO
;   Handle commands 1, 2, 3 from the note record.
;
;   Command 1 (TEMPO): set ticks-per-row from the parameter (min 16, /16).
;   Command 2 (JUMP):  set NEXT_ORD to ORDER + parameter (absolute jump).
;   Command 3 (BREAK): force "advance to next order" on the next row.
; -----------------------------------------------------------------------------
goto:
                ld      a, (ix+N_PARAM)
                ld      e, a
                ld      a, (ix+N_COMAND)
                cp      1
                jr      z, loc_897
                cp      2
                jr      z, loc_8AD
                cp      3
                jr      z, break
                ret
; ---------------------------------------------------------------------------

loc_897:
                ld      a, e
                cp      10h
                jr      nc, loc_89E
                ld      a, 10h                     ; clamp to minimum 16

loc_89E:
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (TEMP_PE), a
                ld      (TEMP_CONT), a
                ret
; ---------------------------------------------------------------------------

loc_8AD:
                ld      d, 0
                ld      hl, ORDER
                add     hl, de
                ld      (NEXT_ORD), hl
                ret
; ---------------------------------------------------------------------------

break:
                ld      a, 1
                ld      (F_N_PAT), a               ; force order advance
                ret
; End of function goto

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; COMMAND
;   Run the per-tick effect for the current command on the channel.
;   Called every tick (mid-row) from the interrupt handler.
; -----------------------------------------------------------------------------
command:
                ld      a, (ix+PIK_VOL)
                or      a
                jr      z, loc_8C7
                dec     a
                ld      (ix+PIK_VOL), a            ; decay VU-meter peak

loc_8C7:
                ld      a, (ix+N_PARAM)
                ld      l, a
                ld      a, (ix+N_COMAND)
                cp      4
                jp      z, slide
                cp      5
                jp      z, por_down
                cp      6
                jp      z, por_up
                cp      9
                jp      z, tremor
                ld      (ix+TIM_TREM), 0
                ld      (ix+ON_OFF), 1
                cp      7
                jp      z, portamento
                cp      8
                jp      z, vibrato
                ld      (ix+VIB_POINT), 0
                cp      0Ah
                ret                                ; arpeggio dispatch disabled
; ---------------------------------------------------------------------------

por_up:
                ld      h, 0
                ld      e, (ix+SNG_DIV)
                ld      d, (ix+SNG_DIV+1)
                ex      de, hl
                or      a
                sbc     hl, de
                ld      (ix+SNG_DIV), l
                ld      (ix+SNG_DIV+1), h
                ld      (ix+F_DIV), 1
                ret
; ---------------------------------------------------------------------------

por_down:
                ld      h, 0
                ld      e, (ix+SNG_DIV)
                ld      d, (ix+SNG_DIV+1)
                add     hl, de
                ld      (ix+SNG_DIV), l
                ld      (ix+SNG_DIV+1), h
                ld      (ix+F_DIV), 1
                ret
; ---------------------------------------------------------------------------

slide:
                ld      (ix+F_VOL), 1
                ld      a, l
                and     0Fh
                jr      z, v_up
                ld      l, a
                ld      a, (ix+SNG_VOL)
                sub     l
                ld      (ix+SNG_VOL), a
                ret     nc
                ld      (ix+SNG_VOL), 0
                ret
; ---------------------------------------------------------------------------

v_up:
                ld      a, l
                srl     a
                srl     a
                srl     a
                srl     a
                ld      l, a
                ld      a, (ix+SNG_VOL)
                add     a, l
                ld      (ix+SNG_VOL), a
                cp      41h
                ret     c
                ld      (ix+SNG_VOL), 40h          ; clamp to 0x40
                ret
; ---------------------------------------------------------------------------

tremor:
                ld      a, (ix+TIM_TREM)
                or      a
                jr      z, _tremor_1
                dec     a
                ld      (ix+TIM_TREM), a
                ret
; ---------------------------------------------------------------------------

_tremor_1:
                ld      a, (ix+ON_OFF)
                cp      1
                jr      z, _tremor_2
                ld      (ix+ON_OFF), 1
                ld      a, (ix+SEK_VOL)
                ld      (ix+SNG_VOL), a
                ld      a, l
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (ix+TIM_TREM), a
                ret
; ---------------------------------------------------------------------------

_tremor_2:
                ld      (ix+ON_OFF), 0
                ld      (ix+SNG_VOL), 0
                ld      a, l
                and     0Fh
                ld      (ix+TIM_TREM), a
                ret
; ---------------------------------------------------------------------------

arpejio:
                ld      a, (ix+F_ARP)
                or      a
                ret     z
                ld      a, (ix+TIM_ARP)
                or      a
                jr      z, AR_0
                dec     a
                ld      (ix+TIM_ARP), a
                ret
; ---------------------------------------------------------------------------

AR_0:
                ld      h, 0
                ld      a, l
                ld      a, 0Fh                     ; arpeggio shift amount
                ld      l, a
                ex      de, hl
                ld      l, (ix+SEK_DIV)
                ld      h, (ix+SEK_DIV+1)
                or      a
                sbc     hl, de
                ld      (ix+SNG_DIV), l
                ld      (ix+SNG_DIV+1), h
                ld      (ix+F_DIV), 1
                ld      (ix+F_ARP), 0
                ret
; ---------------------------------------------------------------------------
                rst     18h
                rst     18h
                rst     18h

portamento:
                ld      e, (ix+SNG_DIV)
                ld      d, (ix+SNG_DIV+1)
                ld      l, (ix+SEK_DIV)
                ld      h, (ix+SEK_DIV+1)
                or      a
                push    hl
                sbc     hl, de
                pop     hl
                ret     z
                jp      c, _portamentor_2
                ld      c, (ix+N_PARAM)
                ld      b, 0
                ex      de, hl
                add     hl, bc
                ex      de, hl
                or      a
                push    hl
                sbc     hl, de
                pop     hl
                jr      nc, _portamento_1
                ex      de, hl

_portamento_1:
                ld      (ix+SNG_DIV), e
                ld      (ix+SNG_DIV+1), d
                ld      (ix+F_DIV), 1
                ret
; ---------------------------------------------------------------------------

_portamentor_2:
                ld      c, (ix+N_PARAM)
                ld      b, 0
                ex      de, hl
                or      a
                sbc     hl, bc
                ex      de, hl
                or      a
                push    hl
                sbc     hl, de
                pop     hl
                jr      c, _portamento_3
                ex      de, hl

_portamento_3:
                ld      (ix+SNG_DIV), e
                ld      (ix+SNG_DIV+1), d
                ld      (ix+F_DIV), 1
                ret
; ---------------------------------------------------------------------------

vibrato:
                ld      h, (ix+VIB_POINT)
                ld      e, h
                ld      d, 0
                push    hl
                ld      a, l
                and     0Fh
                inc     a
                ld      b, a
                ex      de, hl
                sra     h
                rr      l
                add     hl, hl
                ld      de, T_VIBRATO
                add     hl, de
                ld      e, (hl)
                inc     hl
                ld      d, (hl)
                call    divide_de_by_2
                call    divide_de_by_2
                call    divide_de_by_2
                call    divide_de_by_2
                call    divide_de_by_2
                call    divide_de_by_2
                ld      hl, 0

_vibrator_1:
                add     hl, de
                djnz    _vibrator_1
                ex      de, hl
                ld      l, (ix+SEK_DIV)
                ld      h, (ix+SEK_DIV+1)
                add     hl, de
                ld      (ix+SNG_DIV), l
                ld      (ix+SNG_DIV+1), h
                pop     hl
                ld      a, h
                srl     l
                srl     l
                srl     l
                srl     l
                add     a, l
                inc     a
                and     7Fh
                ld      (ix+VIB_POINT), a
                ld      (ix+F_DIV), 1
                ret
; End of function command

; =============== S U B R O U T I N E =======================================

divide_de_by_2:
                sra     d
                rr      e
                ret     nc
                inc     de
                ret
; End of function divide_de_by_2

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; NEX_ORD
;   Move NEXT_ORD to the next order byte and reconfigure the four pattern
;   pointers (ADR_PAT) to point at the new pattern's first row.
;
;   Order byte format: high nibble = pattern number.
;   0x63 is the end-of-song marker; on 0x63 the player wraps to the start
;   of ORDER and forces all channels off.
; -----------------------------------------------------------------------------
next_order:
                ld      a, (F_PRINT)
                or      a
                call    nz, print_new_line
                ld      hl, (NEXT_ORD)
                ld      a, (hl)
                cp      63h                        ; end-of-song marker
                jr      nz, loc_A8A
                ld      hl, ORDER                  ; wrap to start
                ld      a, 1
                ld      (SEG_A+F_CH_ON), a         ; silence all channels on wrap
                ld      (SEG_B+F_CH_ON), a
                ld      (SEG_C+F_CH_ON), a
                ld      (SEG_D+F_CH_ON), a
                ld      a, (hl)                    ; re-read the first order byte

loc_A8A:
                ld      (SEK_ORD), hl
                inc     hl
                ld      (NEXT_ORD), hl
                ld      (NUM_PART), a
                ld      h, a
                and     0F0h                       ; high nibble = pattern number
                srl     a
                srl     a
                srl     a
                srl     a
                add     a, 0Ah                     ; page = pattern + 0x0A
                ld      (0F342h), a                ; BIOS/BDOS variable (side effect)
                or      0C0h                       ; bits 7..6 = 11
                ld      bc, 7DFFh
                out     (c), a                     ; RAM/ROM bank select
                ld      l, 0
                add     hl, hl                     ; *2
                add     hl, hl                     ; *4
                ld      a, h
                and     3Fh
                or      40h                        ; force page 1 (0x4000..0x7FFF)
                ld      h, a                       ; HL = pattern base address
                ld      de, 4
                ld      (SEG_A+ADR_PAT), hl        ; ch A at offset 0
                add     hl, de
                ld      (SEG_B+ADR_PAT), hl        ; ch B at offset 4
                add     hl, de
                ld      (SEG_C+ADR_PAT), hl        ; ch C at offset 8
                add     hl, de
                ld      (SEG_D+ADR_PAT), hl        ; ch D at offset 12
                sub     a
                ld      (SEG_A+PAT_POINT), a       ; reset row counters
                ld      (SEG_B+PAT_POINT), a
                ld      (SEG_C+PAT_POINT), a
                ld      (SEG_D+PAT_POINT), a
                ret
; End of function next_order

; ---------------------------------------------------------------------------

nmi_hook:
                push    hl
                push    de
                push    bc
                push    af
                call    nmi_imp
                pop     af
                pop     bc
                pop     de
                pop     hl
                retn

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; NMI
;   Handles the 8237 DMA terminal-count interrupt. Reads the 8237 status
;   register (DMACOM) to see which channel(s) finished, then for each armed
;   channel (F_RESTART) reprograms it to the loop half and re-enables it
;   in autoinit mode.
; -----------------------------------------------------------------------------
nmi_imp:
                ld      bc, DMACOM
                in      e, (c)                     ; read TC status bits
                rrc     e
                jr      nc, loc_B15
                ld      a, (SEG_A+F_RESTART)
                or      a
                jr      z, loc_B15
                ld      hl, (SEG_A+NMI_START)
                ld      bc, DMA_A
                out     (c), l
                out     (c), h                     ; new base address
                inc     c
                ld      hl, (SEG_A+NMI_LENGHT)
                out     (c), l
                out     (c), h                     ; new count
                sub     a
                ld      (SEG_A+F_RESTART), a       ; disarm
                ld      bc, DMAMOD
                ld      a, 58h                     ; 8237 mode: autoinit (ch A)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 0                       ; unmask -> restart
                out     (c), a

loc_B15:
                nop
                rrc     e
                jr      nc, loc_B44
                ld      a, (SEG_B+F_RESTART)
                or      a
                jr      z, loc_B44
                ld      hl, (SEG_B+NMI_START)
                ld      bc, DMA_B
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_B+NMI_LENGHT)
                out     (c), l
                out     (c), h
                sub     a
                ld      (SEG_B+F_RESTART), a
                ld      bc, DMAMOD
                ld      a, 59h                     ; 8237 mode: autoinit (ch B)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 1
                out     (c), a

loc_B44:
                nop
                rrc     e
                jr      nc, loc_B73
                ld      a, (SEG_C+F_RESTART)
                or      a
                jr      z, loc_B73
                ld      hl, (SEG_C+NMI_START)
                ld      bc, DMA_C
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_C+NMI_LENGHT)
                out     (c), l
                out     (c), h
                sub     a
                ld      (SEG_C+F_RESTART), a
                ld      bc, DMAMOD
                ld      a, 5Ah                     ; 8237 mode: autoinit (ch C)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 2
                out     (c), a

loc_B73:
                nop
                rrc     e
                jr      nc, loc_BA2
                ld      a, (SEG_D+F_RESTART)
                or      a
                jr      z, loc_BA2
                ld      hl, (SEG_D+NMI_START)
                ld      bc, DMA_D
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (SEG_D+NMI_LENGHT)
                out     (c), l
                out     (c), h
                sub     a
                ld      (SEG_D+F_RESTART), a
                ld      bc, DMAMOD
                ld      a, 5Bh                     ; 8237 mode: autoinit (ch D)
                out     (c), a
                ld      bc, DMAMASK
                ld      a, 3
                out     (c), a

loc_BA2:
                nop
                ret
; End of function nmi_imp

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; SET_INT
;   Save the current INT 38h and NMI vectors, then install PRG_INT at 0038h
;   and NMI at 0066h.
; -----------------------------------------------------------------------------
set_interrupt_hook:
                di
                ld      hl, 0FD9Fh
                ld      de, 6E4h
                ld      bc, 5
                ldir                               ; save interrupt hook
                ld      hl, int_hook_vector
                ld      de, 0FD9Fh
                ld      bc, 5
                ldir                               ; set interrupt hook
                ld      hl, nmi_hook_buffer
                ld      de, 0FD90h
                ld      bc, 5
                ldir                               ; save nmi hook
                ld      a, 0C3h
                ld      (66h), a                   ; set nmi hook opcode
                ld      hl, nmi_hook
                ld      (67h), hl                  ; set nmi hook address
                ret
; End of function set_interrupt_hook

; ---------------------------------------------------------------------------

int_hook_vector:
                rst     30h
                inc     b
                sub     a
                inc     bc
                ret
; ---------------------------------------------------------------------------

nmi_hook_buffer:
                rst     30h
                inc     b
                jp      po, 0C90Ah

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; GET_INT
;   Restore the original INT 38h and NMI vectors from BUF_INT / BUF_NMI.
; -----------------------------------------------------------------------------
remove_interrupt_hook:
                di
                ld      hl, 6E4h
                ld      de, 0FD9Fh
                ld      bc, 5
                ldir
                ld      a, 0C9h
                ld      (66h), a
                ret
; End of function remove_interrupt_hook

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; INI_DIV
;   Precompute the per-instrument divisor table I_DIV. For each of the
;   31 instruments, IDIV_1 multiplies the 12 standard divisors by the
;   instrument's frequency ratio and stores the results in I_DIV.
; -----------------------------------------------------------------------------
init_div:
                ld      ix, INST
                ld      iy, I_DIV
                ld      de, 20h
                ld      b, 1Fh

loc_BFB:
                push    de
                push    bc
                call    inst_div
                pop     bc
                pop     de
                add     ix, de
                add     iy, de
                djnz    loc_BFB
                ret
; End of function init_div

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; IDIV_1
;   For one instrument:
;     1. Read the instrument's frequency and compute ratio = freq / 0x2100.
;     2. For each of the 12 notes in ST_DIV, multiply the standard divisor
;        by this ratio and store the result in I_DIV.
; -----------------------------------------------------------------------------
inst_div:
                ld      e, (ix+18h)
                ld      d, (ix+19h)                ; DE = instrument frequency
                ld      bc, 4200h                  ; standard frequency
                call    divide                     ; BC = BC / DE (ratio)
                ld      e, c
                ld      d, b                       ; DE = ratio
                push    iy
                pop     bc                         ; BC = destination table
                ld      a, 0Ch                     ; 12 notes per octave
                ld      hl, standart_divisors      ; standard divisors

loc_C1F:
                push    af
                push    hl
                push    bc
                ld      c, (hl)
                inc     hl
                ld      b, (hl)                    ; BC = standard divisor
                call    multiply                   ; HLBC * DE -> BC,HL
                pop     hl                         ; restore destination pointer
                ld      (hl), c
                inc     hl
                ld      (hl), b                    ; store the scaled divisor
                inc     hl
                push    hl
                pop     bc                         ; BC = next destination
                pop     hl                         ; HL = next ST_DIV entry
                pop     af
                inc     hl
                inc     hl                         ; ST_DIV is words
                dec     a
                jr      nz, loc_C1F
                ret
; End of function inst_div

; ---------------------------------------------------------------------------
standart_divisors:
                dw      3B3h
                dw      37Eh
                dw      34Bh
                dw      31Ch
                dw      2EFh
                dw      2C5h
                dw      29Dh
                dw      278h
                dw      254h
                dw      233h
                dw      213h
                dw      1F5h

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; LOAD
;   Open the .STM file, read its header into DATA, verify the version and
;   pattern count, then read the pattern data into memory (in 16 KB pages)
;   and de-interleave (XOR 0x80) each byte of the pattern area.
; -----------------------------------------------------------------------------
load_stm_file:
                ld      hl, 5Ch+12
                ld      de, 5Ch+13
                ld      bc, 18h
                ld      (hl), 0
                ldir                               ; zero the FCB filename area
                ld      a, 53h                     ; 'S'
                ld      (5Ch+9), a                 ; force extension "STM"
                ld      a, 54h                     ; 'T'
                ld      (5Ch+10), a
                ld      a, 4Dh                     ; 'M'
                ld      (5Ch+11), a
                call    open_file
                ld      hl, 10h
                ld      (5Ch+14), hl               ; record count = 16 (header block)
                ld      de, DATA                   ; set DMA to DATA
                ld      c, 1Ah
                call    5
                ld      hl, 49h                    ; 73 records (header + instruments)
                ld      de, 5Ch
                ld      c, 27h
                call    5                          ; read random block
                ld      de, bad_version_message
                ld      a, (DATA+1Eh)
                cp      2
                jp      nz, print_error
                ld      de, bad_number_message
                ld      a, (DATA+1Dh)
                cp      2
                jp      nz, print_error
                ld      de, loading_message
                ld      c, 9
                call    5                          ; print "Loading : "
                sub     a
                ld      (DATA+13h), a
                ld      de, DATA
                call    print_string               ; print the file name
                ld      hl, DATA
                ld      de, 119Dh
                ld      bc, 13h
                ldir
                ld      de, 4000h
                ld      c, 1Ah
                call    5                          ; DMA -> 0x4000 (patterns go here)
                ld      hl, 400h                   ; 1024 records = 16 KB
                ld      c, 0Ah                     ; starting page = 0x0A

loc_CC7:
                push    bc
                push    hl
                ld      h, 40h                     ; bank 0x40 (page 1)
                ld      a, c
                call    24h                        ; MSX-DOS: 0024h hook
                pop     hl
                ld      de, 5Ch
                ld      c, 27h
                call    5                          ; read 16 KB
                or      a
                jr      nz, loc_CE3                ; short read -> last page
                ld      hl, 400h
                pop     bc
                inc     c
                jr      loc_CC7
; ---------------------------------------------------------------------------
                ret
; ---------------------------------------------------------------------------

loc_CE3:
                pop     bc                         ; last page (instruments?)
                ld      a, (DATA+21h)              ; number of patterns
                ld      l, a
                ld      h, 0
                add     hl, hl                     ; *2
                add     hl, hl                     ; *4
                add     hl, hl                     ; *8
                add     hl, hl                     ; *16
                add     hl, hl                     ; *32
                add     hl, hl                     ; *64
                ld      a, h
                rrca
                rrca
                and     1Fh
                add     a, 0Ah                     ; start page for instruments
                add     hl, hl                     ; *128
                add     hl, hl                     ; *256
                add     hl, hl                     ; *512
                add     hl, hl                     ; *1024
                res     7, h
                set     6, h                       ; clamp to page 1
                inc     c

loc_D00:
                push    af
                push    hl
                push    bc
                ld      h, 40h
                call    24h                        ; MSX-DOS: 0024h hook
                pop     bc
                pop     hl

loc_D0A:
                ld      a, (hl)
                xor     80h                        ; de-interleave
                ld      (hl), a
                inc     hl
                ld      a, h
                cp      80h
                jr      nz, loc_D0A
                pop     af
                ld      hl, 4000h
                inc     a
                cp      c
                jr      nz, loc_D00
                ld      a, 5
                ld      h, 40h
                call    24h                        ; MSX-DOS: 0024h hook
                ret
; End of function load_stm_file

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; PRINT
;   Print a string up to 0 (zero-terminated).
; -----------------------------------------------------------------------------
print_string:
                ld      a, (de)
                or      a
                ret     z
                push    de
                ld      e, a
                ld      c, 2
                ld      c, 2
                call    5
                pop     de
                inc     de
                jr      print_string
; End of function print_string

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; HEX
;   Print a byte as two hex digits.
; -----------------------------------------------------------------------------
print_hex:
                push    ix
                push    af
                and     0F0h
                srl     a
                srl     a
                srl     a
                srl     a
                call    print_hex_hibble
                pop     af
                and     0Fh
                call    print_hex_hibble
                pop     ix
                ret
; End of function print_hex

; =============== S U B R O U T I N E =======================================

print_hex_hibble:
                cp      0Ah
                jr      nc, loc_D55
                add     a, 30h                     ; '0'..'9'
                jr      loc_D57
; ---------------------------------------------------------------------------

loc_D55:
                add     a, 37h                     ; 'A'..'F'

loc_D57:
                rst     30h
                ex      af, af'
                jr      locret_D5B
; ---------------------------------------------------------------------------

locret_D5B:
                ret
; End of function print_hex_hibble

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; ENTER
;   Print a newline (LF + CR).
; -----------------------------------------------------------------------------
print_new_line:
                push    ix
                ld      a, 0Ah                     ; LF
                rst     30h
                ex      af, af'
                jr      loc_D64
; ---------------------------------------------------------------------------

loc_D64:
                ld      a, 0Dh                     ; CR
                rst     30h
                ex      af, af'
                jr      loc_D6A
; ---------------------------------------------------------------------------

loc_D6A:
                pop     ix
                ret
; End of function print_new_line

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; SPACE
;   Print a space.
; -----------------------------------------------------------------------------
print_space:
                push    ix
                ld      a, 1Ch                     ; space
                rst     30h
                ex      af, af'
                jr      loc_D75
; ---------------------------------------------------------------------------

loc_D75:
                pop     ix
                ret
; End of function print_space

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; OUT_PUT
;   Debug-print one channel's current note as a hex dump.
; -----------------------------------------------------------------------------
print_curent_note:
                ld      a, (ix+N_NOTE)
                call    print_hex
                call    print_space
                ld      a, (ix+N_SAMPLE)
                call    print_hex
                call    print_space
                ld      a, (ix+N_VOLUME)
                call    print_hex
                call    print_space
                ld      a, (ix+N_COMAND)
                or      a
                jr      z, loc_D9D
                add     a, 40h                     ; command -> letter 'A'+cmd-1
                jr      loc_D9F
; ---------------------------------------------------------------------------

loc_D9D:
                ld      a, 2Eh                     ; '.'

loc_D9F:
                push    ix
                rst     30h
                ex      af, af'
                jr      loc_DA5
; ---------------------------------------------------------------------------

loc_DA5:
                pop     ix
                ei
                ld      a, (ix+N_PARAM)
                call    print_hex
                call    print_space
                call    print_space
                call    print_space
                ret
; End of function print_curent_note

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; OPEN_FILE
;   Open the file whose FCB is at 005Ch.
; -----------------------------------------------------------------------------
open_file:
                ld      de, 5Ch
                ld      c, 0Fh
                call    5                          ; open file
                ld      hl, 0
                ld      (5Ch+21h), hl              ; reset current record
                or      a
                ret     z                          ; success
                ld      de, file_not_found_message
                jp      print_error
; ---------------------------------------------------------------------------
file_not_found_message:
                db      20h
                db      0E6h
                db      0E1h
                db      0EAh
                db      0ECh
                db      20h
                db      0CEh
                db      0C5h
                db      20h
                db      0CEh
                db      0C1h
                db      0CAh
                db      0C4h
                db      0C5h
                db      0CEh
                db      20h
                db      24h
; ---------------------------------------------------------------------------

print_error:
                ld      c, 9
                call    5                          ; print the $-terminated string
                rst     0                          ; warm boot
; End of function open_file

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; INI_PRT
;   Configure the 8254 timers and the 8237 DMA controller for Magic Sound
;   playback.
; -----------------------------------------------------------------------------
int_ptr:
                ld      bc, TIMUP0                 ; 8254 #1 control
                ld      a, 34h                     ; counter 0, mode 2, LSB/MSB
                out     (c), a
                ld      a, 74h                     ; counter 1, mode 2
                out     (c), a
                ld      a, 0B4h                    ; counter 2, mode 2
                out     (c), a
                ld      bc, TIMUP1                 ; 8254 #2 control
                ld      a, 34h                     ; counter 0, mode 2
                out     (c), a
                ld      a, 76h                     ; counter 1, mode 3 (square)
                out     (c), a
                ld      bc, TIM_E                  ; aux counter
                ld      a, 4
                out     (c), a                     ; load 4 (LSB)
                sub     a
                out     (c), a                     ; load 0 (MSB) -> period = 4
                ld      bc, DMARES                 ; 8237 master clear
                out     (c), a                     ; A = 0
                ld      bc, DMACOM
                sub     a
                out     (c), a                     ; command = 0
                ld      bc, DMAMASK
                ld      hl, 405h                   ; mask 05h then 04h
                out     (c), l
                out     (c), h
                ld      hl, 607h                   ; mask 07h then 06h
                out     (c), l
                out     (c), h
                ret
; End of function int_ptr

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; MUL
;   Multiply the 16-bit value in BC by the 16-bit value in DE, using the
;   HL register pair as an accumulator. Result is returned in BC (high) and
;   HL (low): 32-bit product BC:HL.
; -----------------------------------------------------------------------------
multiply:
                ld      hl, 0                      ; HL = low half of accumulator
                ld      a, b                       ; A = high byte of BC (multiplier)
                ld      b, 11h                     ; 17 iterations (16 + 1)
                jr      loc_E35
; ---------------------------------------------------------------------------

loc_E2E:
                jr      nc, loc_E31                ; no carry -> skip add
                add     hl, de                     ; add multiplicand

loc_E31:
                rr      h
                rr      l                          ; shift accumulator right

loc_E35:
                rr      a                          ; shift multiplier, carry out
                rr      c
                djnz    loc_E2E
                ld      b, a                       ; high half = A
                ret
; End of function multiply

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; DIV
;   Divide the 16-bit value in BC by the 16-bit value in DE, returning
;   the quotient in BC and the remainder in HL. Uses a restoring
;   shift-and-subtract algorithm.
; -----------------------------------------------------------------------------
divide:
                ld      hl, 0                      ; HL = remainder
                ld      a, b                       ; A = high byte of dividend
                ld      b, 10h                     ; 16 iterations
                rl      c
                rla

loc_E46:
                rl      l
                rl      h                          ; shift remainder left
                jr      c, loc_E5F                 ; overflow -> subtract
                sbc     hl, de
                jr      nc, loc_E51                ; no borrow -> quotient bit = 1
                add     hl, de                     ; restore remainder

loc_E51:
                ccf                                ; complement carry into quotient

loc_E52:
                rl      c
                rla
                djnz    loc_E46
                ld      b, a
; Integer part from ( BC, HL )
                add     hl, hl                     ; remainder * 2
                or      a
                sbc     hl, de                     ; (rem * 2) - divisor
                ret     c                          ; < 0 -> done
                inc     bc                         ; round up
                ret
; ---------------------------------------------------------------------------

loc_E5F:
                or      a
                sbc     hl, de
                jr      loc_E52
; End of function divide

; =============== S U B R O U T I N E =======================================

; -----------------------------------------------------------------------------
; INIT_SCREEN
;   Set up the screen mode and draw the initial VU-meters and marquee.
; -----------------------------------------------------------------------------
init_screen:
                ld      a, 1
                ld      bc, 300h
                ld      ix, 81h
                ld      iy, 800h
                call    1Ch
                ld      a, 1
                ld      e, 0
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ld      a, 3
                ld      e, 0
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ld      a, 2
                ld      e, 0
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ld      de, 0F16h
                call    print_string               ; print "Loading : "
                ld      hl, 11B2h
                ld      b, 9

loc_EAC:
                push    hl
                push    bc
                ld      b, 32h

loc_EB0:
                push    bc
                ld      b, 0

loc_EB3:
                nop
                djnz    loc_EB3
                pop     bc
                djnz    loc_EB0
                ld      e, (hl)
                ld      a, 3
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                pop     bc
                pop     hl
                inc     hl
                djnz    loc_EAC
                ld      a, 1
                ld      e, 30h
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ret
; End of function init_screen

; ---------------------------------------------------------------------------
bad_number_message:
                db      0EEh
                db      0C5h
                db      20h
                db      0D3h
                db      0CFh
                db      0D7h
                db      0D0h
                db      0C1h
                db      0C4h
                db      0C1h
                db      0C5h
                db      0D4h
                db      20h
                db      0CEh
                db      0CFh
                db      0CDh
                db      0C5h
                db      0D2h
                db      20h
                db      24h
bad_version_message:
                db      0EEh
                db      0C5h
                db      20h
                db      0D3h
                db      0CFh
                db      0D7h
                db      0D0h
                db      0C1h
                db      0C4h
                db      0C1h
                db      0C5h
                db      0D4h
                db      20h
                db      0CEh
                db      0CFh
                db      0CDh
                db      0C5h
                db      0D2h
                db      20h
                db      0D7h
                db      0C5h
                db      0D2h
                db      0D3h
                db      0C9h
                db      0C9h
                db      20h
                db      24h
loading_message:
                db      4Ch
                db      6Fh
                db      61h
                db      64h
                db      69h
                db      6Eh
                db      67h
                db      20h
                db      3Ah
                db      20h
                db      24h
demo_text_info:
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      42h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      41h
                db      4Ch
                db      45h
                db      53h
                db      54h
                db      45h
                db      20h
                db      20h
                db      4Dh
                db      43h
                db      20h
                db      20h
                db      35h
                db      32h
                db      30h
                db      20h
                db      45h
                db      58h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      43h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      4Dh
                db      41h
                db      47h
                db      49h
                db      43h
                db      20h
                db      20h
                db      53h
                db      4Fh
                db      55h
                db      4Eh
                db      44h
                db      20h
                db      20h
                db      20h
                db      54h
                db      52h
                db      41h
                db      43h
                db      4Bh
                db      45h
                db      52h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      0Dh
                db      0Ah
                db      20h
                db      20h
                db      20h
                db      20h
                db      0F7h
                db      0D9h
                db      20h
                db      0D3h
                db      0CCh
                db      0D5h
                db      0DBh
                db      0C1h
                db      0C5h
                db      0D4h
                db      0C5h
                db      20h
                db      0DAh
                db      0D7h
                db      0D5h
                db      0CBh
                db      2Ch
                db      20h
                db      0C7h
                db      0C5h
                db      0CEh
                db      0C5h
                db      0D2h
                db      0C9h
                db      0D2h
                db      0D5h
                db      0C5h
                db      0CDh
                db      0D9h
                db      0CAh
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      20h
                db      20h
                db      20h
                db      0CDh
                db      0D5h
                db      0DAh
                db      0D9h
                db      0CBh
                db      0C1h
                db      0CCh
                db      0D8h
                db      0CEh
                db      0CFh
                db      0CAh
                db      20h
                db      0D0h
                db      0CCh
                db      0C1h
                db      0D4h
                db      0CFh
                db      0CAh
                db      20h
                db      22h
                db      4Dh
                db      41h
                db      47h
                db      49h
                db      43h
                db      20h
                db      53h
                db      4Fh
                db      55h
                db      4Eh
                db      44h
                db      22h
                db      2Ch
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      20h
                db      0D0h
                db      0D2h
                db      0C5h
                db      0C4h
                db      0CEh
                db      0C1h
                db      0DAh
                db      0CEh
                db      0C1h
                db      0DEh
                db      0C5h
                db      0CEh
                db      0CEh
                db      0CFh
                db      0CAh
                db      20h
                db      0D4h
                db      0CFh
                db      0CCh
                db      0D8h
                db      0CBh
                db      0CFh
                db      20h
                db      0C4h
                db      0CCh
                db      0D1h
                db      20h
                db      0CBh
                db      0CFh
                db      0CDh
                db      0D0h
                db      0D8h
                db      0C0h
                db      0D4h
                db      0C5h
                db      0D2h
                db      0C1h
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      42h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      41h
                db      4Ch
                db      45h
                db      53h
                db      54h
                db      45h
                db      20h
                db      20h
                db      35h
                db      32h
                db      30h
                db      2Fh
                db      31h
                db      30h
                db      34h
                db      30h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      43h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      53h
                db      54h
                db      45h
                db      52h
                db      45h
                db      4Fh
                db      20h
                db      20h
                db      4Fh
                db      55h
                db      54h
                db      50h
                db      55h
                db      54h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      20h
                db      20h
                db      38h
                db      20h
                db      42h
                db      69h
                db      74h
                db      73h
                db      20h
                db      44h
                db      2Fh
                db      41h
                db      20h
                db      20h
                db      20h
                db      20h
                db      33h
                db      32h
                db      20h
                db      6Bh
                db      48h
                db      7Ah
                db      20h
                db      20h
                db      20h
                db      20h
                db      48h
                db      69h
                db      46h
                db      69h
                db      20h
                db      51h
                db      75h
                db      61h
                db      6Ch
                db      69h
                db      74h
                db      79h
                db      0Dh
                db      0Ah
                db      20h
                db      20h
                db      34h
                db      20h
                db      53h
                db      6Fh
                db      75h
                db      6Eh
                db      64h
                db      20h
                db      43h
                db      68h
                db      61h
                db      6Eh
                db      6Eh
                db      65h
                db      6Ch
                db      20h
                db      2Ch
                db      20h
                db      20h
                db      36h
                db      20h
                db      42h
                db      69h
                db      74h
                db      73h
                db      20h
                db      44h
                db      2Fh
                db      41h
                db      20h
                db      56h
                db      6Fh
                db      6Ch
                db      75h
                db      6Dh
                db      65h
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      42h
                db      20h
                db      20h
                db      20h
                db      20h
                db      49h
                db      42h
                db      4Dh
                db      2Dh
                db      50h
                db      43h
                db      20h
                db      53h
                db      43h
                db      52h
                db      45h
                db      41h
                db      4Dh
                db      20h
                db      54h
                db      52h
                db      41h
                db      43h
                db      4Bh
                db      45h
                db      52h
                db      20h
                db      43h
                db      4Fh
                db      4Dh
                db      50h
                db      41h
                db      54h
                db      49h
                db      42h
                db      4Ch
                db      45h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      0CBh
                db      0C1h
                db      0DEh
                db      0C5h
                db      0D3h
                db      0D4h
                db      0D7h
                db      0CFh
                db      20h
                db      0DAh
                db      0D7h
                db      0D5h
                db      0CBh
                db      0C1h
                db      20h
                db      0C1h
                db      0CEh
                db      0C1h
                db      0CCh
                db      0CFh
                db      0C7h
                db      0C9h
                db      0DEh
                db      0CEh
                db      0CFh
                db      20h
                db      53h
                db      4Fh
                db      55h
                db      4Eh
                db      44h
                db      20h
                db      42h
                db      4Ch
                db      41h
                db      53h
                db      54h
                db      45h
                db      52h
                db      0Dh
                db      0Ah
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      41h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0D0h
                db      0D2h
                db      0CFh
                db      0C4h
                db      0D5h
                db      0CBh
                db      0C3h
                db      0C9h
                db      0D1h
                db      20h
                db      0CBh
                db      0CFh
                db      0CDh
                db      0D0h
                db      0C1h
                db      0CEh
                db      0C9h
                db      0C9h
                db      20h
                db      22h
                db      50h
                db      41h
                db      54h
                db      49h
                db      53h
                db      4Fh
                db      4Eh
                db      49h
                db      43h
                db      22h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      28h
                db      43h
                db      29h
                db      20h
                db      20h
                db      31h
                db      39h
                db      39h
                db      33h
                db      20h
                db      20h
                db      0EFh
                db      0EDh
                db      0F3h
                db      0EBh
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0Dh
                db      0Ah
                db      1Bh
                db      62h
                db      43h
                db      0AAh
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      8Fh
                db      0Dh
                db      0Ah
                db      83h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      83h
                db      0Dh
                db      0Ah
                db      83h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      83h
                db      0Dh
                db      0Ah
                db      83h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      83h
                db      0Dh
                db      0Ah
                db      83h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      83h
                db      0Dh
                db      0Ah
                db      90h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      94h
                db      0A9h
                db      0Dh
                db      0Ah
                db      50h
                db      6Ch
                db      61h
                db      79h
                db      69h
                db      6Eh
                db      67h
                db      3Ah
                db      1Bh
                db      62h
                db      42h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      20h
                db      0
                db      10h
                db      11h
                db      15h
                db      25h
                db      26h
                db      2Ah
                db      3Ah
                db      3Bh
                db      3Fh
demo_text:
                db      30h
                db      31h
                db      22h
                db      13h
                db      3
                db      7
                db      0Ah
                db      0Bh
                db      0Ch
                db      1Ch
                db      28h
                db      34h
                db      0
vibrato_table:
            DB      000h, 000h, 018h, 000h, 031h, 000h, 04Ah, 000h
            DB      061h, 000h, 078h, 000h, 08Dh, 000h, 0A1h, 000h
            DB      0B4h, 000h, 0C5h, 000h, 0D4h, 000h, 0E0h, 000h
            DB      0EBh, 000h, 0F4h, 000h, 0FAh, 000h, 0FDh, 000h
            DB      0FFh, 000h, 0FDh, 000h, 0FAh, 000h, 0F4h, 000h
            DB      0EBh, 000h, 0E0h, 000h, 0D4h, 000h, 0C5h, 000h
            DB      0B4h, 000h, 0A1h, 000h, 08Dh, 000h, 078h, 000h
            DB      061h, 000h, 04Ah, 000h, 031h, 000h, 018h, 000h
            DB      000h, 000h, 0E8h, 0FFh, 0CFh, 0FFh, 0B6h, 0FFh
            DB      09Fh, 0FFh, 088h, 0FFh, 073h, 0FFh, 05Fh, 0FFh
            DB      04Ch, 0FFh, 03Bh, 0FFh, 02Ch, 0FFh, 020h, 0FFh
            DB      015h, 0FFh, 00Ch, 0FFh, 006h, 0FFh, 003h, 0FFh
            DB      001h, 0FFh, 003h, 0FFh, 006h, 0FFh, 00Ch, 0FFh
            DB      015h, 0FFh, 020h, 0FFh, 02Ch, 0FFh, 03Bh, 0FFh
            DB      04Ch, 0FFh, 05Fh, 0FFh, 073h, 0FFh, 088h, 0FFh
            DB      09Fh, 0FFh, 0B6h, 0FFh, 0CFh, 0FFh, 0E8h, 0FFh

                end
