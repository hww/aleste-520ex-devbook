; =============================================================================
; MAGIC SOUND — STM player for ALESTE MC 520 EX
; =============================================================================
;
; WHAT THIS IS
;   A Scream Tracker (.STM) module player for the Magic Sound Board, an
;   expansion card for the Aleste 520EX with 4-channel 8-bit DMA audio.
;   Loads a .STM file from disk (MSX-DOS), converts it to the board's DMA
;   format, and plays it back at 50 Hz with per-channel 8254 timers.
;
; REQUIREMENTS
;   - Aleste 520EX with Magic Sound Board installed
;   - MSX-DOS (the player uses BDOS calls and the 0024h hook)
;   - A .STM module with version 2 and 2 patterns (checked at load)
;
; HOW TO RUN
;   1. Copy MAGIC.COM and a .STM file to the same disk.
;   2. At the MSX-DOS prompt:  MAGIC
;   3. The player opens the first .STM it finds (filename in FCB at 005Ch).
;   4. Keys:
;        Space  — toggle debug print mode (dumps current notes)
;        CR     — force advance to the next order
;        other  — stop playback and return to MSX-DOS
;
; LIMITATIONS
;   - No FM instruments (sample-only playback)
;   - No pattern loop command (only order jump / break)
;   - Arpeggio dispatch is commented out (see COMMAND)
;   - Vibrato scaling is approximate (see VIBRATO)
;   - T_VIB_1 is 256 bytes in this dump but RESTORE copies 512 (see notes)
;
; =============================================================================
;
; BUILD
;
; Target assembler: M80/L80 (historical, CP/M-era). The macros in this
; file use M80 syntax: LOCAL with comma-separated names, and macro
; parameters named SEG/SEG1 (which sjasmplus would textually substitute
; inside SEG_A, SEG_B, etc., breaking the code). Do not try to build
; this with sjasmplus without rewriting the macros.
;
; Build (M80/L80, historical):
;   M80 =MAGIC
;   L80 /P:100,MAGIC,MAGIC/N/E
;
; Cross-platform alternatives:
;   - z88dk's z80asm may work if it accepts M80 LOCAL syntax; verify.
;   - sjasmplus requires rewriting MA_START / MA_NMI (parameter names
;     must not be prefixes of other identifiers; LOCAL syntax differs).
;
; =============================================================================
; Variable name glossary
; -----------------------------------------------------------------------------
; SEG_A..SEG_D      per-channel state blocks (0x20 bytes each, at 0x3078..0x307E)
; F_START           "start DMA for this channel" flag
; F_DIV             "reprogram timer divisor" flag
; F_VOL             "update volume" flag
; F_LOOP            "loop the sample" flag
; F_RESTART         "reprogram DMA on NMI" flag (set from F_LOOP)
; F_CH_ON           "force channel off" flag
; SNG_DIV           current timer divisor (16-bit)
; SNG_VOL           current volume (0..63, 0x40 = max/special)
; SEK_DIV           saved divisor (for portamento target)
; SEK_VOL           saved volume (for tremor)
; SEK_SAMP          pointer to the current instrument header
; PIK_VOL           peak volume, for the VU-meter
; NMI_START/LENGHT  next sample address/length for NMI reprogramming
; START_0/LENGHT_0  first half of the sample (address/length)
; START_1/LENGHT_1  second half (loop part)
; S_MAP             memory page for DMA
; N_NOTE            note byte from the pattern (with octave)
; N_SAMPLE          instrument number
; N_VOLUME          volume from the note (0x41 = "use instrument default")
; N_COMAND          effect command
; N_PARAM           effect parameter
; PAT_POINT         current row within the pattern (0..63)
; ADR_PAT           pointer to the current pattern row
; =============================================================================

; ============================ Adapter ports ==================================

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

DMAP_A      EQU     0FBD0H          ; memory-page mapper, channel A (4 bytes)
DMAP_B      EQU     0FBD4H          ; channel B (4 bytes)
DMAP_C      EQU     0FBD8H          ; channel C (4 bytes)
DMAP_D      EQU     0FBDCH          ; channel D (4 bytes)

; ============================== Interrupts ===================================

INT_H       EQU     38H             ; RST 38h vector (0FD9FH on Aleste)
NMI_H       EQU     66H             ; NMI vector
X_Y         EQU     1401H           ; cursor position (X=14h, Y=01h)

; =========================== Sound variables =================================

DATA        EQU     2000H           ; STM header / sample data base
INST        EQU     2030H           ; instrument table (32 bytes per entry)
ORDER       EQU     2410H           ; order list
I_DIV       EQU     2490H           ; per-instrument divisor table (12 notes each)
T_VIBRATO   EQU     2D00H           ; vibrato waveform (256 bytes)
TEMP_CONT   EQU     2F80H           ; tick counter (row timing)
TEMP_PE     EQU     2F81H           ; ticks per row
F_N_PAT     EQU     2F82H           ; "advance to next order" flag
NEXT_ORD    EQU     2F84H           ; pointer to the next order byte
SEK_ORD     EQU     2F86H           ; pointer to the current order byte
NUM_PART    EQU     2F88H           ; current pattern number
VOL_1234    EQU     2F8CH           ; global volume (from STM header)
SOUND_ON    EQU     2F8EH           ; 0 = paused, 1 = playing
F_PRINT     EQU     2F90H           ; 0 = play, 1 = debug print
F_TEMP      EQU     2F92H           ; "new row just started" flag
STAR_S      EQU     2F94H           ; scroll position, top marquee
STAR_D      EQU     2F96H           ; scroll position, bottom marquee
STAR_M      EQU     2F98H           ; marquee bit-shift mask
D_POINT     EQU     2F9AH           ; pointer into the marquee text

; ---------------------- Per-channel state (0x20 bytes) -----------------------

SEG_A       EQU     3078H           ; channel A state block
SEG_B       EQU     307AH           ; channel B
SEG_C       EQU     307CH           ; channel C
SEG_D       EQU     307EH           ; channel D

; Offsets within a channel state block. Negative values because SEG_x points
; *past* the block (the block occupies [SEG_x-0x78 .. SEG_x+0x08)).
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

NMI_START   EQU     0-0H            ; next sample start (16-bit)
NMI_LENGHT  EQU     8H              ; next sample length (16-bit, +8 from block)

START_0     EQU     10H             ; first half: address
START_1     EQU     18H             ; second half: address
LENGHT_0    EQU     20H             ; first half: length
LENGHT_1    EQU     28H             ; second half: length
S_MAP       EQU     30H             ; DMA memory page

; ---------------------- Parameters decoded from a note -----------------------

N_COMAND    EQU     38H             ; effect command (0..15)
N_VOLUME    EQU     40H             ; volume (0x41 = "instrument default")
N_NOTE      EQU     48H             ; note byte (0xFF = none, 0xFE = key off)
N_SAMPLE    EQU     50H             ; instrument number
N_PARAM     EQU     58H             ; effect parameter

VIB_POINT   EQU     60H             ; vibrato phase
F_ARP       EQU     68H             ; arpeggio active flag
TIM_ARP     EQU     70H             ; arpeggio timer
PIK_VOL     EQU     78H             ; peak volume (VU-meter)

; ======================= Channel start macro =================================
;
; MA_START programs one DMA channel from its state block. It is called once
; per tick (50 Hz) from PRG_INT. The macro is deliberately "lazy": each flag
; (F_START, F_DIV, F_VOL) guards only the part of the setup that actually
; changed, so most ticks do almost nothing.
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

MA_START    MACRO   SEG,STOP,DMA,TIM,DST,BMOD,PVOL,DMAP
            LOCAL   MA_0,MA_1,MA_2,MA_3,MA_4,MA_5,MA_6,MA_7,MAQU

            ; --- 1. Force-off path: silence the channel and skip the rest ---
            LD      A,(SEG+F_CH_ON)
            OR      A
            JR      Z,MA_0

            LD      A,STOP
            LD      BC,DMAMASK
;           OUT     (C),A                   ; (commented out in original)
            LD      BC,PVOL
            LD      A,40H                   ; 0x40 = "max/special" = silence
            OUT     (C),A
            JP      MAQU

MA_0:       ; --- 2. Start path: program DMA address and length ---
            LD      A,(F_START+SEG)
            OR      A
            JR      Z,MA_2

            LD      A,STOP
            LD      BC,DMAMASK
            OUT     (C),A                   ; mask the channel before reconfig
            LD      A,(F_LOOP+SEG)
            LD      (F_RESTART+SEG),A       ; arm NMI reprogramming if looping
            OR      A
            JR      Z,MA_1

            ; Two-part sample: save the loop half for the NMI handler
            LD      HL,(START_1+SEG)
            LD      (NMI_START+SEG),HL
            LD      HL,(LENGHT_1+SEG)
            LD      (NMI_LENGHT+SEG),HL

MA_1:       LD      BC,DMA
            LD      HL,(START_0+SEG)
            OUT     (C),L                   ; 8237 base address, low byte
            OUT     (C),H                   ; high byte
            INC     C
            LD      HL,(LENGHT_0+SEG)
            OUT     (C),L                   ; 8237 count, low byte
            OUT     (C),H                   ; high byte

MA_2:       ; --- 3. Timer divisor update ---
            LD      A,(F_DIV+SEG)
            OR      A
            JR      Z,MA_3

            LD      BC,TIM
            LD      HL,(SNG_DIV+SEG)
            OUT     (C),L
            OUT     (C),H

MA_3:       ; --- 4. Volume update + peak tracking for the VU-meter ---
            LD      A,(F_VOL+SEG)
            OR      A
            JR      Z,MA_6

            LD      A,(SNG_VOL+SEG)
            SUB     1
            JR      Z,MA_5                  ; sng_vol == 1 -> 0x40
            JR      NC,MA_4                 ; sng_vol >= 2 -> as is

MA_5:       LD      A,40H                   ; sng_vol == 0 -> 0x40 (max/special)
MA_4:       LD      BC,PVOL
            OUT     (C),A
            AND     3FH                     ; low 6 bits = actual volume
            LD      L,A
            LD      A,(PIK_VOL+SEG)
            CP      L
            JR      NC,MA_6                 ; peak already higher
            LD      A,L
            LD      (PIK_VOL+SEG),A         ; raise the peak

MA_6:       ; --- 5. Page mapper + mode + unmask (only on start) ---
            LD      A,(F_START+SEG)
            OR      A
            JR      Z,MAQU

            LD      BC,DMAP
            LD      A,(S_MAP+SEG)
            CPL                             ; page number is stored inverted
            OUT     (C),A
            INC     C
            DEC     A
            OUT     (C),A
            INC     C
            DEC     A
            OUT     (C),A
            INC     C
            DEC     A
            OUT     (C),A                   ; 4 consecutive pages per channel

            LD      BC,DMAMOD
            LD      A,BMOD                   ; 48h/49h/4Ah/4Bh
            OUT     (C),A
            LD      BC,DMAMASK
            LD      A,DST                    ; 0..3 = unmask -> start
            OUT     (C),A

MAQU:       ; --- 6. Clear all one-shot flags ---
            SUB     A
            LD      (F_START+SEG),A
            LD      (F_DIV+SEG),A
            LD      (F_VOL+SEG),A
            LD      (F_LOOP+SEG),A
            LD      (F_CH_ON+SEG),A
            ENDM

; ========================== NMI macro ========================================
;
; MA_NMI is invoked once per channel from the NMI handler (called by the
; 8237 when a transfer completes). RRC E shifts the 8237 status byte right,
; so the carry flag carries TC bit for the current channel. If the bit is
; set and the channel is armed (F_RESTART), reprogram the DMA address and
; length to the loop half and re-enable the channel in autoinit mode.
;
; C equivalent (per channel):
;
;   if (tc_bit) {
;       if (c->restart) {
;           out(dma,   c->nmi_start);
;           out(dma+1, c->nmi_length);
;           c->restart = 0;
;           out(DMAMOD,  bmod | 0x10);      // autoinit enable
;           out(DMAMASK, dst);              // unmask -> restart
;       }
;   }

MA_NMI      MACRO   SEG1,DMA1,DMOD1,DST1
            LOCAL   MA_QUIT
            RRC     E                       ; shift next TC bit into carry
            JR      NC,MA_QUIT              ; no TC for this channel
            LD      A,(F_RESTART+SEG1)
            OR      A
            JR      Z,MA_QUIT               ; not armed for restart

            LD      HL,(NMI_START+SEG1)
            LD      BC,DMA1
            OUT     (C),L
            OUT     (C),H                   ; new base address
            INC     C
            LD      HL,(NMI_LENGHT+SEG1)
            OUT     (C),L
            OUT     (C),H                   ; new count
            SUB     A
            LD      (F_RESTART+SEG1),A      ; disarm
            LD      BC,DMAMOD
            LD      A,DMOD1                 ; 58h..5Bh = autoinit mode
            OUT     (C),A
            LD      BC,DMAMASK
            LD      A,DST1                  ; unmask -> restart
            OUT     (C),A
MA_QUIT:    NOP
            ENDM

; =========================== BDOS macro =====================================
;
; Thin wrapper around the MSX-DOS BDOS entry (function in C, call 0005h).
; The calling convention is identical to CP/M for the functions used here.

BDOS        MACRO   FUNCTION
            LD      C,FUNCTION
            CALL    5
            ENDM

; ========================== PROGRAM START ===================================

START:      LD      SP,(6)                  ; restore SP from page-zero slot 6
                                            ; (MSX-DOS keeps the caller's SP here)
            CALL    INI_PRT                 ; init 8254 timers + 8237 DMA
            CALL    CLEAR                   ; zero out the work area
            CALL    LOAD                    ; open and parse the .STM file
            CALL    RESTORE                 ; copy init tables, set flags
            CALL    INI_DIV                 ; precompute per-instrument divisors
            LD      A,0
            RST     30H                     ; BIOS: set screen mode
            DB      8,81H,0                 ; mode 81h = 320x200x4, ROM off
            LD      HL,0B800H
            CALL    SET_STAR                ; init top marquee at 0B800h
            LD      HL,0B000H
            CALL    SET_STAR1               ; init bottom marquee at 0B000h
            LD      HL,DEMO
            LD      (D_POINT),HL            ; start of the marquee text
            CALL    SET_INT                 ; hook INT 38h and NMI
            LD      HL,X_Y
            LD      (0FE09H),HL             ; park the BIOS cursor off-screen

; =========================== Player loop =====================================
;
; The main loop runs at whatever speed the CPU can manage; actual timing is
; driven by the 50 Hz INT 38h handler (PRG_INT). Two modes:
;
;   F_PRINT = 1  -> debug print: dump the four current notes to the screen
;   F_PRINT = 0  -> normal play: scroll the marquee, update the VU-meters
;
; Key handling:
;   20h (space)  -> toggle F_PRINT
;   0Dh (CR)     -> force "advance to next order" on the next tick
;   anything else-> stop playback, restore BIOS vectors, return to CP/M
;
; C equivalent (conceptually):
;
;   for (;;) {
;       enable_interrupts();
;       if (print_mode) {
;           if (new_row) { dump_notes(); newline(); }
;       } else {
;           if (new_row) { advance_marquee(); update_vu_meters(); }
;       }
;       switch (poll_key()) {
;           case ' ':  print_mode = !print_mode; break;
;           case '\r': next_order_flag = 1;     break;
;           case 0:    break;                    // no key
;           default:   cleanup_and_exit();
;       }
;   }

LOOP:       EI
            LD      A,(F_PRINT)
            OR      A
            JR      Z,LOP_1                 ; normal play

            ; --- Debug-print mode: dump all four channels' current notes ---
            LD      A,(F_TEMP)
            OR      A
            JP      Z,LOP_2                 ; no new row yet
            SUB     A
            LD      (F_TEMP),A              ; consume the "new row" flag
            LD      IX,SEG_A
            CALL    OUT_PUT                 ; print note, sample, volume, fx
            LD      IX,SEG_B
            CALL    OUT_PUT
            LD      IX,SEG_C
            CALL    OUT_PUT
            LD      IX,SEG_D
            CALL    OUT_PUT
            CALL    ENTER                    ; newline
            JP      LOP_2

LOP_1:      ; --- Normal play mode: advance marquee, redraw VU-meters ---
            LD      A,(F_TEMP)
            OR      A
            JP      LOP_11                  ; no new row yet
            SUB     A
            LD      (F_TEMP),A
            LD      HL,(D_POINT)
            LD      A,(HL)
            INC     HL
            LD      (D_POINT),HL
            CP      1
            JP      Z,DT_0                  ; end-of-text marker
            JP      C,DT_1                  ; any control byte 0 -> restart
            RST     30H                     ; BIOS: output character
            DB      8,18H,0                 ; function 18h = SYMBOL
            EI
            JP      LOP_11
DT_0:       LD      HL,DEMO
            LD      (D_POINT),HL            ; wrap to the start of the text
DT_1:       LD      HL,X_Y
            LD      (0FE09H),HL             ; keep BIOS cursor off-screen

LOP_11:     ; --- Draw the four VU-meter bars ---
            LD      A,(SEG_A+PIK_VOL)
            LD      HL,8004H+19*80          ; row 19, col 4
            CALL    LINE
            LD      A,(SEG_B+PIK_VOL)
            LD      HL,8004H+20*80          ; row 20
            CALL    LINE
            LD      A,(SEG_C+PIK_VOL)
            LD      HL,8004H+21*80          ; row 21
            CALL    LINE
            LD      A,(SEG_D+PIK_VOL)
            LD      HL,8004H+22*80          ; row 22
            CALL    LINE
            CALL    STAR_ON                 ; animate top marquee
            CALL    STAR_ON1                ; animate bottom marquee
            JP      LOP_2

; -----------------------------------------------------------------------------
; LINE
;   Draw a horizontal VU-meter bar of 16 character cells at (HL).
;   Cells [0 .. vol/4] are filled with 0FCh, the rest are cleared.
;   The bar is drawn vertically across 8 raster lines (0x800 stride).
;
; Input:  A  = peak volume (0..63)
;         HL = VRAM address of the bar's left edge (top raster line)
; Output: HL = HL + 1 (advanced past the bar, unused by caller)
; Clobbers: AF, BC, DE, HL
;
; C equivalent:
;
;   void line(uint8_t vol, uint16_t addr) {
;       uint8_t cells = (vol >> 2) & 0x0F;   // 0..15 filled cells
;       for (int i = 0; i <= cells; i++) {
;           vram[addr] = 0xFC;               // filled cell
;           addr += 0x800;                    // next raster line
;       }
;       for (int i = cells + 1; i <= 15; i++) {
;           vram[addr] = 0x00;               // empty cell
;           addr += 0x800;
;       }
;   }
; -----------------------------------------------------------------------------
LINE:       LD      BC,7EC0H                ; Gate Array: select palette index
            OUT     (C),C
            RRCA                            ; A = vol >> 2
            RRCA
            AND     0FH                     ; A = number of filled cells
            LD      B,A
            INC     B                       ; B = filled + 1 (inclusive)
            LD      A,10H                   ; A = 16 - (filled + 1) = empty
            LD      DE,0800H                ; DE = raster-line stride
LDI_0:      LD      (HL),0FCH               ; write filled cell
            ADD     HL,DE
            LD      (HL),0FCH
            ADD     HL,DE
            LD      (HL),0FCH               ; 3 writes per character row
            OR      A
            SBC     HL,DE
            SBC     HL,DE                   ; net advance = +1 stride
            INC     HL
            DEC     A
            DJNZ    LDI_0
            LD      B,A
            INC     B
LDI_1:      LD      (HL),0                     ; clear remaining cells
            ADD     HL,DE
            LD      (HL),0
            ADD     HL,DE
            LD      (HL),0
            OR      A
            SBC     HL,DE
            SBC     HL,DE
            INC     HL
            DJNZ    LDI_1

            LD      BC,7EC6H                ; Gate Array: restore normal mode
            OUT     (C),C
            RET

; -----------------------------------------------------------------------------
; LOP_2
;   Poll the keyboard and dispatch. Runs every iteration of the main loop.
; -----------------------------------------------------------------------------
LOP_2:      RST     30H                     ; BIOS: check keyboard
            DB      08H,08H,00H             ; function 08h = INKEY
            OR      A
            JP      Z,LOOP                  ; no key -> next iteration
            CP      20H                     ; space?
            JR      NZ,LOP_0
            LD      A,(F_PRINT)
            CPL                             ; toggle F_PRINT
            LD      (F_PRINT),A
            SUB     A
            RST     30H                     ; BIOS: clear screen
            DB      8,81H,0
            LD      A,(F_PRINT)
            OR      A
            JP      NZ,LOOP                 ; entered print mode -> loop
            ; exited print mode: reinit marquees and cursor
            LD      HL,0B800H
            CALL    SET_STAR
            LD      HL,0B000H
            CALL    SET_STAR1
            LD      HL,X_Y
            LD      (0FE09H),HL
            JP      LOOP

LOP_0:      CP      0DH                     ; CR?
            JR      NZ,LOP_4
            LD      A,1
            LD      (F_N_PAT),A             ; force "advance to next order"
            JP      LOOP

LOP_4:      
            SUB     A
            LD      (SOUND_ON),A            ; pause the player
            CALL    INI_PRT                 ; silence all DMA channels
            CALL    GET_INT                 ; restore BIOS INT/NMI vectors
            LD      H,40H
            LD      A,5
            ; On MSX-DOS, 0024h is NOT a standard "close file" vector (that
            ; would be BDOS function 10h with DE = FCB). This call may be a
            ; no-op or may hit a BDOS hook table, depending on the MSX-DOS
            ; build. Kept as-is to preserve original behaviour; verify on
            ; real hardware before relying on it.
            CALL    24H                     ; (see note above) close file
            LD      A,0
            RST     30H
            DB      8,81H,0                 ; clear the screen
            RST     0                       ; warm boot back to MSX-DOS

; ------------------------- * * * * * ---------------------------

; -----------------------------------------------------------------------------
; STAR_ON / STAR_ON1
;   Animate the two scrolling marquees. Each call advances the marquee by
;   one pixel (by shifting the bit mask) and redraws it via SS_3 / SS_31.
;
;   STAR_ON  operates on the top marquee (STAR_S, XOR with STAR_M)
;   STAR_ON1 operates on the bottom marquee (STAR_D, XOR with 0x70)
;
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
STAR_ON:    LD      HL,(STAR_S)
            PUSH    HL
            LD      A,(STAR_M)
            PUSH    AF
            RRCA                            ; rotate mask 4 bits right
            RRCA
            RRCA
            RRCA
            LD      (STAR_M),A
            AND     1
            JR      Z,STON_0                ; mask bit 0 = 0 -> no advance
            INC     HL
            LD      A,H
            AND     7
            OR      0B8H                    ; keep within 0B800h..0BFFFh
            LD      (STAR_S),HL
STON_0:     CALL    SS_3                    ; draw with current shift
            POP     AF
            LD      (STAR_M),A
            POP     HL
            CALL    SS_3                    ; draw with restored shift
            LD      A,(STAR_M)
            RRCA
            RRCA
            RRCA
            RRCA                            ; restore the original mask
            LD      (STAR_M),A
            RET

; -----------------------------------------------------------------------------
; SET_STAR
;   Initialise the top marquee: position = HL, mask = 1.
; -----------------------------------------------------------------------------
SET_STAR:   LD      (STAR_S),HL
            LD      A,1
            LD      (STAR_M),A

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
SS_3:       LD      DE,100H                 ; DE = 0x0100 (mirror stride)
            LD      BC,7EC0H                ; Gate Array: palette index
            OUT     (C),C
            LD      B,30H                   ; 30 rows
SS_0:       LD      A,(DE)
            AND     1FH
            ADD     A,20H
            LD      C,A                     ; C = DE offset for this row
            LD      A,B
            LD      B,0
            ADD     HL,BC                   ; HL = HL + offset
            LD      B,A
            LD      A,H
            AND     7
            OR      0B8H                    ; wrap within 0B800h..0BFFFh
            LD      H,A
            LD      A,(STAR_M)
            XOR     (HL)                    ; XOR pixel with mask
            LD      (HL),A
            PUSH    HL
            LD      A,L
            CPL                             ; mirror address: HL -> ~HL
            LD      L,A
            LD      A,H
            CPL
            AND     7
            OR      0B8H
            LD      H,A
            LD      A,(STAR_M)
            XOR     (HL)                    ; XOR at the mirrored address
            LD      (HL),A
            POP     HL
            INC     DE
            DJNZ    SS_0

SS_1:       LD      BC,7EC6H                ; Gate Array: restore normal mode
            OUT     (C),C
            RET

; -----------------------------------------------------------------------------
; STAR_ON1
;   Animate the bottom marquee. Simpler than STAR_ON: it just increments
;   the scroll address and redraws both the current and the previous
;   position (to erase the old copy).
; -----------------------------------------------------------------------------
STAR_ON1:   LD      HL,(STAR_D)
            PUSH    HL
            INC     HL
            LD      A,H
            AND     7
            OR      0B0H                    ; keep within 0B000h..0B7FFh
            LD      (STAR_D),HL
            CALL    SS_31                   ; draw new position
            POP     HL
            CALL    SS_31                   ; draw (erase) old position
            RET

; -----------------------------------------------------------------------------
; SET_STAR1
;   Initialise the bottom marquee position = HL.
; -----------------------------------------------------------------------------
SET_STAR1:  LD      (STAR_D),HL

; -----------------------------------------------------------------------------
; SS_31
;   Draw the bottom marquee at (HL). Same structure as SS_3, but XORs with
;   a fixed 0x70 pattern instead of STAR_M.
;
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
SS_31:      LD      DE,100H
            LD      BC,7EC0H
            OUT     (C),C
            LD      B,30H
SS_01:      LD      A,(DE)
            AND     1FH
            ADD     A,20H
            LD      C,A
            LD      A,B
            LD      B,0
            ADD     HL,BC
            LD      B,A
            LD      A,H
            AND     7
            OR      0B0H
            LD      H,A
            LD      A,(HL)
            XOR     70H                     ; fixed XOR pattern for bottom
            LD      (HL),A
            PUSH    HL
            LD      A,L
            CPL
            LD      L,A
            LD      A,H
            CPL
            AND     7
            OR      0B8H                    ; mirror goes to the top half
            LD      H,A
            LD      A,(HL)
            XOR     70H
            LD      (HL),A
            POP     HL
            INC     DE
            DJNZ    SS_01

SS_11:      LD      BC,7EC6H
            OUT     (C),C
            RET

; ======================= Set parameters to start ============================
;
; CLEAR zeroes the work area from DATA (2000h) up to 4000h. This covers the
; STM header, instrument table, order list, divisor table, and all per-channel
; state. Must run before LOAD and RESTORE.
;
; NOTE: 2000h..3FFFh is page 0 on the Aleste. On MSX-DOS page 0 is partly
; system-owned, so this range overlaps with BDOS scratch. The original code
; does this unconditionally; kept as-is. If you port this player to a
; different memory layout, shrink the range or move DATA higher.
;
; C equivalent:
;   memset((void*)0x2000, 0, 0x4000 - 0x2000);

CLEAR:      DI
            LD      HL,DATA
            LD      DE,DATA+1
            LD      BC,4000H-DATA           ; length = 4000h - DATA
            LD      (HL),0                  ; first byte
            LDIR                            ; fill the rest
            RET

; -----------------------------------------------------------------------------
; RESTORE
;   Copy initialisation tables into the work area and set up playback state.
;
;   - TEMP_CONT / TEMP_PE <- tempo from the STM header (DATA+32), min 16, /16
;   - T_VIBRATO          <- 256-byte vibrato waveform (T_VIB_1)
;   - F_N_PAT            <- 1 (force "advance to next order" on first tick)
;   - NEXT_ORD           <- ORDER (start of the order list)
;   - VOL_1234           <- global volume from DATA+34
;   - SOUND_ON           <- 1 (unpause)
;
; Input:  DATA must be filled by LOAD
; Output: playback state initialised
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
RESTORE:    LD      A,(DATA+32)             ; tempo byte from STM header
            CP      16
            JR      NC,RE_0
            LD      A,16                    ; clamp tempo to >= 16
RE_0:       SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; A = tempo / 16 = ticks per row
            LD      (TEMP_CONT),A           ; tick counter
            LD      (TEMP_PE),A             ; ticks per row

            ; NOTE: T_VIB_1 in this dump is 256 bytes (128 words), but RESTORE copies
            ; 0x200 = 512 bytes. Either the original table was 512 bytes (truncated
            ; here) or the extra 256 bytes are harmless padding. Verify against the
            ; original binary before relying on the vibrato waveform shape.
            LD      HL,T_VIB_1
            LD      DE,T_VIBRATO
            LD      BC,200H                 ; 512 bytes = 256 words
            LDIR                            ; copy vibrato waveform

            LD      A,1
            LD      (F_N_PAT),A             ; force order advance on first tick
            LD      HL,ORDER
            LD      (NEXT_ORD),HL           ; start at the first order

            LD      A,(DATA+34)             ; global volume from STM header
            LD      (VOL_1234),A

            LD      A,1
            LD      (SOUND_ON),A            ; unpause
            RET

; ===================== INTERRUPT HANDLER (INT 38h) ==========================
;
; PRG_INT runs at 50 Hz. It is invoked from the RST 38h vector installed by
; SET_INT. The handler:
;
;   1. Saves all registers.
;   2. Polls PPI port B to detect a VSYNC pulse. If VSYNC is present, it
;      additionally calls the NMI handler once (to catch a pending DMA
;      completion that the CPU NMI did not take, e.g. because NMI was
;      masked by an earlier handler).
;   3. Runs MA_START for all four channels (programs DMA / timer / volume
;      if the corresponding flags are set).
;   4. Decrements the row tick counter (TEMP_CONT). If it reaches 0, the
;      row advances: fetch the next note from each channel's pattern,
;      possibly advance the order.
;
; The 50 Hz rate matches the CPC/Aleste raster; music speed is controlled by
; TEMP_PE (ticks per row), set from the STM tempo byte.
;
; C equivalent (conceptually):
;
;   void int38(void) {
;       save_regs();
;       if (ppi_port_b & 0x01) {        // VSYNC present
;           set_rom_bank(0x38);
;           nmi_handler();              // catch pending DMA NMI
;       }
;       ma_start(&seg_a, 4, DMA_A, TIM_A, 0, 0x48, VOL_A, DMAP_A);
;       ma_start(&seg_b, 5, DMA_B, TIM_B, 1, 0x49, VOL_B, DMAP_B);
;       ma_start(&seg_c, 6, DMA_C, TIM_C, 2, 0x4A, VOL_C, DMAP_C);
;       ma_start(&seg_d, 7, DMA_D, TIM_D, 3, 0x4B, VOL_D, DMAP_D);
;
;       if (temp_cont != 0) {
;           temp_cont--;
;           command(&seg_a); command(&seg_b);
;           command(&seg_c); command(&seg_d);
;           restore_regs(); return;
;       }
;       if (!sound_on) { restore_regs(); return; }
;       if (temp_pe != 0) temp_pe--;
;       temp_cont = temp_pe;
;       if (f_n_pat) { f_n_pat = 0; nex_ord(); }
;       next_not(&seg_a); next_not(&seg_b);
;       next_not(&seg_c); next_not(&seg_d);
;       f_temp = 0xFF;                  // signal "new row" to the main loop
;       restore_regs();
;   }

PRG_INT:    PUSH    HL
            PUSH    DE
            PUSH    BC
            PUSH    AF
            PUSH    IX
            PUSH    IY

            ; --- VSYNC detection via PPI port B bit 0 ---
            LD      BC,0F5FFH
            IN      A,(C)
            RRCA                            ; bit 0 -> carry = VSYNC
            JP      C,T_34                  ; VSYNC present -> extra NMI poll
            CALL    NMI                     ; always poll NMI once
            JP      EXIT

T_34:       RST     30H                     ; BIOS: select ROM bank 38h
            DB      8H,38H,0H
            ; Purpose of BIOS function 38h is undocumented here. By context
            ; (VSYNC branch, before NMI poll) it likely relates to ROM bank
            ; selection or interrupt acknowledge. Treat as a black box.

            CALL    NMI                     ; poll NMI on VSYNC

            ; --- Program all four DMA channels from their state blocks ---
            MA_START    SEG_A,4,DMA_A,TIM_A,0,48H,VOL_A,DMAP_A
            MA_START    SEG_B,5,DMA_B,TIM_B,1,49H,VOL_B,DMAP_B
            MA_START    SEG_C,6,DMA_C,TIM_C,2,4AH,VOL_C,DMAP_C
            MA_START    SEG_D,7,DMA_D,TIM_D,3,4BH,VOL_D,DMAP_D

            ; --- Row tick counter ---
            LD      A,(TEMP_CONT)
            OR      A
            JR      Z,PR_0                  ; counter expired -> new row
            DEC     A
            LD      (TEMP_CONT),A
            ; mid-row: run per-tick effects on all four channels
            LD      IX,SEG_A
            CALL    COMMAND
            LD      IX,SEG_B
            CALL    COMMAND
            LD      IX,SEG_C
            CALL    COMMAND
            LD      IX,SEG_D
            CALL    COMMAND
            JP      EXIT

PR_0:       LD      A,(SOUND_ON)
            OR      A
            JP      Z,EXIT                  ; playback paused
            LD      A,(TEMP_PE)
            OR      A
            JR      Z,PR_2
            DEC     A
PR_2:       LD      (TEMP_CONT),A           ; reload tick counter
            LD      A,(F_N_PAT)
            OR      A
            JR      Z,PR_3                  ; no order advance requested
            SUB     A
            LD      (F_N_PAT),A
            CALL    NEX_ORD                 ; advance to the next order

PR_3:       ; --- Fetch next note for each channel ---
            LD      IX,SEG_A
            CALL    NEXT_NOT
            LD      IX,SEG_B
            CALL    NEXT_NOT
            LD      IX,SEG_C
            CALL    NEXT_NOT
            LD      IX,SEG_D
            CALL    NEXT_NOT
            LD      A,0FFH
            LD      (F_TEMP),A              ; signal "new row" to main loop

EXIT:       POP     IY
            POP     IX
            POP     AF
            POP     BC
            POP     DE
            POP     HL
            EI
BUF_INT:    DB      0,0,0,0                 ; saved original INT 38h vector
            RET

; ======================= Note parameter fetch ================================
;
; NEXT_NOT
;   Advance one channel by one row: read the 4-byte note record from the
;   pattern, decode it into N_NOTE / N_SAMPLE / N_VOLUME / N_COMAND / N_PARAM,
;   call GET_NOT to prepare DMA parameters, and handle arpeggio setup for
;   command 10 (arpeggio).
;
; Pattern row format (4 bytes per channel, 4 channels = 16 bytes per row):
;   byte 0: note byte (with octave in high nibble; 0xFF = no note,
;           0xFE = key off)
;   byte 1: bits 7..3 = instrument number, bits 2..0 = high 3 bits of volume
;   byte 2: bits 7..3 = low 5 bits of volume, bits 3..0 = command
;   byte 3: command parameter
;
; Note records are stored contiguously; ADR_PAT points to the next row for
; this channel. Every 4 channels share the same row offset, so each call
; advances ADR_PAT by 16 bytes.
;
; C equivalent (per channel):
;
;   void next_not(chan_t *c) {
;       c->pat_point++;
;       if (c->pat_point >= 64) f_n_pat = 1;   // pattern ended
;       uint8_t *p = c->adr_pat;
;       c->n_note   = p[0];
;       c->n_sample = p[1] >> 3;
;       c->n_volume = ((p[2] >> 1) & 0x78) | (p[1] & 0x07);
;       c->n_comand = p[2] & 0x0F;
;       c->n_param  = p[3];
;       c->adr_pat += 16;
;       get_not(c);
;       if (c->n_comand == 9)  command(c);
;       else if (c->n_comand == 10) {
;           c->f_arp = 1;
;           c->tim_arp = c->n_param >> 4;
;       }
;   }

NEXT_NOT:   INC     (IX+PAT_POINT)
            LD      A,(IX+PAT_POINT)
            CP      40H                     ; 64 rows per pattern
            JR      C,NEX_0                 ; pattern not finished
            LD      A,1
            LD      (F_N_PAT),A             ; signal "advance order"
NEX_0:      LD      L,(IX+ADR_PAT)
            LD      H,(IX+ADR_PAT+1)
            PUSH    HL
            POP     IY                      ; IY = pointer to the row
            LD      A,(IY+0)
            LD      (IX+N_NOTE),A           ; note byte
            LD      A,(IY+1)
            SRL     A
            SRL     A
            SRL     A
            LD      (IX+N_SAMPLE),A         ; instrument number
            LD      A,(IY+1)
            AND     7
            LD      L,A
            LD      A,(IY+2)
            RRCA
            AND     78H
            OR      L
            LD      (IX+N_VOLUME),A         ; combined 8-bit volume
            LD      A,(IY+2)
            AND     0FH
            LD      (IX+N_COMAND),A         ; command nibble
            LD      A,(IY+3)
            LD      (IX+N_PARAM),A          ; parameter
            PUSH    IY
            POP     HL
            LD      DE,10H
            ADD     HL,DE                   ; advance to next row (16 bytes)
            LD      (IX+ADR_PAT),L
            LD      (IX+ADR_PAT+1),H
            CALL    GET_NOT
            LD      A,(IX+N_COMAND)
            CP      9
            JP      NZ,CG_0
            CALL    COMMAND                 ; command 9 = tremor, run now
            RET
CG_0:       CP      10
            RET     NZ
            LD      (IX+F_ARP),1            ; command 10 = arpeggio
            LD      A,(IX+N_PARAM)
            AND     0F0H
            SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; high nibble = arpeggio period
            LD      (IX+TIM_ARP),A
            RET

; ================== Prepare DMA parameters ===================================
;
; GET_NOT
;   Decode the current note into per-channel DMA parameters:
;     - volume (from note or instrument default)
;     - instrument start address and length (first half and loop half)
;     - DMA memory page (S_MAP)
;     - timer divisor (from the per-instrument I_DIV table)
;   Then call GOTO to handle branch/loop commands (1, 2, 3).
;
; Special note values:
;   0xFE -> key off (F_CH_ON = 1, channel will be silenced)
;   0xFF -> no note (skip frequency update, keep playing)
;
; Command 7 -> portamento (only update SEK_DIV, not SNG_DIV)
;
; C equivalent:
;
;   void get_not(chan_t *c) {
;       if (c->n_volume < 0x41) {
;           c->sng_vol = c->n_volume;
;           c->sek_vol = c->n_volume;
;           c->f_vol   = 1;
;       }
;       if (c->n_comand == 7) {             // portamento: target only
;           if (c->n_note != 0xFF) {
;               uint16_t d = ret_div(c);
;               c->sek_div = d;
;           }
;           return;
;       }
;       if (c->n_note == 0xFF) { goto_dispatch(c); return; }
;       if (c->n_sample == 0)  { /* fallthrough */ }
;       else {
;           inst_t *ins = &inst[c->n_sample];
;           c->sek_samp = (uint16_t)ins;
;           if (c->n_volume == 0x41) {
;               c->sng_vol = ins->vol;
;               c->sek_vol = ins->vol;
;               c->f_vol   = 1;
;           }
;           c->s_map    = ins->page;
;           c->start_0  = ins->addr;
;           c->lenght_0 = ins->len;
;           if (ins->loop_len) {
;               c->lenght_1 = ins->loop_end - ins->loop_start;
;               c->start_1  = c->start_0 + ins->loop_start;
;               c->f_loop   = 1;
;           }
;           c->f_start  = 1;
;       }
;       if (c->n_note == 0xFE) { c->f_ch_on = 1; }
;       else if (c->n_note != 0xFF) {
;           uint16_t d = ret_div(c);
;           c->sek_div = c->sng_div = d;
;           c->f_div   = 1;
;       }
;       goto_dispatch(c);
;   }

GET_NOT:    LD      A,(IX+N_VOLUME)         ; volume from the note
            CP      41H                     ; 0x41 = "use instrument default"
            JR      NC,GET_0

            LD      (IX+SNG_VOL),A
            LD      (IX+SEK_VOL),A
            LD      (IX+F_VOL),1

GET_0:      LD      A,(IX+N_COMAND)
            CP      7
            JP      Z,GET_2                 ; command 7 = portamento

            LD      A,(IX+N_NOTE)
            CP      0FFH
            JP      Z,GET_7                 ; no note -> just dispatch GOTO
            LD      A,(IX+N_SAMPLE)
            OR      0
            JP      Z,GET_3                 ; instrument 0 -> no sample
            ; --- Locate the instrument header (32 bytes per entry) ---
            LD      L,A
            LD      H,0
            ADD     HL,HL                   ; *2
            ADD     HL,HL                   ; *4
            ADD     HL,HL                   ; *8
            ADD     HL,HL                   ; *16
            ADD     HL,HL                   ; *32
            LD      DE,INST-32              ; start of the instrument table
            ADD     HL,DE
            PUSH    HL
            POP     IY
            LD      (IX+SEK_SAMP),L
            LD      (IX+SEK_SAMP+1),H       ; save pointer to the header
            LD      A,(IX+N_VOLUME)
            CP      41H
            JR      NZ,GET_4
            LD      A,(IY+16H)              ; volume from the instrument
            LD      (IX+SNG_VOL),A
            LD      (IX+SEK_VOL),A
            LD      (IX+F_VOL),1
GET_4:
            ; --- Sample start address (offset by 0x49 for the STM header) ---
            LD      L,(IY+0EH)
            LD      H,(IY+0FH)              ; address in the instrument's memory
            LD      DE,49H                  ; STM header size
            OR      A
            SBC     HL,DE                   ; subtract header
            LD      A,H
            ADD     HL,HL                   ; *2
            ADD     HL,HL                   ; *4
            ADD     HL,HL                   ; *8
            ADD     HL,HL                   ; *16
            RES     6,H
            RES     7,H                     ; mask to page offset
            SRL     A
            SRL     A
            ADD     A,0AH                   ; page number for DMA
            LD      (IX+S_MAP),A
            LD      (IX+START_0),L
            LD      (IX+START_0+1),H
            ; --- Loop length and loop start ---
            LD      L,(IY+14H)
            LD      H,(IY+15H)              ; loop end
            INC     HL
            LD      A,L
            OR      H
            JR      Z,GET_5                 ; no loop (both zero after INC)
            DEC     HL
            LD      (IX+LENGHT_0),L
            LD      (IX+LENGHT_0+1),H       ; first length = loop end
            LD      E,(IY+12H)
            LD      D,(IY+13H)              ; loop start
            OR      A
            SBC     HL,DE                   ; loop length = end - start
            LD      (IX+LENGHT_1),L
            LD      (IX+LENGHT_1+1),H
            LD      L,(IX+START_0)
            LD      H,(IX+START_0+1)
            ADD     HL,DE                   ; loop start address = start + off
            LD      (IX+START_1),L
            LD      (IX+START_1+1),H
            LD      (IX+F_LOOP),1
            JR      GET_31
GET_5:      LD      L,(IY+10H)
            LD      H,(IY+11H)              ; sample length
            LD      (IX+LENGHT_0),L
            LD      (IX+LENGHT_0+1),H
GET_31:     LD      (IX+F_START),1

GET_3:      LD      A,(IX+N_NOTE)
            CP      0FEH
            JR      NZ,GET_6
            LD      (IX+F_CH_ON),1          ; key off -> disable the channel
            JP      GET_7
GET_6:      CP      0FFH
            JR      Z,GET_7
            CALL    RET_DIV                 ; compute timer divisor
            LD      (IX+SEK_DIV),L
            LD      (IX+SEK_DIV+1),H
            LD      (IX+SNG_DIV),L
            LD      (IX+SNG_DIV+1),H
            LD      (IX+F_DIV),1
GET_7:      CALL    GOTO
            RET

; Note portamento: command 7 sets the target divisor (SEK_DIV) but does not
; apply it immediately. The actual slide is performed by N_PORT over many ticks.
GET_2:      LD      A,(IX+N_NOTE)
            CP      0FFH
            RET     Z
            CALL    RET_DIV
            LD      (IX+SEK_DIV),L
            LD      (IX+SEK_DIV+1),H
            RET

; -----------------------------------------------------------------------------
; RET_DIV
;   Compute the timer divisor for the current note.
;
;   The divisor table for each instrument is at (SEK_SAMP + 0x490 - 0x30),
;   indexed by (note & 0x0F) * 2 (12 entries per octave). The octave part of
;   the note (high nibble) selects a right shift (divisor = base >> octave).
;
; Input:  IX = channel state, N_NOTE must be set
;         SEK_SAMP must point to the instrument header
; Output: HL = timer divisor
; Clobbers: AF, BC, DE, HL
;
; C equivalent:
;
;   uint16_t ret_div(chan_t *c) {
;       uint8_t idx = c->n_note & 0x0F;
;       uint16_t *tbl = (uint16_t*)(c->sek_samp + 0x490 - 0x30);
;       uint16_t d = tbl[idx];
;       uint8_t oct = (c->n_note >> 4) & 7;
;       return d >> oct;
;   }
; -----------------------------------------------------------------------------
RET_DIV:    PUSH    AF
            AND     0FH                     ; note within octave
            LD      L,A
            LD      H,0
            ADD     HL,HL                   ; *2 (word index)
            LD      E,(IX+SEK_SAMP)
            LD      D,(IX+SEK_SAMP+1)       ; DE = instrument header
            ADD     HL,DE
            LD      DE,490H-30H             ; divisor table offset
            ADD     HL,DE
            LD      E,(HL)
            INC     HL
            LD      D,(HL)                  ; DE = base divisor
            EX      DE,HL                   ; HL = base divisor
            POP     AF
            SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; A = octave
            AND     7
            RET     Z                       ; octave 0 -> no shift
            LD      B,A
RED_0:      SRL     H
            RR      L                       ; HL >>= 1
            DJNZ    RED_0
            RET

; ================== Branch and loop commands ================================
;
; GOTO
;   Handle commands 1, 2, 3 from the note record. Commands 4..10 are
;   handled by COMMAND (called separately from PRG_INT for mid-row
;   effects, and from NEXT_NOT for command 9/10 on the row boundary).
;
;   Command 1 (TEMPO): set ticks-per-row from the parameter (min 16, /16).
;   Command 2 (JUMP):  set NEXT_ORD to ORDER + parameter (absolute jump).
;   Command 3 (BREAK): force "advance to next order" on the next row.
;
; Input:  IX = channel state
; Clobbers: AF, DE, HL
;
; C equivalent:
;
;   void goto_dispatch(chan_t *c) {
;       uint8_t p = c->n_param;
;       switch (c->n_comand) {
;           case 1: if (p < 16) p = 16;
;                   temp_pe = temp_cont = p >> 4;
;                   break;
;           case 2: next_ord = ORDER + p;
;                   break;
;           case 3: f_n_pat = 1;
;                   break;
;       }
;   }

GOTO:       LD      A,(IX+N_PARAM)
            LD      E,A
            LD      A,(IX+N_COMAND)
            CP      1
            JR      Z,TEMP
            CP      2
            JR      Z,JMP
            CP      3
            JR      Z,BREAK
            RET
TEMP:       LD      A,E
            CP      16
            JR      NC,TE_0
            LD      A,16                     ; clamp to minimum 16
TE_0:       SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; A = tempo / 16
            LD      (TEMP_PE),A
            LD      (TEMP_CONT),A
            RET
JMP:        LD      D,0
            LD      HL,ORDER
            ADD     HL,DE                   ; HL = ORDER + param
            LD      (NEXT_ORD),HL
            RET
BREAK:      LD      A,1
            LD      (F_N_PAT),A             ; force order advance
            RET

; ======================== Musical effects ===================================
;
; COMMAND
;   Run the per-tick effect for the current command on the channel.
;   Called every tick (mid-row) from PRG_INT for all four channels, and
;   once on the row boundary from NEXT_NOT for commands 9/10.
;
;   Command 4: volume slide       -> SLIDE
;   Command 5: portamento down    -> POR_DOW
;   Command 6: portamento up      -> POR_UP
;   Command 7: note portamento    -> N_PORT
;   Command 8: vibrato            -> VIBRATO
;   Command 9: tremor             -> TREMOR
;   Command 10: arpeggio          -> ARPEJO (commented out in original)
;
;   Also decays PIK_VOL (peak VU-meter level) by 1 every call, so the bars
;   fall back after a note ends.
;
; Clobbers: AF, BC, DE, HL (varies by effect)
;
; C equivalent:
;
;   void command(chan_t *c) {
;       if (c->pik_vol) c->pik_vol--;
;       uint8_t p = c->n_param;
;       switch (c->n_comand) {
;           case 4:  slide(c, p);   break;
;           case 5:  por_dow(c, p); break;
;           case 6:  por_up(c, p);  break;
;           case 7:  n_port(c, p);  break;
;           case 8:  vibrato(c, p); break;
;           case 9:  tremor(c, p);  break;
;           /* case 10: arpejo(c, p); break; */  // commented out in original
;           default: c->tim_trem = 0; c->on_off = 1; c->vib_point = 0;
;       }
;   }

COMMAND:    LD      A,(IX+PIK_VOL)
            OR      A
            JR      Z,PI_8
            DEC     A
            LD      (IX+PIK_VOL),A          ; decay VU-meter peak

PI_8:       LD      A,(IX+N_PARAM)
            LD      L,A
            LD      A,(IX+N_COMAND)

            CP      4
            JP      Z,SLIDE
            CP      5
            JP      Z,POR_DOW
            CP      6
            JP      Z,POR_UP
            CP      9
            JP      Z,TREMOR
            LD      (IX+TIM_TREM),0         ; not tremor -> reset its state
            LD      (IX+ON_OFF),1
            CP      7
            JP      Z,N_PORT
            CP      8
            JP      Z,VIBRATO
            LD      (IX+VIB_POINT),0        ; not vibrato -> reset its phase
            CP      10
;???????    JP      Z,ARPEJO                 ; arpeggio dispatch disabled
            RET

; ------------------------- Portamento up ------------------------------------
;
; Decrease the divisor (higher pitch) by the parameter amount each tick.
; Marks F_DIV so the new divisor is pushed to the 8254 on the next MA_START.
;
; C equivalent:
;   void por_up(chan_t *c, uint8_t p) {
;       c->sng_div -= p;
;       c->f_div = 1;
;   }

POR_UP:     LD      H,0
            LD      E,(IX+SNG_DIV)
            LD      D,(IX+SNG_DIV+1)
            EX      DE,HL                   ; HL = divisor
            OR      A
            SBC     HL,DE                   ; HL = divisor - param
            LD      (IX+SNG_DIV),L
            LD      (IX+SNG_DIV+1),H
            LD      (IX+F_DIV),1
            RET

; ------------------------- Portamento down ----------------------------------
;
; Increase the divisor (lower pitch) by the parameter amount each tick.
;
; C equivalent:
;   void por_dow(chan_t *c, uint8_t p) {
;       c->sng_div += p;
;       c->f_div = 1;
;   }

POR_DOW:    LD      H,0
            LD      E,(IX+SNG_DIV)
            LD      D,(IX+SNG_DIV+1)
            ADD     HL,DE                   ; HL = divisor + param
            LD      (IX+SNG_DIV),L
            LD      (IX+SNG_DIV+1),H
            LD      (IX+F_DIV),1
            RET

; ----------------------- Volume slide ---------------------------------------
;
; If the low nibble of the parameter is nonzero, slide down by that amount.
; Otherwise, slide up by (parameter >> 4). Volume is clamped to 0 and 0x40.
;
; C equivalent:
;   void slide(chan_t *c, uint8_t p) {
;       c->f_vol = 1;
;       if (p & 0x0F) {
;           uint8_t d = p & 0x0F;
;           c->sng_vol = (c->sng_vol >= d) ? c->sng_vol - d : 0;
;       } else {
;           uint8_t u = p >> 4;
;           c->sng_vol = min(c->sng_vol + u, 0x40);
;       }
;   }

SLIDE:      LD      (IX+F_VOL),1
            LD      A,L
            AND     0FH
            JR      Z,V_UP                  ; low nibble zero -> slide up
            LD      L,A
            LD      A,(IX+SNG_VOL)
            SUB     L
            LD      (IX+SNG_VOL),A
            RET     NC
            LD      (IX+SNG_VOL),0          ; clamp to 0
            RET

V_UP:       LD      A,L
            SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; A = parameter >> 4
            LD      L,A
            LD      A,(IX+SNG_VOL)
            ADD     A,L
            LD      (IX+SNG_VOL),A
            CP      41H
            RET     C
            LD      (IX+SNG_VOL),40H        ; clamp to 0x40
            RET

; ------------------------------ Tremor --------------------------------------
;
; Rapidly toggle volume between SEK_VOL and 0. The parameter nibbles give
; the on-time (low nibble) and off-time (high nibble) in ticks.
;
; C equivalent:
;   void tremor(chan_t *c, uint8_t p) {
;       if (c->tim_trem) { c->tim_trem--; return; }
;       if (c->on_off == 1) {
;           c->on_off = 0;
;           c->sng_vol = 0;
;           c->tim_trem = p & 0x0F;
;       } else {
;           c->on_off = 1;
;           c->sng_vol = c->sek_vol;
;           c->tim_trem = p >> 4;
;       }
;   }

TREMOR:     LD      A,(IX+TIM_TREM)
            OR      A
            JR      Z,TR_0
            DEC     A
            LD      (IX+TIM_TREM),A
            RET
TR_0:       LD      A,(IX+ON_OFF)
            CP      1
            JR      Z,TR_1
            LD      (IX+ON_OFF),1
            LD      A,(IX+SEK_VOL)
            LD      (IX+SNG_VOL),A          ; restore saved volume
            LD      A,L
            SRL     A
            SRL     A
            SRL     A
            SRL     A                       ; high nibble -> on-time
            LD      (IX+TIM_TREM),A
            RET
TR_1:       LD      (IX+ON_OFF),0
            LD      (IX+SNG_VOL),0          ; silence during off phase
            LD      A,L
            AND     0FH                     ; low nibble -> off-time
            LD      (IX+TIM_TREM),A
            RET

; ------------------------- Arpeggio -----------------------------------------
;
; NOTE: this routine is present but the dispatch is commented out in
; COMMAND (see ";??????? JP Z,ARPEJO"). Kept for reference.
;
; Rapidly alternate the divisor between the current note and a shifted
; version, producing a chord-like effect. The parameter's low nibble
; selects the shift amount.

ARPEJO:     LD      A,(IX+F_ARP)
            OR      A
            RET     Z                       ; arpeggio not active
            LD      A,(IX+TIM_ARP)
            OR      A
            JR      Z,AR_0
            DEC     A
            LD      (IX+TIM_ARP),A
            RET
AR_0:       LD      H,0
            LD      A,L
            LD      A,0FH                   ; ??? hardcoded shift amount
            LD      L,A
            EX      DE,HL
            LD      L,(IX+SEK_DIV)
            LD      H,(IX+SEK_DIV+1)
            OR      A
            SBC     HL,DE                   ; divisor - shift
            LD      (IX+SNG_DIV),L
            LD      (IX+SNG_DIV+1),H
            LD      (IX+F_DIV),1
            LD      (IX+F_ARP),0
            RET
            RST     18H                     ; unreachable (padding?)
            RST     18H
            RST     18H

; -------------------------- Note portamento ---------------------------------
;
; Slide SNG_DIV toward SEK_DIV (the target set by command 7) by the
; parameter amount each tick, until they meet.
;
; C equivalent:
;   void n_port(chan_t *c, uint8_t p) {
;       uint16_t cur = c->sng_div, tgt = c->sek_div;
;       if (cur == tgt) return;
;       if (cur < tgt) {                 // slide up (increase divisor)
;           cur += p;
;           if (cur > tgt) cur = tgt;
;       } else {                          // slide down (decrease divisor)
;           cur -= p;
;           if (cur < tgt) cur = tgt;
;       }
;       c->sng_div = cur;
;       c->f_div = 1;
;   }

N_PORT:     LD      E,(IX+SNG_DIV)
            LD      D,(IX+SNG_DIV+1)
            LD      L,(IX+SEK_DIV)
            LD      H,(IX+SEK_DIV+1)
            OR      A
            PUSH    HL
            SBC     HL,DE                   ; target - current
            POP     HL
            RET     Z                       ; already at target
            JP      C,PORT_2                ; current > target -> slide down

PORT_0:     ; current < target -> slide up
            LD      C,(IX+N_PARAM)
            LD      B,0
            EX      DE,HL
            ADD     HL,BC                   ; cur += p
            EX      DE,HL
            OR      A
            PUSH    HL
            SBC     HL,DE                   ; new - target
            POP     HL
            JR      NC,PORT_1               ; overshoot -> clamp
            EX      DE,HL
PORT_1:     LD      (IX+SNG_DIV),E
            LD      (IX+SNG_DIV+1),D
            LD      (IX+F_DIV),1
            RET

PORT_2:     ; current > target -> slide down
            LD      C,(IX+N_PARAM)
            LD      B,0
            EX      DE,HL
            OR      A
            SBC     HL,BC                   ; cur -= p
            EX      DE,HL
            OR      A
            PUSH    HL
            SBC     HL,DE                   ; new - target
            POP     HL
            JR      C,PORT_3                ; overshoot -> clamp
            EX      DE,HL
PORT_3:     LD      (IX+SNG_DIV),E
            LD      (IX+SNG_DIV+1),D
            LD      (IX+F_DIV),1
            RET

; ----------------------------- Vibrato --------------------------------------
;
; Modulate the divisor by a waveform sample from T_VIBRATO. The phase
; (VIB_POINT) advances by (phase >> 4) + 1 each call, wrapping at 0x7F.
; The waveform is signed, scaled by (param & 0x0F) + 1.
;
; C equivalent:
;   void vibrato(chan_t *c, uint8_t p) {
;       uint8_t phase = c->vib_point;
;       int16_t w = (int16_t)T_VIBRATO[(phase >> 1) & 0xFF];
;       int16_t scale = (p & 0x0F) + 1;
;       int16_t delta = w;
;       for (int i = 0; i < scale; i++) delta >>= 1;   // I_2 is arithmetic >>1
;       c->sng_div = c->sek_div + delta * scale;
;       c->vib_point = (phase + (phase >> 4) + 1) & 0x7F;
;       c->f_div = 1;
;   }
;
; NOTE: the exact scaling in the original is unusual (six CALL I_2 followed
; by a multiply-by-B loop). The C above is an approximation; see the asm
; for the precise sequence.

VIBRATO:    LD      H,(IX+VIB_POINT)
            LD      E,H
            LD      D,0
            PUSH    HL
            LD      A,L
            AND     0FH
            INC     A
            LD      B,A                     ; B = (phase & 0x0F) + 1
            EX      DE,HL
            SRA     H
            RR      L                       ; HL = phase / 2 (signed)
            ADD     HL,HL                   ; HL = (phase / 2) * 2 = word idx
            LD      DE,T_VIBRATO
            ADD     HL,DE
            LD      E,(HL)
            INC     HL
            LD      D,(HL)                  ; DE = waveform sample (signed)
            CALL    I_2
            CALL    I_2
            CALL    I_2
            CALL    I_2
            CALL    I_2
            CALL    I_2                     ; scale the sample down 6 times
            LD      HL,0

VIB_1:      ADD     HL,DE
            DJNZ    VIB_1                   ; HL = scaled * B
            EX      DE,HL
            LD      L,(IX+SEK_DIV)
            LD      H,(IX+SEK_DIV+1)
            ADD     HL,DE                   ; divisor + scaled offset
            LD      (IX+SNG_DIV),L
            LD      (IX+SNG_DIV+1),H
            POP     HL
            LD      A,H
            SRL     L
            SRL     L
            SRL     L
            SRL     L
            ADD     A,L                     ; phase += (phase >> 4)
            INC     A
            AND     7FH                     ; wrap at 0x7F
            LD      (IX+VIB_POINT),A
            LD      (IX+F_DIV),1
            RET
I_2:        SRA     D
            RR      E                       ; DE >>= 1 (arithmetic)
            RET     NC
            INC     DE                      ; round toward zero
            RET

; ==================== Advance to next order =================================
;
; NEX_ORD
;   Move NEXT_ORD to the next order byte and reconfigure the four pattern
;   pointers (ADR_PAT) to point at the new pattern's first row.
;
;   Order byte format: high nibble = pattern number, low nibble = ??? (unused
;   in this player, but preserved in NUM_PART). 0x63 is the end-of-song marker;
;   on 0x63 the player wraps to the start of ORDER and forces all channels off.
;
;   Side effects:
;     - SEG_x + F_CH_ON set to 1 on song end (silences all channels)
;     - writes to port 07DFFh: bits 7..6 = 0xC0 (RAM/ROM banking?)
;     - sets SEG_x + ADR_PAT to the new pattern base
;     - resets PAT_POINT for all channels
;
; C equivalent:
;
;   void nex_ord(void) {
;       if (f_print) enter();               // newline in debug print mode
;       uint8_t *p = next_ord;
;       uint8_t ord = *p;
;       if (ord == 0x63) {                   // end of song
;           p = ORDER;
;           seg_a.f_ch_on = seg_b.f_ch_on = 1;
;           seg_c.f_ch_on = seg_d.f_ch_on = 1;
;           ord = *p;
;       }
;       sek_ord = p++;
;       next_ord = p;
;       num_part = ord;
;       uint8_t pat = (ord >> 4) + 0x0A;    // pattern number -> page
;       *(uint8_t*)0xF342 = pat;            // side effect: BIOS/BDOS variable
;       out(0x7DFF, pat | 0xC0);            // bank select?
;       uint8_t *base = (uint8_t*)(0x4000 | ((pat << 2) & 0x3FFF));
;       seg_a.adr_pat = base + 0;
;       seg_b.adr_pat = base + 4;
;       seg_c.adr_pat = base + 8;
;       seg_d.adr_pat = base + 12;
;       seg_a.pat_point = seg_b.pat_point = 0;
;       seg_c.pat_point = seg_d.pat_point = 0;
;   }

NEX_ORD:    LD      A,(F_PRINT)
            OR      A
            CALL    NZ,ENTER                ; newline if in debug mode
            LD      HL,(NEXT_ORD)
            LD      A,(HL)
            CP      63H                     ; end-of-song marker
            JR      NZ,NEX_O_0
            LD      HL,ORDER                ; wrap to start
            LD      A,1
            LD      (SEG_A+F_CH_ON),A       ; silence all channels on wrap
            LD      (SEG_B+F_CH_ON),A
            LD      (SEG_C+F_CH_ON),A
            LD      (SEG_D+F_CH_ON),A
            LD      A,(HL)                  ; re-read the first order byte

NEX_O_0:    LD      (SEK_ORD),HL            ; save pointer to current order
            INC     HL
NEX_O_1:    LD      (NEXT_ORD),HL
            LD      (NUM_PART),A            ; save the raw order byte
            LD      H,A
            AND     0F0H                    ; high nibble = pattern number
            SRL     A
            SRL     A
            SRL     A
            SRL     A
            ADD     A,0AH                   ; page = pattern + 0x0A
            LD      (0F342H),A              ; BIOS/BDOS variable? (side effect)
            OR      0C0H                    ; bits 7..6 = 11
            LD      BC,07DFFH
            OUT     (C),A                   ; RAM/ROM bank select
            LD      L,0
            ADD     HL,HL                   ; *2
            ADD     HL,HL                   ; *4
            LD      A,H
            AND     3FH
            OR      40H                     ; force page 1 (0x4000..0x7FFF)
            LD      H,A                     ; HL = pattern base address

            LD      DE,4
            LD      (SEG_A+ADR_PAT),HL      ; ch A at offset 0
            ADD     HL,DE
            LD      (SEG_B+ADR_PAT),HL      ; ch B at offset 4
            ADD     HL,DE
            LD      (SEG_C+ADR_PAT),HL      ; ch C at offset 8
            ADD     HL,DE
            LD      (SEG_D+ADR_PAT),HL      ; ch D at offset 12
            SUB     A
            LD      (PAT_POINT+SEG_A),A     ; reset row counters
            LD      (PAT_POINT+SEG_B),A
            LD      (PAT_POINT+SEG_C),A
            LD      (PAT_POINT+SEG_D),A
            RET

; ========================= PROGRAM NMI ======================================
;
; NMI
;   Handles the 8237 DMA terminal-count interrupt. Reads the 8237 status
;   register (DMACOM) to see which channel(s) finished, then for each armed
;   channel (F_RESTART) reprograms it to the loop half and re-enables it
;   in autoinit mode.
;
;   The MA_NMI macro is invoked four times, once per channel. Each call
;   does RRC E (shifting the next TC bit into carry), so E is consumed
;   bit by bit: bit 0 = channel A, bit 1 = B, bit 2 = C, bit 3 = D.
;
; C equivalent:
;
;   void nmi(void) {
;       uint8_t status = in(DMACOM);
;       for (int ch = 0; ch < 4; ch++) {
;           if (status & (1 << ch)) {
;               if (seg[ch].restart) {
;                   out(dma[ch],   seg[ch].nmi_start);
;                   out(dma[ch]+1, seg[ch].nmi_length);
;                   seg[ch].restart = 0;
;                   out(DMAMOD,  0x58 + ch);   // autoinit mode
;                   out(DMAMASK, ch);          // unmask -> restart
;               }
;           }
;       }
;   }

NMI:        PUSH    HL
            PUSH    DE
            PUSH    BC
            PUSH    AF

            LD      BC,DMACOM
            IN      E,(C)                   ; read TC status bits

            MA_NMI  SEG_A,DMA_A,58H,0H
            MA_NMI  SEG_B,DMA_B,59H,1H
            MA_NMI  SEG_C,DMA_C,5AH,2H
            MA_NMI  SEG_D,DMA_D,5BH,3H

NMI_3:      POP     AF
            POP     BC
            POP     DE
            POP     HL
            RETN

; ================= Set interrupt vectors ====================================
;
; SET_INT
;   Save the current INT 38h and NMI vectors into BUF_INT / BUF_NMI, then
;   install PRG_INT at 0038h and NMI at 0066h.
;
;   BUF_INT is 4 bytes: a 3-byte JP plus a trailing RET (unused, padding).
;
; C equivalent:
;
;   void set_int(void) {
;       memcpy(BUF_INT,  (void*)0x0038, 3);
;       memcpy((void*)0x0038, VECTOR, 3);   // JP PRG_INT
;       memcpy(BUF_NMI,  (void*)0x0066, 3);
;       *(uint8_t*)0x0066 = 0xC3;            // JP opcode
;       *(uint16_t*)0x0067 = (uint16_t)NMI;
;   }

SET_INT:    DI
            LD      HL,INT_H                ; source: 0038h
            ;   BUF_INT is defined in Part 2 (after PRG_INT), not here. It is 4 bytes:
            ;   a 3-byte JP plus a trailing RET (unused, padding)
            LD      DE,BUF_INT              ; destination: saved copy
            LD      BC,3
            LDIR
            LD      HL,VECTOR               ; source: new JP PRG_INT
            LD      DE,INT_H                ; destination: 0038h
            LD      BC,3
            LDIR

            LD      HL,NMI_H                ; source: 0066h
            LD      DE,BUF_NMI              ; destination: saved copy
            LD      BC,3
            LDIR

            LD      A,0C3H                  ; JP opcode
            LD      (NMI_H),A
            LD      HL,NMI
            LD      (NMI_H+1),HL            ; 0067h = NMI
            RET
BUF_NMI:    JP      NMI                     ; default NMI target
VECTOR:     JP      PRG_INT                 ; default INT 38h target
            RET

; ============== Restore interrupt vectors ===================================
;
; GET_INT
;   Restore the original INT 38h and NMI vectors from BUF_INT / BUF_NMI.
;   Called on exit to leave the system as we found it.
;
; C equivalent:
;
;   void get_int(void) {
;       memcpy((void*)0x0038, BUF_INT, 3);
;       memcpy((void*)0x0066, BUF_NMI, 3);
;   }

GET_INT:    DI
            LD      HL,BUF_INT
            LD      DE,INT_H
            LD      BC,3
            LDIR
            LD      HL,BUF_NMI
            LD      DE,NMI_H
            LD      BC,3
            LDIR
            RET

; =================  Initialise division coefficients ========================
;
; INI_DIV
;   Precompute the per-instrument divisor table I_DIV. For each of the
;   31 instruments, IDIV_1 multiplies the 12 standard divisors (ST_DIV)
;   by the instrument's frequency ratio and stores the results in I_DIV.
;
;   Called once at startup, after LOAD has read the STM file.
;
; C equivalent:
;
;   void ini_div(void) {
;       for (int i = 0; i < 31; i++) {
;           idiv_1(&INST[i*32], &I_DIV[i*32]);
;       }
;   }

INI_DIV:    LD      IX,INST                 ; IX = source instrument table
            LD      IY,I_DIV                ; IY = destination divisor table
            LD      DE,20H                  ; 32 bytes per entry
            LD      B,31                    ; 31 instruments
IDIV_0:     PUSH    DE
            PUSH    BC
            CALL    IDIV_1
            POP     BC
            POP     DE
            ADD     IX,DE                   ; advance to next instrument
            ADD     IY,DE
            DJNZ    IDIV_0
            RET

; ==================== Compute division coefficient ==========================
;
; IDIV_1
;   For one instrument:
;     1. Read the instrument's frequency (INS+18h/19h) and compute
;        ratio = instrument_freq / 0x2100 (standard frequency).
;     2. For each of the 12 notes in ST_DIV, multiply the standard divisor
;        by this ratio and store the result in I_DIV.
;
;   The result is a per-instrument divisor table used by RET_DIV.
;
; Input:  IX = instrument header
;         IY = destination in I_DIV
; Clobbers: AF, BC, DE, HL
;
; C equivalent:
;
;   void idiv_1(inst_t *ins, uint16_t *out) {
;       uint16_t ratio = div16(ins->freq, 0x2100);   // MUL/DIV helpers below
;       for (int i = 0; i < 12; i++) {
;           out[i] = (ST_DIV[i] * ratio) >> 8;        // MUL semantics
;       }
;   }

IDIV_1:     LD      E,(IX+18H)
            LD      D,(IX+19H)              ; DE = instrument frequency
            LD      BC,2100H                ; standard frequency
            CALL    DIV                     ; BC = BC / DE (ratio)
            LD      E,C
            LD      D,B                     ; DE = ratio
            PUSH    IY
            POP     BC                      ; BC = destination table

            LD      A,12                    ; 12 notes per octave
            LD      HL,ST_DIV               ; standard divisors
IDIV_2:     PUSH    AF
            PUSH    HL
            PUSH    BC
            LD      C,(HL)
            INC     HL
            LD      B,(HL)                  ; BC = standard divisor
            CALL    MUL                     ; HLBC * DE -> BC,HL
            POP     HL                      ; restore destination pointer
            LD      (HL),C
            INC     HL
            LD      (HL),B                  ; store the scaled divisor
            INC     HL
            PUSH    HL
            POP     BC                      ; BC = next destination
            POP     HL                      ; HL = next ST_DIV entry
            POP     AF
            INC     HL
            INC     HL                      ; ST_DIV is words
            DEC     A
            JR      NZ,IDIV_2
            RET

; Standard divisors for one octave (12 notes)
ST_DIV:     DW      766H,6FCH,697H,639H,5DFH,58BH
            DW      53BH,4F0H,4A9H,466H,427H,3EBH

; ===================== Read file into memory ================================
;
; LOAD
;   Open the .STM file, read its header into DATA, verify the version and
;   pattern count, then read the pattern data into memory (in 16 KB pages)
;   and de-interleave (XOR 0x80) each byte of the pattern area.
;
;   The file name comes from the FCB at 005Ch (the default DMA buffer).
;   The extension is forced to "STM" (S, T, M) if the user did not supply
;   one.
;
;   Header fields checked:
;     DATA+1Eh = version (must be 2)
;     DATA+1Dh = pattern count (must be 2)
;
;   Data layout after loading:
;     DATA    .. 0x4000  : header + instrument table + order list
;     0x4000  .. 0x8000  : pattern data (de-interleaved)
;
; C equivalent:
;
;   void load(void) {
;       fcb_t *fcb = (fcb_t*)0x005C;
;       memset(fcb->fname, 0, 24);
;       fcb->ext[0] = 'S'; fcb->ext[1] = 'T'; fcb->ext[2] = 'M';
;       if (!open(fcb)) error("File not found");
;       set_dma(DATA);
;       read_random(fcb, 0x49);              // 73 records = header
;       if (DATA[0x1E] != 2) error("Wrong version");
;       if (DATA[0x1D] != 2) error("Wrong pattern count");
;       print("Loading : ");
;       print_file_name(fcb);
;       // read the pattern data page by page
;       uint8_t page = 0x0A;
;       for (;;) {
;           set_dma(0x4000);
;           if (read_random(fcb, 0x400)) break;
;           page++;
;       }
;       // de-interleave: XOR 0x80 on every byte from 0x4000 to 0x7FFF
;       for (int i = 0x4000; i < 0x8000; i++) ((uint8_t*)i)[0] ^= 0x80;
;   }

LOAD:       LD      HL,5CH+12
            LD      DE,5CH+13
            LD      BC,24
            LD      (HL),0
            LDIR                            ; zero the FCB filename area
            LD      A,"S"
            LD      (5CH+9),A               ; force extension "STM"
            LD      A,"T"
            LD      (5CH+10),A
            LD      A,"M"
            LD      (5CH+11),A
            CALL    OPEN
            LD      HL,10H
            LD      (5CH+14),HL             ; record count = 16 (header block)
            LD      DE,DATA                 ; set DMA to DATA
            BDOS    1AH
            LD      HL,49H                  ; 73 records (header + instruments)
            LD      DE,5CH
            BDOS    27H                     ; read random block

; -------------------- Check the version is correct --------------------------

            LD      DE,BAD_VERS
            LD      A,(DATA+1EH)
            CP      2
            JP      NZ,ERROR
            LD      DE,BAD_NUM
            LD      A,(DATA+1DH)
            CP      2
            JP      NZ,ERROR
            LD      DE,LOADING
            BDOS    9                       ; print "Loading : "
            LD      DE,DATA
            CALL    PRINT                   ; print the file name

; ---------------------- Load the patterns -----------------------------------

            LD      DE,4000H
            BDOS    1AH                     ; DMA -> 0x4000 (patterns go here)
            LD      HL,400H                 ; 1024 records = 16 KB
            LD      C,0AH                   ; starting page = 0x0A
LO_0:       PUSH    BC
            PUSH    HL
            LD      H,40H                   ; bank 0x40 (page 1)
            LD      A,C
            ; NOTE: the asm also calls the MSX-DOS 0024h hook before each
            ; page read (see the CALL 24H instructions in LO_0 / LO_3).
            ; This is not part of standard CP/M; it is preserved as-is.            
            CALL    24H                     ; MSX-DOS: 0024h hook (see LOP_4 note)
            POP     HL
            LD      DE,5CH
            BDOS    27H                     ; read 16 KB
            OR      A
            JR      NZ,LO_1                 ; short read -> last page
            LD      HL,400H
            POP     BC
            INC     C
            JR      LO_0
            RET
LO_1:       POP     BC                      ; last page (instruments?)
            LD      A,(DATA+33)             ; number of patterns
            LD      L,A
            LD      H,0
            ADD     HL,HL                   ; *2
            ADD     HL,HL                   ; *4
            ADD     HL,HL                   ; *8
            ADD     HL,HL                   ; *16
            ADD     HL,HL                   ; *32
            ADD     HL,HL                   ; *64
            LD      A,H
            RRCA
            RRCA
            AND     1FH
            ADD     A,0AH                   ; start page for instruments
            ADD     HL,HL                   ; *128
            ADD     HL,HL                   ; *256
            ADD     HL,HL                   ; *512
            ADD     HL,HL                   ; *1024
            RES     7,H
            SET     6,H                     ; clamp to page 1
            INC     C
LO_3:       PUSH    AF
            PUSH    HL
            PUSH    BC
            LD      H,40H
            ; NOTE: the asm also calls the MSX-DOS 0024h hook before each
            ; page read (see the CALL 24H instructions in LO_0 / LO_3).
            ; This is not part of standard CP/M; it is preserved as-is.            
            CALL    24H                     ; MSX-DOS: 0024h hook
            POP     BC
            POP     HL
LO_2:       LD      A,(HL)
            XOR     80H                     ; de-interleave
            LD      (HL),A
            INC     HL
            LD      A,H
            CP      80H
            JR      NZ,LO_2
            POP     AF
            LD      HL,4000H
            INC     A
            CP      C
            JR      NZ,LO_3
            LD      A,05H
            LD      H,40H
            ; NOTE: the asm also calls the MSX-DOS 0024h hook before each
            ; page read (see the CALL 24H instructions in LO_0 / LO_3).
            ; This is not part of standard CP/M; it is preserved as-is.            
            CALL    24H                     ; MSX-DOS: 0024h hook
            RET

; ------------------------ Print a string up to 0 ----------------------------

PRINT:      LD      A,(DE)
            OR      A
            RET     Z
            PUSH    DE
            LD      E,A
            LD      C,2
            BDOS    2                       ; print one character
            POP     DE
            INC     DE
            JR      PRINT

; --------------------------- Print HEX --------------------------------------

HEX:        PUSH    IX                      ; BIOS SYMBOL may clobber IX
            PUSH    AF
            AND     0F0H
            SRL     A
            SRL     A
            SRL     A
            SRL     A
            CALL    HE_X                    ; high nibble
            POP     AF
            AND     0FH
            CALL    HE_X                    ; low nibble
            POP     IX
            RET
HE_X:       CP      0AH
            JR      NC,HE_0
            ADD     A,30H                   ; '0'..'9'
            JR      HE_1
HE_0:       ADD     A,41H-0AH                ; 'A'..'F'
HE_1:       RST     30H                     ; BIOS: output character
            DB      8,18H,0
            RET
ENTER:      PUSH    IX
            LD      A,0AH
            RST     30H
            DB      8,18H,0                 ; LF
            LD      A,0DH
            RST     30H
            DB      8,18H,0                 ; CR
            POP     IX
            RET
SPASE:      PUSH    IX
            LD      A,1CH
            RST     30H
            DB      8,18H,0                 ; space
            POP     IX
            RET

; ================== Print the note's string =================================
;
; OUT_PUT
;   Debug-print one channel's current note as a hex dump:
;     "NN SS VV C PP"  where NN=note, SS=sample, VV=volume,
;     C=command letter ('.' if 0, otherwise 'A'+command-1),
;     PP=parameter.
;
; Called from the main loop when F_PRINT is set.

OUT_PUT:    LD      A,(IX+N_NOTE)
            CALL    HEX
            CALL    SPASE
            LD      A,(IX+N_SAMPLE)
            CALL    HEX
            CALL    SPASE
            LD      A,(IX+N_VOLUME)
            CALL    HEX
            CALL    SPASE
            LD      A,(IX+N_COMAND)
            OR      A
            JR      Z,OU_0
            ADD     A,40H                   ; command -> letter 'A'+cmd-1
            JR      OU_1
OU_0:       LD      A,'.'
OU_1:       PUSH    IX
            RST     30H
            DB      8,18H,0                 ; output command letter
            POP     IX
            EI                              ; re-enable interrupts before
                                            ; the (slow) BIOS call below
            LD      A,(IX+N_PARAM)
            CALL    HEX
            CALL    SPASE
            CALL    SPASE
            CALL    SPASE
            RET

; ==================== Open FILE for access ==================================
;
; OPEN
;   Open the file whose FCB is at 005Ch. On success, zero the record
;   counter (FCB+33) and return with Z set. On failure, print OP_0 and
;   exit to the OS.
;
;   Side effect: writes 0 to FCB+33 (current record), so subsequent
;   BDOS 27h calls start from record 0.
;
; C equivalent:
;
;   int open_file(fcb_t *fcb) {
;       int rc = bdos_open(fcb);            // BDOS function 0Fh
;       fcb->record = 0;
;       if (rc == 0) return 0;              // success
;       error("File not found");
;       return -1;
;   }

OPEN:       LD      DE,5CH
            BDOS    0FH                     ; open file
            LD      HL,0
            LD      (5CH+33),HL             ; reset current record
            OR      A
            RET     Z                       ; success
            LD      DE,OP_0
            JP      ERROR

OP_0:       DEFM    'File not found $'

; ======================= Error messages =====================================

ERROR:      BDOS    9                       ; print the $-terminated string
            RST     0                       ; warm boot

; ========================== I/O PORTS INIT ==================================
;
; INI_PRT
;   Configure the 8254 timers and the 8237 DMA controller for Magic Sound
;   playback.
;
;   8254 #1 (TIMUP0 = 0F9DBh):
;     counter 0 (channel A, TIM_A) : mode 2 (rate generator), LSB then MSB
;     counter 1 (channel B, TIM_B) : mode 2
;     counter 2 (channel C, TIM_C) : mode 2
;   8254 #2 (TIMUP1 = 0F9D7h):
;     counter 0 (channel D, TIM_D) : mode 2
;     counter 1 (aux,     TIM_E) : mode 3 (square wave)
;   Aux counter (TIM_E) is loaded with 4 (and then 0).
;
;   8237 (DMARES = 0F8DDh):
;     master clear, command = 0
;     mask channels in order B, A, D, C (05h, 04h, 07h, 06h)
;
; C equivalent:
;
;   void ini_prt(void) {
;       out(TIMUP0, 0x34);   // cnt0, mode 2, LSB/MSB
;       out(TIMUP0, 0x74);   // cnt1, mode 2
;       out(TIMUP0, 0xB4);   // cnt2, mode 2
;       out(TIMUP1, 0x34);   // cnt0, mode 2
;       out(TIMUP1, 0x76);   // cnt1, mode 3 (square wave)
;       out(TIM_E, 4);
;       out(TIM_E, 0);
;       out(DMARES, 0);      // master clear
;       out(DMACOM, 0);      // command
;       out(DMAMASK, 0x05);  // mask ch B
;       out(DMAMASK, 0x04);  // mask ch A
;       out(DMAMASK, 0x07);  // mask ch D
;       out(DMAMASK, 0x06);  // mask ch C
;   }

INI_PRT:    LD      BC,TIMUP0                ; 8254 #1 control
            LD      A,034H                   ; counter 0, mode 2, LSB/MSB
            OUT     (C),A
            LD      A,074H                   ; counter 1, mode 2
            OUT     (C),A
            LD      A,0B4H                   ; counter 2, mode 2
            OUT     (C),A
            LD      BC,TIMUP1                ; 8254 #2 control
            LD      A,034H                   ; counter 0, mode 2
            OUT     (C),A
            LD      A,076H                   ; counter 1, mode 3 (square)
            OUT     (C),A
            LD      BC,TIM_E                 ; aux counter
            LD      A,4
            OUT     (C),A                    ; load 4 (LSB)
            SUB     A
            OUT     (C),A                    ; load 0 (MSB) -> period = 4
            LD      BC,DMARES                ; 8237 master clear
            OUT     (C),A                    ; A = 0
            LD      BC,DMACOM
            SUB     A
            OUT     (C),A                    ; command = 0
            LD      BC,DMAMASK
            LD      HL,0405H                 ; mask 05h then 04h
            OUT     (C),L
            OUT     (C),H
            LD      HL,0607H                 ; mask 07h then 06h
            OUT     (C),L
            OUT     (C),H
            RET

; ======================= Multiplication 16×16 ================================
;
; MUL
;   Multiply the 16-bit value in BC by the 16-bit value in DE, using the
;   HL register pair as an accumulator. Result is returned in BC (high) and
;   HL (low): 32-bit product BC:HL.
;
;   Algorithm: shift-and-add over 16 iterations. The multiplier is BC,
;   the multiplicand is DE. Each iteration:
;     - shift the 17-bit accumulator (A:HL) right
;     - if the low bit of BC (shifted out) was 1, add DE to HL
;
;   Note: the original uses a 17-bit accumulator (A + HL) to handle the
;   carry chain. The routine is called from IDIV_1, where BC = ST_DIV[i]
;   and DE = frequency ratio.
;
; C equivalent:
;
;   uint32_t mul(uint16_t bc, uint16_t de) {
;       uint32_t acc = 0;
;       for (int i = 0; i < 16; i++) {
;           acc = (acc << 1) | (bc & 1);
;           bc >>= 1;
;           if (acc & 0x10000) {           // carry from previous shift
;               acc += (uint32_t)de << 16;
;           }
;       }
;       return acc;
;   }

MUL:        LD      HL,0                     ; HL = low half of accumulator
            LD      A,B                      ; A = high byte of BC (multiplier)
            LD      B,11H                    ; 17 iterations (16 + 1)
            JR      MUL_1

MUL_3:      JR      NC,MUL_2                 ; no carry -> skip add
            ADD     HL,DE                    ; add multiplicand
MUL_2:      RR      H
            RR      L                        ; shift accumulator right
MUL_1:      RR      A                        ; shift multiplier, carry out
            RR      C
            DJNZ    MUL_3
            LD      B,A                      ; high half = A
            RET

; ======================== Division 2 bytes ==================================
;
; DIV
;   Divide the 16-bit value in BC by the 16-bit value in DE, returning
;   the quotient in BC and the remainder in HL. Uses a restoring
;   shift-and-subtract algorithm.
;
;   Called from IDIV_1 to compute the frequency ratio.
;
; C equivalent:
;
;   void div16(uint16_t bc, uint16_t de, uint16_t *q, uint16_t *r) {
;       uint32_t rem = 0;
;       uint16_t quot = 0;
;       for (int i = 0; i < 16; i++) {
;           rem = (rem << 1) | ((bc >> 15) & 1);
;           bc <<= 1;
;           if (rem >= de) { rem -= de; quot = (quot << 1) | 1; }
;           else            { quot = quot << 1; }
;       }
;       *q = quot; *r = rem;
;   }

DIV:        LD      HL,0                     ; HL = remainder
            LD      A,B                      ; A = high byte of dividend
            LD      B,10H                    ; 16 iterations
            RL      C
            RLA
DIV_0:      RL      L
            RL      H                        ; shift remainder left
            JR      C,DIV_3                  ; overflow -> subtract
            SBC     HL,DE
            JR      NC,DIV_1                 ; no borrow -> quotient bit = 1
            ADD     HL,DE                    ; restore remainder
DIV_1:      CCF                              ; complement carry into quotient
DIV_2:      RL      C
            RLA
            DJNZ    DIV_0
            LD      B,A
; Integer part from ( BC, HL )
            ADD     HL,HL                    ; remainder * 2
            OR      A
            SBC     HL,DE                    ; (rem * 2) - divisor
            RET     C                        ; < 0 -> done
            INC     BC                       ; round up
            RET

DIV_3:      OR      A
            SBC     HL,DE
            JR      DIV_2

; =============================================================================

BAD_NUM:    DB      'Wrong pattern count $'
BAD_VERS:   DB      'Wrong version number $'
LOADING:    DB      'Loading : $'

; -----------------------------------------------------------------------------
; DEMO
;   Single-line marquee text. Scrolled by STAR_ON / STAR_ON1. A 0x01 byte
;   terminates the string; the main loop wraps D_POINT to the start on it.
; -----------------------------------------------------------------------------
DEMO:       DB      'ALESTE 520EX  MAGIC SOUND  STM PLAYER',1

; -----------------------------------------------------------------------------
; T_VIB_1
;   Vibrato waveform, 256 bytes in this dump (128 signed 16-bit samples).
;   A full sine wave: ascending from 0 to 0x00FF, descending to 0, then
;   mirrored negative half. Copied to T_VIBRATO by RESTORE.
;
;   NOTE: RESTORE copies 0x200 bytes, but this table is only 0x100 bytes.
;   See the note in RESTORE. The original binary may have a 512-byte table.
; -----------------------------------------------------------------------------
T_VIB_1:    DB      000h, 000h, 018h, 000h, 031h, 000h, 04Ah, 000h
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

            END