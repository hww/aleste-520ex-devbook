                org 100h

; =============== S U B R O U T I N E =======================================


entry:
                jp      start
; ---------------------------------------------------------------------------

start:                                  ; CODE XREF: entry↑j
                ld      sp, (6)
                call    int_ptr
                call    clear
                call    load_stm_file
                call    restore
                call    init_div
                call    init_screen
                call    sub_2E0
                ld      hl, demo_text
                ld      (2FA2h), hl
                call    set_interrupt_hook

loop:                                   ; CODE XREF: entry+F9↓j ROM:021B↓j ...
                ei
                ld      a, (2F90h)
                or      a
                jr      z, update_player
                ld      a, (2F92h)
                or      a
                jp      z, loc_1ED
                sub     a
                ld      (2F92h), a
                ld      ix, 3078h
                call    print_curent_note
                ld      ix, 307Ah
                call    print_curent_note
                ld      ix, 307Ch
                call    print_curent_note
                ld      ix, 307Eh
                call    print_curent_note
                call    print_new_line
                jp      loc_1ED
; ---------------------------------------------------------------------------

update_player:                          ; CODE XREF: entry+2A↑j
                ld      a, (2F92h)
                or      a
                jp      z, loc_182
                sub     a
                ld      (2F92h), a
                ld      hl, (2FA2h)
                ld      a, (hl)
                inc     hl
                or      a
                jr      nz, loc_170
                ld      hl, 11BBh
                ld      a, (hl)

loc_170:                                ; CODE XREF: entry+6A↑j
                ld      (2FA2h), hl
                ld      e, a
                ld      a, 2
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ei

loc_182:                                ; CODE XREF: entry+5D↑j
                call    draw_vu_meter
                call    star_enable
                jp      loc_1ED
; End of function entry


; =============== S U B R O U T I N E =======================================


draw_vu_meter:                          ; CODE XREF: entry:loc_182↑p
                ld      a, (30F0h)
                ld      hl, 95F4h
                call    draw_line
                ld      a, (30F2h)
                ld      hl, 9644h
                call    draw_line
                ld      a, (30F4h)
                ld      hl, 9694h
                call    draw_line
                ld      a, (30F6h)
                ld      hl, 96E4h
                call    draw_line
                ret
; End of function draw_vu_meter


; =============== S U B R O U T I N E =======================================


draw_line:                              ; CODE XREF: draw_vu_meter+6↑p
                                        ; draw_vu_meter+F↑p ...
                ld      bc, 7EC0h
                out     (c), c
                rrca
                rrca
                and     0Fh
                ld      b, a
                inc     b
                ld      a, 0Ch
                ld      c, 0CCh
                ld      de, 800h

loc_1C2:                                ; CODE XREF: draw_line:loc_1D4↓j
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

loc_1D4:                                ; CODE XREF: draw_line+1E↑j
                djnz    loc_1C2
                ld      b, a

loc_1D7:                                ; CODE XREF: draw_line+35↓j
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
                ld      bc, 7EC6h       ; Gate Array: restore normal mode
                out     (c), c
                ret
; End of function draw_line

; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR entry

loc_1ED:                                ; CODE XREF: entry+30↑j entry+56↑j ...
                ld      ix, 8
                ld      iy, 800h
                call    1Ch
                or      a
                jp      z, loop
                jr      loc_227
; END OF FUNCTION CHUNK FOR entry
; ---------------------------------------------------------------------------
                cp      20h ; ' '
                jr      nz, loc_227
                ld      a, (2F90h)
                cpl
                ld      (2F90h), a
                or      a
                jr      z, loc_21E
                sub     a
                ld      bc, 300h
                ld      ix, 81h
                ld      iy, 800h
                call    1Ch
                jp      loop
; ---------------------------------------------------------------------------

loc_21E:                                ; CODE XREF: ROM:020A↑j
                call    init_screen
                call    sub_2E0
                jp      loop
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR entry

loc_227:                                ; CODE XREF: entry+FC↑j ROM:0200↑j
                cp      0Dh
                jr      nz, loc_233
                ld      a, 1
                ld      (2F82h), a
                jp      loop
; ---------------------------------------------------------------------------

loc_233:                                ; CODE XREF: entry+129↑j
                sub     a
                ld      (2F8Eh), a
                call    int_ptr
                call    remove_interrupt_hook
                ld      h, 40h ; '@'
                ld      a, 5
                call    24h
                ld      a, 0
                ld      bc, 300h
                ld      ix, 81h
                ld      iy, 800h
                call    1Ch
                rst     0
; END OF FUNCTION CHUNK FOR entry

; =============== S U B R O U T I N E =======================================


star_enable:                            ; CODE XREF: entry+85↑p
                ld      hl, (2F98h)
                push    hl
                ld      a, (2F9Eh)
                ld      (2FA0h), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      (2F98h), hl
                ld      de, 180h
                call    set_starts
                pop     hl
                ld      de, 180h
                call    set_starts
                ld      hl, (2F96h)
                push    hl
                ld      a, (2F9Ch)
                push    af
                rrca
                rrca
                ld      (2FA0h), a
                ld      (2F9Ch), a
                jr      nc, loc_29A
                ld      a, 0Ch
                ld      (2FA0h), a
                ld      (2F9Ch), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      (2F96h), hl

loc_29A:                                ; CODE XREF: star_enable+31↑j
                ld      de, 140h
                call    set_starts
                pop     af
                ld      (2FA0h), a
                pop     hl
                ld      de, 140h
                call    set_starts
                ld      hl, (2F94h)
                push    hl
                ld      a, (2F9Ah)
                push    af
                rrca
                ld      (2FA0h), a
                ld      (2F9Ah), a
                jr      nc, loc_2CE
                ld      a, 8
                ld      (2FA0h), a
                ld      (2F9Ah), a
                inc     hl
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      (2F94h), hl

loc_2CE:                                ; CODE XREF: star_enable+65↑j
                ld      de, 100h
                call    set_starts
                pop     af
                ld      (2FA0h), a
                pop     hl
                ld      de, 100h
                call    set_starts
                ret
; End of function star_enable


; =============== S U B R O U T I N E =======================================


sub_2E0:                                ; CODE XREF: entry+19↑p ROM:0221↑p
                ld      hl, 0B800h
                ld      (2F94h), hl
                ld      (2F96h), hl
                ld      (2F98h), hl
                ld      a, 8
                ld      (2F9Ah), a
                ld      a, 0Ch
                ld      (2F9Ch), a
                ld      a, 0Eh
                ld      (2F9Eh), a
                ld      a, (2F9Ah)
                ld      (2FA0h), a
                ld      hl, (2F94h)
                ld      de, 100h
                call    set_starts
                ld      a, (2F9Ch)
                ld      (2FA0h), a
                ld      hl, (2F96h)
                ld      de, 140h
                call    set_starts
                ld      a, (2F9Eh)
                ld      (2FA0h), a
                ld      hl, (2F98h)
                ld      de, 180h
                call    set_starts
                ret
; End of function sub_2E0


; =============== S U B R O U T I N E =======================================


set_starts:                             ; CODE XREF: star_enable+17↑p
                                        ; star_enable+1E↑p ...
                ld      bc, 7EC0h
                out     (c), c
                ld      b, 30h ; '0'

loc_330:                                ; CODE XREF: set_starts+1E↓j
                ld      a, (de)
                and     1Fh
                add     a, 20h ; ' '
                ld      c, a
                ld      a, b
                ld      b, 0
                add     hl, bc
                ld      b, a
                ld      a, h
                and     7
                or      0B8h
                ld      h, a
                ld      a, (2FA0h)
                xor     (hl)
                ld      (hl), a
                inc     de
                djnz    loc_330
                ld      bc, 7EC6h
                out     (c), c
                ret
; End of function set_starts


; =============== S U B R O U T I N E =======================================


clear:                                  ; CODE XREF: entry+A↑p
                di
                ld      hl, 2000h
                ld      de, 2001h
                ld      bc, 2000h
                ld      (hl), 0
                ldir
                ret
; End of function clear


; =============== S U B R O U T I N E =======================================


restore:                                ; CODE XREF: entry+10↑p
                ld      a, (2020h)
                cp      10h
                jr      nc, loc_367
                ld      a, 10h

loc_367:                                ; CODE XREF: restore+5↑j
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (2F80h), a
                ld      (2F81h), a
                ld      hl, vibrato_table
                ld      de, 2D00h
                ld      bc, 200h
                ldir
                ld      a, 1
                ld      (2F82h), a
                ld      hl, 2410h
                ld      (2F84h), hl
                ld      a, (2022h)
                ld      (2F8Ch), a
                ld      a, 1
                ld      (2F8Eh), a
                ret
; End of function restore

; ---------------------------------------------------------------------------
                ld      a, (3048h)
                or      a
                jr      z, loc_3AC
                ld      a, 4
                ld      bc, 0F8DAh
                ld      bc, 0FAD0h
                ld      a, 0
                out     (c), a
                jp      loc_440
; ---------------------------------------------------------------------------

loc_3AC:                                ; CODE XREF: ROM:039B↑j
                ld      a, (3020h)
                or      a
                jr      z, loc_3E0
                ld      a, 4
                ld      bc, 0F8DAh
                out     (c), a
                ld      a, (3038h)
                ld      (3040h), a
                or      a
                jr      z, loc_3CE
                ld      hl, (3090h)
                ld      (3078h), hl
                ld      hl, (30A0h)
                ld      (3080h), hl

loc_3CE:                                ; CODE XREF: ROM:03C0↑j
                ld      bc, 0F8D0h
                ld      hl, (3088h)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (3098h)
                out     (c), l
                out     (c), h

loc_3E0:                                ; CODE XREF: ROM:03B0↑j
                ld      a, (3030h)
                or      a
                jr      z, loc_3F0
                ld      bc, 0F9D8h
                ld      hl, (3010h)
                out     (c), l
                out     (c), h

loc_3F0:                                ; CODE XREF: ROM:03E4↑j
                ld      a, (3028h)
                or      a
                jr      z, loc_417
                ld      a, (3018h)
                sub     1
                jr      z, loc_3FF
                jr      nc, loc_401

loc_3FF:                                ; CODE XREF: ROM:03FB↑j
                ld      a, 0

loc_401:                                ; CODE XREF: ROM:03FD↑j
                ld      bc, 0FAD0h
                sla     a
                sla     a
                out     (c), a
                and     3Fh ; '?'
                ld      l, a
                ld      a, (30F0h)
                cp      l
                jr      nc, loc_417
                ld      a, l
                ld      (30F0h), a

loc_417:                                ; CODE XREF: ROM:03F4↑j ROM:0411↑j
                ld      a, (3020h)
                or      a
                jr      z, loc_440
                ld      bc, 0FBD0h
                ld      a, (30A8h)
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
                ld      bc, 0F8DBh
                ld      a, 48h ; 'H'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 0
                out     (c), a

loc_440:                                ; CODE XREF: ROM:03A9↑j ROM:041B↑j
                sub     a
                ld      (3020h), a
                ld      (3030h), a
                ld      (3028h), a
                ld      (3038h), a
                ld      (3048h), a
                ld      a, (304Ah)
                or      a
                jr      z, loc_465
                ld      a, 5
                ld      bc, 0F8DAh
                ld      bc, 0FAD1h
                ld      a, 0
                out     (c), a
                jp      loc_4F9
; ---------------------------------------------------------------------------

loc_465:                                ; CODE XREF: ROM:0454↑j
                ld      a, (3022h)
                or      a
                jr      z, loc_499
                ld      a, 5
                ld      bc, 0F8DAh
                out     (c), a
                ld      a, (303Ah)
                ld      (3042h), a
                or      a
                jr      z, loc_487
                ld      hl, (3092h)
                ld      (307Ah), hl
                ld      hl, (30A2h)
                ld      (3082h), hl

loc_487:                                ; CODE XREF: ROM:0479↑j
                ld      bc, 0F8D2h
                ld      hl, (308Ah)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (309Ah)
                out     (c), l
                out     (c), h

loc_499:                                ; CODE XREF: ROM:0469↑j
                ld      a, (3032h)
                or      a
                jr      z, loc_4A9
                ld      bc, 0F9D9h
                ld      hl, (3012h)
                out     (c), l
                out     (c), h

loc_4A9:                                ; CODE XREF: ROM:049D↑j
                ld      a, (302Ah)
                or      a
                jr      z, loc_4D0
                ld      a, (301Ah)
                sub     1
                jr      z, loc_4B8
                jr      nc, loc_4BA

loc_4B8:                                ; CODE XREF: ROM:04B4↑j
                ld      a, 0

loc_4BA:                                ; CODE XREF: ROM:04B6↑j
                ld      bc, 0FAD1h
                sla     a
                sla     a
                out     (c), a
                and     3Fh ; '?'
                ld      l, a
                ld      a, (30F2h)
                cp      l
                jr      nc, loc_4D0
                ld      a, l
                ld      (30F2h), a

loc_4D0:                                ; CODE XREF: ROM:04AD↑j ROM:04CA↑j
                ld      a, (3022h)
                or      a
                jr      z, loc_4F9
                ld      bc, 0FBD4h
                ld      a, (30AAh)
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
                ld      bc, 0F8DBh
                ld      a, 49h ; 'I'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 1
                out     (c), a

loc_4F9:                                ; CODE XREF: ROM:0462↑j ROM:04D4↑j
                sub     a
                ld      (3022h), a
                ld      (3032h), a
                ld      (302Ah), a
                ld      (303Ah), a
                ld      (304Ah), a
                ld      a, (304Ch)
                or      a
                jr      z, loc_51E
                ld      a, 6
                ld      bc, 0F8DAh
                ld      bc, 0FAD2h
                ld      a, 0
                out     (c), a
                jp      loc_5B2
; ---------------------------------------------------------------------------

loc_51E:                                ; CODE XREF: ROM:050D↑j
                ld      a, (3024h)
                or      a
                jr      z, loc_552
                ld      a, 6
                ld      bc, 0F8DAh
                out     (c), a
                ld      a, (303Ch)
                ld      (3044h), a
                or      a
                jr      z, loc_540
                ld      hl, (3094h)
                ld      (307Ch), hl
                ld      hl, (30A4h)
                ld      (3084h), hl

loc_540:                                ; CODE XREF: ROM:0532↑j
                ld      bc, 0F8D4h
                ld      hl, (308Ch)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (309Ch)
                out     (c), l
                out     (c), h

loc_552:                                ; CODE XREF: ROM:0522↑j
                ld      a, (3034h)
                or      a
                jr      z, loc_562
                ld      bc, 0F9DAh
                ld      hl, (3014h)
                out     (c), l
                out     (c), h

loc_562:                                ; CODE XREF: ROM:0556↑j
                ld      a, (302Ch)
                or      a
                jr      z, loc_589
                ld      a, (301Ch)
                sub     1
                jr      z, loc_571
                jr      nc, loc_573

loc_571:                                ; CODE XREF: ROM:056D↑j
                ld      a, 0

loc_573:                                ; CODE XREF: ROM:056F↑j
                ld      bc, 0FAD2h
                sla     a
                sla     a
                out     (c), a
                and     3Fh ; '?'
                ld      l, a
                ld      a, (30F4h)
                cp      l
                jr      nc, loc_589
                ld      a, l
                ld      (30F4h), a

loc_589:                                ; CODE XREF: ROM:0566↑j ROM:0583↑j
                ld      a, (3024h)
                or      a
                jr      z, loc_5B2
                ld      bc, 0FBD8h
                ld      a, (30ACh)
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
                ld      bc, 0F8DBh
                ld      a, 4Ah ; 'J'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 2
                out     (c), a

loc_5B2:                                ; CODE XREF: ROM:051B↑j ROM:058D↑j
                sub     a
                ld      (3024h), a
                ld      (3034h), a
                ld      (302Ch), a
                ld      (303Ch), a
                ld      (304Ch), a
                ld      a, (304Eh)
                or      a
                jr      z, loc_5D7
                ld      a, 7
                ld      bc, 0F8DAh
                ld      bc, 0FAD3h
                ld      a, 0
                out     (c), a
                jp      loc_66B
; ---------------------------------------------------------------------------

loc_5D7:                                ; CODE XREF: ROM:05C6↑j
                ld      a, (3026h)
                or      a
                jr      z, loc_60B
                ld      a, 7
                ld      bc, 0F8DAh
                out     (c), a
                ld      a, (303Eh)
                ld      (3046h), a
                or      a
                jr      z, loc_5F9
                ld      hl, (3096h)
                ld      (307Eh), hl
                ld      hl, (30A6h)
                ld      (3086h), hl

loc_5F9:                                ; CODE XREF: ROM:05EB↑j
                ld      bc, 0F8D6h
                ld      hl, (308Eh)
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (309Eh)
                out     (c), l
                out     (c), h

loc_60B:                                ; CODE XREF: ROM:05DB↑j
                ld      a, (3036h)
                or      a
                jr      z, loc_61B
                ld      bc, 0F9D4h
                ld      hl, (3016h)
                out     (c), l
                out     (c), h

loc_61B:                                ; CODE XREF: ROM:060F↑j
                ld      a, (302Eh)
                or      a
                jr      z, loc_642
                ld      a, (301Eh)
                sub     1
                jr      z, loc_62A
                jr      nc, loc_62C

loc_62A:                                ; CODE XREF: ROM:0626↑j
                ld      a, 0

loc_62C:                                ; CODE XREF: ROM:0628↑j
                ld      bc, 0FAD3h
                sla     a
                sla     a
                out     (c), a
                and     3Fh ; '?'
                ld      l, a
                ld      a, (30F6h)
                cp      l
                jr      nc, loc_642
                ld      a, l
                ld      (30F6h), a

loc_642:                                ; CODE XREF: ROM:061F↑j ROM:063C↑j
                ld      a, (3026h)
                or      a
                jr      z, loc_66B
                ld      bc, 0FBDCh
                ld      a, (30AEh)
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
                ld      bc, 0F8DBh
                ld      a, 4Bh ; 'K'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 3
                out     (c), a

loc_66B:                                ; CODE XREF: ROM:05D4↑j ROM:0646↑j
                sub     a
                ld      (3026h), a
                ld      (3036h), a
                ld      (302Eh), a
                ld      (303Eh), a
                ld      (304Eh), a
                ld      a, (2F80h)
                or      a
                jr      z, loc_6A4
                dec     a
                ld      (2F80h), a
                ld      ix, 3078h
                call    command
                ld      ix, 307Ah
                call    command
                ld      ix, 307Ch
                call    command
                ld      ix, 307Eh
                call    command
                jp      int_hook_buffer
; ---------------------------------------------------------------------------

loc_6A4:                                ; CODE XREF: ROM:067F↑j
                ld      a, (2F8Eh)
                or      a
                jp      z, int_hook_buffer
                ld      a, (2F81h)
                or      a
                jr      z, loc_6B2
                dec     a

loc_6B2:                                ; CODE XREF: ROM:06AF↑j
                ld      (2F80h), a
                ld      a, (2F82h)
                or      a
                jr      z, loc_6C2
                sub     a
                ld      (2F82h), a
                call    next_order

loc_6C2:                                ; CODE XREF: ROM:06B9↑j
                ld      ix, 3078h
                call    next_note
                ld      ix, 307Ah
                call    next_note
                ld      ix, 307Ch
                call    next_note
                ld      ix, 307Eh
                call    next_note
                ld      a, 0FFh
                ld      (2F92h), a

int_hook_buffer:                        ; CODE XREF: ROM:06A1↑j ROM:06A8↑j
                nop
                nop
                nop
                nop
                nop
                nop
                ret

; =============== S U B R O U T I N E =======================================


next_note:                              ; CODE XREF: ROM:06C6↑p ROM:06CD↑p ...
                inc     (ix-78h)
                ld      a, (ix-78h)
                cp      40h ; '@'
                jr      c, loc_6F9
                ld      a, 1
                ld      (2F82h), a

loc_6F9:                                ; CODE XREF: next_note+8↑j
                ld      l, (ix-70h)
                ld      h, (ix-6Fh)
                push    hl
                pop     iy
                ld      a, (iy+0)
                ld      (ix+48h), a
                ld      a, (iy+1)
                srl     a
                srl     a
                srl     a
                ld      (ix+50h), a
                ld      a, (iy+1)
                and     7
                ld      l, a
                ld      a, (iy+2)
                rrca
                and     78h ; 'x'
                or      l
                ld      (ix+40h), a
                ld      a, (iy+2)
                and     0Fh
                ld      (ix+38h), a
                ld      a, (iy+3)
                ld      (ix+58h), a
                push    iy
                pop     hl
                ld      de, 10h
                add     hl, de
                ld      (ix-70h), l
                ld      (ix-6Fh), h
                call    get_note
                ld      a, (ix+38h)
                cp      9
                jp      nz, loc_74E
                call    command
                ret
; ---------------------------------------------------------------------------

loc_74E:                                ; CODE XREF: next_note+5D↑j
                cp      0Ah
                ret     nz
                ld      (ix+68h), 1
                ld      a, (ix+58h)
                and     0F0h
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (ix+70h), a
                ret
; End of function next_note


; =============== S U B R O U T I N E =======================================


get_note:                               ; CODE XREF: next_note+55↑p
                ld      a, (ix+40h)
                cp      41h ; 'A'
                jr      nc, loc_777
                ld      (ix-60h), a
                ld      (ix-20h), a
                ld      (ix-50h), 1

loc_777:                                ; CODE XREF: get_note+5↑j
                ld      a, (ix+38h)
                cp      7
                jp      z, loc_849
                ld      a, (ix+48h)
                cp      0FFh
                jp      z, loc_845
                ld      a, (ix+50h)
                or      0
                jp      z, loc_820
                ld      l, a
                ld      h, 0
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                ld      de, 2010h
                add     hl, de
                push    hl
                pop     iy
                ld      (ix-18h), l
                ld      (ix-17h), h
                ld      a, (ix+40h)
                cp      41h ; 'A'
                jr      nz, loc_7B8
                ld      a, (iy+16h)
                ld      (ix-60h), a
                ld      (ix-20h), a
                ld      (ix-50h), 1

loc_7B8:                                ; CODE XREF: get_note+43↑j
                ld      l, (iy+0Eh)
                ld      h, (iy+0Fh)
                ld      de, 49h ; 'I'
                or      a
                sbc     hl, de
                ld      a, h
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                res     6, h
                res     7, h
                srl     a
                srl     a
                add     a, 0Ah
                ld      (ix+30h), a
                ld      (ix+10h), l
                ld      (ix+11h), h
                ld      l, (iy+14h)
                ld      h, (iy+15h)
                inc     hl
                ld      a, l
                or      h
                jr      z, loc_810
                dec     hl
                ld      (ix+20h), l
                ld      (ix+21h), h
                ld      e, (iy+12h)
                ld      d, (iy+13h)
                or      a
                sbc     hl, de
                ld      (ix+28h), l
                ld      (ix+29h), h
                ld      l, (ix+10h)
                ld      h, (ix+11h)
                add     hl, de
                ld      (ix+18h), l
                ld      (ix+19h), h
                ld      (ix-40h), 1
                jr      loc_81C
; ---------------------------------------------------------------------------

loc_810:                                ; CODE XREF: get_note+7F↑j
                ld      l, (iy+10h)
                ld      h, (iy+11h)
                ld      (ix+20h), l
                ld      (ix+21h), h

loc_81C:                                ; CODE XREF: get_note+A8↑j
                ld      (ix-58h), 1

loc_820:                                ; CODE XREF: get_note+26↑j
                ld      a, (ix+48h)
                cp      0FEh
                jr      nz, loc_82E
                ld      (ix-30h), 1
                jp      loc_845
; ---------------------------------------------------------------------------

loc_82E:                                ; CODE XREF: get_note+BF↑j
                cp      0FFh
                jr      z, loc_845
                call    ret_div
                ld      (ix-28h), l
                ld      (ix-27h), h
                ld      (ix-68h), l
                ld      (ix-67h), h
                ld      (ix-48h), 1

loc_845:                                ; CODE XREF: get_note+1E↑j get_note+C5↑j ...
                call    goto
                ret
; ---------------------------------------------------------------------------

loc_849:                                ; CODE XREF: get_note+16↑j
                ld      a, (ix+48h)
                cp      0FFh
                ret     z
                call    ret_div
                ld      (ix-28h), l
                ld      (ix-27h), h
                ret
; End of function get_note


; =============== S U B R O U T I N E =======================================


ret_div:                                ; CODE XREF: get_note+CC↑p get_note+E9↑p
                push    af
                and     0Fh
                ld      l, a
                ld      h, 0
                add     hl, hl
                ld      e, (ix-18h)
                ld      d, (ix-17h)
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

loc_87C:                                ; CODE XREF: ret_div+27↓j
                srl     h
                rr      l
                djnz    loc_87C
                ret
; End of function ret_div


; =============== S U B R O U T I N E =======================================


goto:                                   ; CODE XREF: get_note:loc_845↑p
                ld      a, (ix+58h)
                ld      e, a
                ld      a, (ix+38h)
                cp      1
                jr      z, loc_897
                cp      2
                jr      z, loc_8AD
                cp      3
                jr      z, break
                ret
; ---------------------------------------------------------------------------

loc_897:                                ; CODE XREF: goto+9↑j
                ld      a, e
                cp      10h
                jr      nc, loc_89E
                ld      a, 10h

loc_89E:                                ; CODE XREF: goto+17↑j
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (2F81h), a
                ld      (2F80h), a
                ret
; ---------------------------------------------------------------------------

loc_8AD:                                ; CODE XREF: goto+D↑j
                ld      d, 0
                ld      hl, 2410h
                add     hl, de
                ld      (2F84h), hl
                ret
; ---------------------------------------------------------------------------

break:                                  ; CODE XREF: goto+11↑j
                ld      a, 1
                ld      (2F82h), a
                ret
; End of function goto


; =============== S U B R O U T I N E =======================================


command:                                ; CODE XREF: ROM:0689↑p ROM:0690↑p ...
                ld      a, (ix+78h)
                or      a
                jr      z, loc_8C7
                dec     a
                ld      (ix+78h), a

loc_8C7:                                ; CODE XREF: command+4↑j
                ld      a, (ix+58h)
                ld      l, a
                ld      a, (ix+38h)
                cp      4
                jp      z, slide
                cp      5
                jp      z, por_down
                cp      6
                jp      z, por_up
                cp      9
                jp      z, tremor
                ld      (ix-10h), 0
                ld      (ix-08h), 1
                cp      7
                jp      z, portamento
                cp      8
                jp      z, vibrato
                ld      (ix+60h), 0
                cp      0Ah
                ret
; ---------------------------------------------------------------------------

por_up:                                 ; CODE XREF: command+1D↑j
                ld      h, 0
                ld      e, (ix-68h)
                ld      d, (ix-67h)
                ex      de, hl
                or      a
                sbc     hl, de
                ld      (ix-68h), l
                ld      (ix-67h), h
                ld      (ix-48h), 1
                ret
; ---------------------------------------------------------------------------

por_down:                               ; CODE XREF: command+18↑j
                ld      h, 0
                ld      e, (ix-68h)
                ld      d, (ix-67h)
                add     hl, de
                ld      (ix-68h), l
                ld      (ix-67h), h
                ld      (ix-48h), 1
                ret
; ---------------------------------------------------------------------------

slide:                                  ; CODE XREF: command+13↑j
                ld      (ix-50h), 1
                ld      a, l
                and     0Fh
                jr      z, v_up
                ld      l, a
                ld      a, (ix-60h)
                sub     l
                ld      (ix-60h), a
                ret     nc
                ld      (ix-60h), 0
                ret
; ---------------------------------------------------------------------------

v_up:                                   ; CODE XREF: command+70↑j
                ld      a, l
                srl     a
                srl     a
                srl     a
                srl     a
                ld      l, a
                ld      a, (ix-60h)
                add     a, l
                ld      (ix-60h), a
                cp      41h ; 'A'
                ret     c
                ld      (ix-60h), 40h ; '@'
                ret
; ---------------------------------------------------------------------------

tremor:                                 ; CODE XREF: command+22↑j
                ld      a, (ix-10h)
                or      a
                jr      z, _tremor_1
                dec     a
                ld      (ix-10h), a
                ret
; ---------------------------------------------------------------------------

_tremor_1:                              ; CODE XREF: command+9D↑j
                ld      a, (ix-08h)
                cp      1
                jr      z, _tremor_2
                ld      (ix-08h), 1
                ld      a, (ix-20h)
                ld      (ix-60h), a
                ld      a, l
                srl     a
                srl     a
                srl     a
                srl     a
                ld      (ix-10h), a
                ret
; ---------------------------------------------------------------------------

_tremor_2:                              ; CODE XREF: command+A9↑j
                ld      (ix-08h), 0
                ld      (ix-60h), 0
                ld      a, l
                and     0Fh
                ld      (ix-10h), a
                ret
; ---------------------------------------------------------------------------

arpejio:
                ld      a, (ix+'h')
                or      a
                ret     z
                ld      a, (ix+70h)
                or      a
                jr      z, _tremor_3
                dec     a
                ld      (ix+70h), a
                ret
; ---------------------------------------------------------------------------

_tremor_3:                              ; CODE XREF: command+DA↑j
                ld      h, 0
                ld      a, l
                ld      a, 0Fh
                ld      l, a
                ex      de, hl
                ld      l, (ix-28h)
                ld      h, (ix-27h)
                or      a
                sbc     hl, de
                ld      (ix-68h), l
                ld      (ix-67h), h
                ld      (ix-48h), 1
                ld      (ix+68h), 0
                ret
; ---------------------------------------------------------------------------
                rst     18h
                rst     18h
                rst     18h

portamento:                             ; CODE XREF: command+2F↑j
                ld      e, (ix-68h)
                ld      d, (ix-67h)
                ld      l, (ix-28h)
                ld      h, (ix-27h)
                or      a
                push    hl
                sbc     hl, de
                pop     hl
                ret     z
                jp      c, _portamentor_2
                ld      c, (ix+58h)
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

_portamento_1:                          ; CODE XREF: command+125↑j
                ld      (ix-68h), e
                ld      (ix-67h), d
                ld      (ix-48h), 1
                ret
; ---------------------------------------------------------------------------

_portamentor_2:                         ; CODE XREF: command+115↑j
                ld      c, (ix+58h)
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

_portamento_3:                          ; CODE XREF: command+142↑j
                ld      (ix-68h), e
                ld      (ix-67h), d
                ld      (ix-48h), 1
                ret
; ---------------------------------------------------------------------------

vibrato:                                ; CODE XREF: command+34↑j
                ld      h, (ix+60h)
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
                ld      de, 2D00h
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

_vibrator_1:                            ; CODE XREF: command+17F↓j
                add     hl, de
                djnz    _vibrator_1
                ex      de, hl
                ld      l, (ix-28h)
                ld      h, (ix-27h)
                add     hl, de
                ld      (ix-68h), l
                ld      (ix-67h), h
                pop     hl
                ld      a, h
                srl     l
                srl     l
                srl     l
                srl     l
                add     a, l
                inc     a
                and     7Fh
                ld      (ix+60h), a
                ld      (ix-48h), 1
                ret
; End of function command


; =============== S U B R O U T I N E =======================================


divide_de_by_2:                         ; CODE XREF: command+169↑p command+16C↑p ...
                sra     d
                rr      e
                ret     nc
                inc     de
                ret
; End of function divide_de_by_2


; =============== S U B R O U T I N E =======================================


next_order:                             ; CODE XREF: ROM:06BF↑p
                ld      a, (2F90h)
                or      a
                call    nz, print_new_line
                ld      hl, (2F84h)
                ld      a, (hl)
                cp      63h ; 'c'
                jr      nz, loc_A8A
                ld      hl, 2410h
                ld      a, 1
                ld      (3048h), a
                ld      (304Ah), a
                ld      (304Ch), a
                ld      (304Eh), a
                ld      a, (hl)

loc_A8A:                                ; CODE XREF: next_order+D↑j
                ld      (2F86h), hl
                inc     hl
                ld      (2F84h), hl
                ld      (2F88h), a
                ld      h, a
                and     0F0h
                srl     a
                srl     a
                srl     a
                srl     a
                add     a, 0Ah
                ld      (0F342h), a
                or      0C0h
                ld      bc, 7DFFh
                out     (c), a
                ld      l, 0
                add     hl, hl
                add     hl, hl
                ld      a, h
                and     3Fh ; '?'
                or      40h ; '@'
                ld      h, a
                ld      de, 4
                ld      (3008h), hl
                add     hl, de
                ld      (300Ah), hl
                add     hl, de
                ld      (300Ch), hl
                add     hl, de
                ld      (300Eh), hl
                sub     a
                ld      (3000h), a
                ld      (3002h), a
                ld      (3004h), a
                ld      (3006h), a
                ret
; End of function next_order

; ---------------------------------------------------------------------------

nmi_hook:                               ; DATA XREF: set_interrupt_hook+27↓o
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


nmi_imp:                                ; CODE XREF: ROM:0AD9↑p
                ld      bc, 0F8D8h
                in      e, (c)
                rrc     e
                jr      nc, loc_B15
                ld      a, (3040h)
                or      a
                jr      z, loc_B15
                ld      hl, (3078h)
                ld      bc, 0F8D0h
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (3080h)
                out     (c), l
                out     (c), h
                sub     a
                ld      (3040h), a
                ld      bc, 0F8DBh
                ld      a, 58h ; 'X'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 0
                out     (c), a

loc_B15:                                ; CODE XREF: nmi_imp+7↑j nmi_imp+D↑j
                nop
                rrc     e
                jr      nc, loc_B44
                ld      a, (3042h)
                or      a
                jr      z, loc_B44
                ld      hl, (307Ah)
                ld      bc, 0F8D2h
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (3082h)
                out     (c), l
                out     (c), h
                sub     a
                ld      (3042h), a
                ld      bc, 0F8DBh
                ld      a, 59h ; 'Y'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 1
                out     (c), a

loc_B44:                                ; CODE XREF: nmi_imp+36↑j nmi_imp+3C↑j
                nop
                rrc     e
                jr      nc, loc_B73
                ld      a, (3044h)
                or      a
                jr      z, loc_B73
                ld      hl, (307Ch)
                ld      bc, 0F8D4h
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (3084h)
                out     (c), l
                out     (c), h
                sub     a
                ld      (3044h), a
                ld      bc, 0F8DBh
                ld      a, 5Ah ; 'Z'
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 2
                out     (c), a

loc_B73:                                ; CODE XREF: nmi_imp+65↑j nmi_imp+6B↑j
                nop
                rrc     e
                jr      nc, loc_BA2
                ld      a, (3046h)
                or      a
                jr      z, loc_BA2
                ld      hl, (307Eh)
                ld      bc, 0F8D6h
                out     (c), l
                out     (c), h
                inc     c
                ld      hl, (3086h)
                out     (c), l
                out     (c), h
                sub     a
                ld      (3046h), a
                ld      bc, 0F8DBh
                ld      a, 5Bh ; '['
                out     (c), a
                ld      bc, 0F8DAh
                ld      a, 3
                out     (c), a

loc_BA2:                                ; CODE XREF: nmi_imp+94↑j nmi_imp+9A↑j
                nop
                ret
; End of function nmi_imp


; =============== S U B R O U T I N E =======================================


set_interrupt_hook:                     ; CODE XREF: entry+22↑p
                di
                ld      hl, 0FD9Fh
                ld      de, 6E4h
                ld      bc, 5
                ldir                    ; save interrupt hook
                ld      hl, int_hook_vector
                ld      de, 0FD9Fh
                ld      bc, 5
                ldir                    ; set interrupt hook
                ld      hl, nmi_hook_buffer
                ld      de, 0FD90h
                ld      bc, 5
                ldir                    ; save nmi hook
                ld      a, 0C3h
                ld      (66h), a        ; set nmi hook opcode
                ld      hl, nmi_hook
                ld      (67h), hl       ; set nmi hook address
                ret
; End of function set_interrupt_hook

; ---------------------------------------------------------------------------

int_hook_vector:                        ; DATA XREF: set_interrupt_hook+C↑o
                rst     30h
                inc     b
                sub     a
                inc     bc
                ret
; ---------------------------------------------------------------------------

nmi_hook_buffer:                        ; DATA XREF: set_interrupt_hook+17↑o
                rst     30h
                inc     b
                jp      po, 0C90Ah

; =============== S U B R O U T I N E =======================================


remove_interrupt_hook:                  ; CODE XREF: entry+13A↑p
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


init_div:                               ; CODE XREF: entry+13↑p
                ld      ix, 2030h
                ld      iy, 2490h
                ld      de, 20h ; ' '
                ld      b, 1Fh

loc_BFB:                                ; CODE XREF: init_div+18↓j
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


inst_div:                               ; CODE XREF: init_div+F↑p
                ld      e, (ix+18h)
                ld      d, (ix+19h)
                ld      bc, 4200h
                call    divide
                ld      e, c
                ld      d, b
                push    iy
                pop     bc
                ld      a, 0Ch
                ld      hl, standart_divisors

loc_C1F:                                ; CODE XREF: inst_div+2B↓j
                push    af
                push    hl
                push    bc
                ld      c, (hl)
                inc     hl
                ld      b, (hl)
                call    multiply
                pop     hl
                ld      (hl), c
                inc     hl
                ld      (hl), b
                inc     hl
                push    hl
                pop     bc
                pop     hl
                pop     af
                inc     hl
                inc     hl
                dec     a
                jr      nz, loc_C1F
                ret
; End of function inst_div

; ---------------------------------------------------------------------------
standart_divisors:dw 3B3h               ; DATA XREF: inst_div+13↑o
                dw 37Eh
                dw 34Bh
                dw 31Ch
                dw 2EFh
                dw 2C5h
                dw 29Dh
                dw 278h
                dw 254h
                dw 233h
                dw 213h
                dw 1F5h

; =============== S U B R O U T I N E =======================================


load_stm_file:                          ; CODE XREF: entry+D↑p
                ld      hl, 68h ; 'h'
                ld      de, 69h ; 'i'
                ld      bc, 18h
                ld      (hl), 0
                ldir
                ld      a, 53h ; 'S'
                ld      (65h), a
                ld      a, 54h ; 'T'
                ld      (66h), a
                ld      a, 4Dh ; 'M'
                ld      (67h), a
                call    open_file
                ld      hl, 10h
                ld      (6Ah), hl
                ld      de, 2000h
                ld      c, 1Ah
                call    5
                ld      hl, 49h ; 'I'
                ld      de, 5Ch ; '\'
                ld      c, 27h ; '''
                call    5
                ld      de, bad_version_message
                ld      a, (201Eh)
                cp      2
                jp      nz, print_error
                ld      de, bad_number_message
                ld      a, (201Dh)
                cp      2
                jp      nz, print_error
                ld      de, loading_message
                ld      c, 9
                call    5
                sub     a
                ld      (2013h), a
                ld      de, 2000h
                call    print_string
                ld      hl, 2000h
                ld      de, 119Dh
                ld      bc, 13h
                ldir
                ld      de, 4000h
                ld      c, 1Ah
                call    5
                ld      hl, 400h
                ld      c, 0Ah

loc_CC7:                                ; CODE XREF: load_stm_file+91↓j
                push    bc
                push    hl
                ld      h, 40h ; '@'
                ld      a, c
                call    24h
                pop     hl
                ld      de, 5Ch ; '\'
                ld      c, 27h ; '''
                call    5
                or      a
                jr      nz, loc_CE3
                ld      hl, 400h
                pop     bc
                inc     c
                jr      loc_CC7
; ---------------------------------------------------------------------------
                ret
; ---------------------------------------------------------------------------

loc_CE3:                                ; CODE XREF: load_stm_file+8A↑j
                pop     bc
                ld      a, (2021h)
                ld      l, a
                ld      h, 0
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                ld      a, h
                rrca
                rrca
                and     1Fh
                add     a, 0Ah
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl
                res     7, h
                set     6, h
                inc     c

loc_D00:                                ; CODE XREF: load_stm_file+CB↓j
                push    af
                push    hl
                push    bc
                ld      h, 40h ; '@'
                call    24h
                pop     bc
                pop     hl

loc_D0A:                                ; CODE XREF: load_stm_file+C3↓j
                ld      a, (hl)
                xor     80h
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
                ld      h, 40h ; '@'
                call    24h
                ret
; End of function load_stm_file


; =============== S U B R O U T I N E =======================================


print_string:                           ; CODE XREF: load_stm_file+5D↑p
                                        ; print_string+E↓j ...
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


print_hex:                              ; CODE XREF: print_curent_note+3↓p
                                        ; print_curent_note+C↓p ...
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


print_hex_hibble:                       ; CODE XREF: print_hex+D↑p
                                        ; print_hex+13↑p
                cp      0Ah
                jr      nc, loc_D55
                add     a, 30h ; '0'
                jr      loc_D57
; ---------------------------------------------------------------------------

loc_D55:                                ; CODE XREF: print_hex_hibble+2↑j
                add     a, 37h ; '7'

loc_D57:                                ; CODE XREF: print_hex_hibble+6↑j
                rst     30h
                ex      af, af'
                jr      locret_D5B
; ---------------------------------------------------------------------------

locret_D5B:                             ; CODE XREF: print_hex_hibble+C↑j
                ret
; End of function print_hex_hibble


; =============== S U B R O U T I N E =======================================


print_new_line:                         ; CODE XREF: entry+53↑p next_order+4↑p
                push    ix
                ld      a, 0Ah
                rst     30h
                ex      af, af'
                jr      loc_D64
; ---------------------------------------------------------------------------

loc_D64:                                ; CODE XREF: print_new_line+6↑j
                ld      a, 0Dh
                rst     30h
                ex      af, af'
                jr      loc_D6A
; ---------------------------------------------------------------------------

loc_D6A:                                ; CODE XREF: print_new_line+C↑j
                pop     ix
                ret
; End of function print_new_line


; =============== S U B R O U T I N E =======================================


print_space:                            ; CODE XREF: print_curent_note+6↓p
                                        ; print_curent_note+F↓p ...
                push    ix
                ld      a, 1Ch
                rst     30h
                ex      af, af'
                jr      loc_D75
; ---------------------------------------------------------------------------

loc_D75:                                ; CODE XREF: print_space+6↑j
                pop     ix
                ret
; End of function print_space


; =============== S U B R O U T I N E =======================================


print_curent_note:                      ; CODE XREF: entry+3B↑p entry+42↑p ...
                ld      a, (ix+48h)
                call    print_hex
                call    print_space
                ld      a, (ix+50h)
                call    print_hex
                call    print_space
                ld      a, (ix+40h)
                call    print_hex
                call    print_space
                ld      a, (ix+38h)
                or      a
                jr      z, loc_D9D
                add     a, 40h ; '@'
                jr      loc_D9F
; ---------------------------------------------------------------------------

loc_D9D:                                ; CODE XREF: print_curent_note+1F↑j
                ld      a, 2Eh ; '.'

loc_D9F:                                ; CODE XREF: print_curent_note+23↑j
                push    ix
                rst     30h
                ex      af, af'
                jr      loc_DA5
; ---------------------------------------------------------------------------

loc_DA5:                                ; CODE XREF: print_curent_note+2B↑j
                pop     ix
                ei
                ld      a, (ix+58h)
                call    print_hex
                call    print_space
                call    print_space
                call    print_space
                ret
; End of function print_curent_note


; =============== S U B R O U T I N E =======================================


open_file:                              ; CODE XREF: load_stm_file+1C↑p
                ld      de, 5Ch ; '\'
                ld      c, 0Fh
                call    5
                ld      hl, 0
                ld      (7Dh), hl
                or      a
                ret     z
                ld      de, file_not_found_message
                jp      print_error
; ---------------------------------------------------------------------------
file_not_found_message:
		db  20h          ; DATA XREF: open_file+10↑o
                db 0E6h
                db 0E1h
                db 0EAh
                db 0ECh
                db  20h
                db 0CEh
                db 0C5h
                db  20h
                db 0CEh
                db 0C1h
                db 0CAh
                db 0C4h
                db 0C5h
                db 0CEh
                db  20h
                db  24h ; $
; ---------------------------------------------------------------------------

print_error:                            ; CODE XREF: load_stm_file+40↑j
                                        ; load_stm_file+4B↑j ...
                ld      c, 9
                call    5
                rst     0
; End of function open_file


; =============== S U B R O U T I N E =======================================


int_ptr:                                ; CODE XREF: entry+7↑p entry+137↑p
                ld      bc, 0F9DBh
                ld      a, 34h ; '4'
                out     (c), a
                ld      a, 74h ; 't'
                out     (c), a
                ld      a, 0B4h
                out     (c), a
                ld      bc, 0F9D7h
                ld      a, 34h ; '4'
                out     (c), a
                ld      a, 76h ; 'v'
                out     (c), a
                ld      bc, 0F9D5h
                ld      a, 4
                out     (c), a
                sub     a
                out     (c), a
                ld      bc, 0F8DDh
                out     (c), a
                ld      bc, 0F8D8h
                sub     a
                out     (c), a
                ld      bc, 0F8DAh
                ld      hl, 405h
                out     (c), l
                out     (c), h
                ld      hl, 607h
                out     (c), l
                out     (c), h
                ret
; End of function int_ptr


; =============== S U B R O U T I N E =======================================


multiply:                               ; CODE XREF: inst_div+1C↑p
                ld      hl, 0
                ld      a, b
                ld      b, 11h
                jr      loc_E35
; ---------------------------------------------------------------------------

loc_E2E:                                ; CODE XREF: multiply+13↓j
                jr      nc, loc_E31
                add     hl, de

loc_E31:                                ; CODE XREF: multiply:loc_E2E↑j
                rr      h
                rr      l

loc_E35:                                ; CODE XREF: multiply+6↑j
                rr      a
                rr      c
                djnz    loc_E2E
                ld      b, a
                ret
; End of function multiply


; =============== S U B R O U T I N E =======================================


divide:                                 ; CODE XREF: inst_div+9↑p
                ld      hl, 0
                ld      a, b
                ld      b, 10h
                rl      c
                rla

loc_E46:                                ; CODE XREF: divide+18↓j
                rl      l
                rl      h
                jr      c, loc_E5F
                sbc     hl, de
                jr      nc, loc_E51
                add     hl, de

loc_E51:                                ; CODE XREF: divide+11↑j
                ccf

loc_E52:                                ; CODE XREF: divide+25↓j
                rl      c
                rla
                djnz    loc_E46
                ld      b, a
                add     hl, hl
                or      a
                sbc     hl, de
                ret     c
                inc     bc
                ret
; ---------------------------------------------------------------------------

loc_E5F:                                ; CODE XREF: divide+D↑j
                or      a
                sbc     hl, de
                jr      loc_E52
; End of function divide


; =============== S U B R O U T I N E =======================================


init_screen:                            ; CODE XREF: entry+16↑p ROM:loc_21E↑p
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
                ld      de, demo_text_info
                call    print_string
                ld      hl, 11B2h
                ld      b, 9

loc_EAC:                                ; CODE XREF: init_screen+66↓j
                push    hl
                push    bc
                ld      b, 32h ; '2'

loc_EB0:                                ; CODE XREF: init_screen+53↓j
                push    bc
                ld      b, 0

loc_EB3:                                ; CODE XREF: init_screen+50↓j
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
                ld      e, 30h ; '0'
                ld      ix, 0C6h
                ld      iy, 800h
                call    1Ch
                ret
; End of function init_screen

; ---------------------------------------------------------------------------
bad_number_message:
		db 0EEh              ; DATA XREF: load_stm_file+43↑o
                db 0C5h
                db  20h
                db 0D3h
                db 0CFh
                db 0D7h
                db 0D0h
                db 0C1h
                db 0C4h
                db 0C1h
                db 0C5h
                db 0D4h
                db  20h
                db 0CEh
                db 0CFh
                db 0CDh
                db 0C5h
                db 0D2h
                db  20h
                db  24h ; $
bad_version_message:
		db 0EEh             ; DATA XREF: load_stm_file+38↑o
                db 0C5h
                db  20h
                db 0D3h
                db 0CFh
                db 0D7h
                db 0D0h
                db 0C1h
                db 0C4h
                db 0C1h
                db 0C5h
                db 0D4h
                db  20h
                db 0CEh
                db 0CFh
                db 0CDh
                db 0C5h
                db 0D2h
                db  20h
                db 0D7h
                db 0C5h
                db 0D2h
                db 0D3h
                db 0C9h
                db 0C9h
                db  20h
                db  24h ; $
loading_message:
		db  4Ch ; L             ; DATA XREF: load_stm_file+4E↑o
                db  6Fh ; o
                db  61h ; a
                db  64h ; d
                db  69h ; i
                db  6Eh ; n
                db  67h ; g
                db  20h
                db  3Ah ; :
                db  20h
                db  24h ; $
demo_text_info:                
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  42h ; B
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  41h ; A
                db  4Ch ; L
                db  45h ; E
                db  53h ; S
                db  54h ; T
                db  45h ; E
                db  20h
                db  20h
                db  4Dh ; M
                db  43h ; C
                db  20h
                db  20h
                db  35h ; 5
                db  32h ; 2
                db  30h ; 0
                db  20h
                db  45h ; E
                db  58h ; X
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  43h ; C
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  4Dh ; M
                db  41h ; A
                db  47h ; G
                db  49h ; I
                db  43h ; C
                db  20h
                db  20h
                db  53h ; S
                db  4Fh ; O
                db  55h ; U
                db  4Eh ; N
                db  44h ; D
                db  20h
                db  20h
                db  20h
                db  54h ; T
                db  52h ; R
                db  41h ; A
                db  43h ; C
                db  4Bh ; K
                db  45h ; E
                db  52h ; R
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  0Dh
                db  0Ah
                db  20h
                db  20h
                db  20h
                db  20h
                db 0F7h
                db 0D9h
                db  20h
                db 0D3h
                db 0CCh
                db 0D5h
                db 0DBh
                db 0C1h
                db 0C5h
                db 0D4h
                db 0C5h
                db  20h
                db 0DAh
                db 0D7h
                db 0D5h
                db 0CBh
                db  2Ch ; ,
                db  20h
                db 0C7h
                db 0C5h
                db 0CEh
                db 0C5h
                db 0D2h
                db 0C9h
                db 0D2h
                db 0D5h
                db 0C5h
                db 0CDh
                db 0D9h
                db 0CAh
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  20h
                db  20h
                db  20h
                db 0CDh
                db 0D5h
                db 0DAh
                db 0D9h
                db 0CBh
                db 0C1h
                db 0CCh
                db 0D8h
                db 0CEh
                db 0CFh
                db 0CAh
                db  20h
                db 0D0h
                db 0CCh
                db 0C1h
                db 0D4h
                db 0CFh
                db 0CAh
                db  20h
                db  22h ; "
                db  4Dh ; M
                db  41h ; A
                db  47h ; G
                db  49h ; I
                db  43h ; C
                db  20h
                db  53h ; S
                db  4Fh ; O
                db  55h ; U
                db  4Eh ; N
                db  44h ; D
                db  22h ; "
                db  2Ch ; ,
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  20h
                db 0D0h
                db 0D2h
                db 0C5h
                db 0C4h
                db 0CEh
                db 0C1h
                db 0DAh
                db 0CEh
                db 0C1h
                db 0DEh
                db 0C5h
                db 0CEh
                db 0CEh
                db 0CFh
                db 0CAh
                db  20h
                db 0D4h
                db 0CFh
                db 0CCh
                db 0D8h
                db 0CBh
                db 0CFh
                db  20h
                db 0C4h
                db 0CCh
                db 0D1h
                db  20h
                db 0CBh
                db 0CFh
                db 0CDh
                db 0D0h
                db 0D8h
                db 0C0h
                db 0D4h
                db 0C5h
                db 0D2h
                db 0C1h
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  42h ; B
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  41h ; A
                db  4Ch ; L
                db  45h ; E
                db  53h ; S
                db  54h ; T
                db  45h ; E
                db  20h
                db  20h
                db  35h ; 5
                db  32h ; 2
                db  30h ; 0
                db  2Fh ; /
                db  31h ; 1
                db  30h ; 0
                db  34h ; 4
                db  30h ; 0
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  43h ; C
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  53h ; S
                db  54h ; T
                db  45h ; E
                db  52h ; R
                db  45h ; E
                db  4Fh ; O
                db  20h
                db  20h
                db  4Fh ; O
                db  55h ; U
                db  54h ; T
                db  50h ; P
                db  55h ; U
                db  54h ; T
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  20h
                db  20h
                db  38h ; 8
                db  20h
                db  42h ; B
                db  69h ; i
                db  74h ; t
                db  73h ; s
                db  20h
                db  44h ; D
                db  2Fh ; /
                db  41h ; A
                db  20h
                db  20h
                db  20h
                db  20h
                db  33h ; 3
                db  32h ; 2
                db  20h
                db  6Bh ; k
                db  48h ; H
                db  7Ah ; z
                db  20h
                db  20h
                db  20h
                db  20h
                db  48h ; H
                db  69h ; i
                db  46h ; F
                db  69h ; i
                db  20h
                db  51h ; Q
                db  75h ; u
                db  61h ; a
                db  6Ch ; l
                db  69h ; i
                db  74h ; t
                db  79h ; y
                db  0Dh
                db  0Ah
                db  20h
                db  20h
                db  34h ; 4
                db  20h
                db  53h ; S
                db  6Fh ; o
                db  75h ; u
                db  6Eh ; n
                db  64h ; d
                db  20h
                db  43h ; C
                db  68h ; h
                db  61h ; a
                db  6Eh ; n
                db  6Eh ; n
                db  65h ; e
                db  6Ch ; l
                db  20h
                db  2Ch ; ,
                db  20h
                db  20h
                db  36h ; 6
                db  20h
                db  42h ; B
                db  69h ; i
                db  74h ; t
                db  73h ; s
                db  20h
                db  44h ; D
                db  2Fh ; /
                db  41h ; A
                db  20h
                db  56h ; V
                db  6Fh ; o
                db  6Ch ; l
                db  75h ; u
                db  6Dh ; m
                db  65h ; e
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  42h ; B
                db  20h
                db  20h
                db  20h
                db  20h
                db  49h ; I
                db  42h ; B
                db  4Dh ; M
                db  2Dh ; -
                db  50h ; P
                db  43h ; C
                db  20h
                db  53h ; S
                db  43h ; C
                db  52h ; R
                db  45h ; E
                db  41h ; A
                db  4Dh ; M
                db  20h
                db  54h ; T
                db  52h ; R
                db  41h ; A
                db  43h ; C
                db  4Bh ; K
                db  45h ; E
                db  52h ; R
                db  20h
                db  43h ; C
                db  4Fh ; O
                db  4Dh ; M
                db  50h ; P
                db  41h ; A
                db  54h ; T
                db  49h ; I
                db  42h ; B
                db  4Ch ; L
                db  45h ; E
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db 0CBh
                db 0C1h
                db 0DEh
                db 0C5h
                db 0D3h
                db 0D4h
                db 0D7h
                db 0CFh
                db  20h
                db 0DAh
                db 0D7h
                db 0D5h
                db 0CBh
                db 0C1h
                db  20h
                db 0C1h
                db 0CEh
                db 0C1h
                db 0CCh
                db 0CFh
                db 0C7h
                db 0C9h
                db 0DEh
                db 0CEh
                db 0CFh
                db  20h
                db  53h ; S
                db  4Fh ; O
                db  55h ; U
                db  4Eh ; N
                db  44h ; D
                db  20h
                db  42h ; B
                db  4Ch ; L
                db  41h ; A
                db  53h ; S
                db  54h ; T
                db  45h ; E
                db  52h ; R
                db  0Dh
                db  0Ah
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  41h ; A
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db 0D0h
                db 0D2h
                db 0CFh
                db 0C4h
                db 0D5h
                db 0CBh
                db 0C3h
                db 0C9h
                db 0D1h
                db  20h
                db 0CBh
                db 0CFh
                db 0CDh
                db 0D0h
                db 0C1h
                db 0CEh
                db 0C9h
                db 0C9h
                db  20h
                db  22h ; "
                db  50h ; P
                db  41h ; A
                db  54h ; T
                db  49h ; I
                db  53h ; S
                db  4Fh ; O
                db  4Eh ; N
                db  49h ; I
                db  43h ; C
                db  22h ; "
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  28h ; (
                db  43h ; C
                db  29h ; )
                db  20h
                db  20h
                db  31h ; 1
                db  39h ; 9
                db  39h ; 9
                db  33h ; 3
                db  20h
                db  20h
                db 0EFh
                db 0EDh
                db 0F3h
                db 0EBh
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  0Dh
                db  0Ah
                db  1Bh
                db  62h ; b
                db  43h ; C
                db 0AAh
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  8Fh
                db  0Dh
                db  0Ah
                db  83h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  83h
                db  0Dh
                db  0Ah
                db  83h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  83h
                db  0Dh
                db  0Ah
                db  83h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  83h
                db  0Dh
                db  0Ah
                db  83h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  83h
                db  0Dh
                db  0Ah
                db  90h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db  94h
                db 0A9h
                db  0Dh
                db  0Ah
                db  50h ; P
                db  6Ch ; l
                db  61h ; a
                db  79h ; y
                db  69h ; i
                db  6Eh ; n
                db  67h ; g
                db  3Ah ; :
                db  1Bh
                db  62h ; b
                db  42h ; B
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db  20h
                db    0
                db  10h
                db  11h
                db  15h
                db  25h ; %
                db  26h ; &
                db  2Ah ; *
                db  3Ah ; :
                db  3Bh ; ;
                db  3Fh ; ?
demo_text:      
		db  30h ; 0             ; DATA XREF: entry+1C↑o
                db  31h ; 1
                db  22h ; "
                db  13h ; CTRL s
                db    3 ; CTRL c
                db    7 ; BEEP
                db  0Ah ; LF
                db  0Bh ; HOM E
                db  0Ch ; CLS
                db  1Ch ; ARROW RIGHT
                db  28h ; (
                db  34h ; 4
                db    0
vibrato_table:  
		db    0                 ; DATA XREF: restore+17↑o
                db    0
                db  18h
                db    0
                db  31h ; 1
                db    0
                db  4Ah ; J
                db    0
                db  61h ; a
                db    0
                db  78h ; x
                db    0
                db  8Dh
                db    0
                db 0A1h
                db    0
                db 0B4h
                db    0
                db 0C5h
                db    0
                db 0D4h
                db    0
                db 0E0h
                db    0
                db 0EBh
                db    0
                db 0F4h
                db    0
                db 0FAh
                db    0
                db 0FDh
                db    0
                db 0FFh
                db    0
                db 0FDh
                db    0
                db 0FAh
                db    0
                db 0F4h
                db    0
                db 0EBh
                db    0
                db 0E0h
                db    0
                db 0D4h
                db    0
                db 0C5h
                db    0
                db 0B4h
                db    0
                db 0A1h
                db    0
                db  8Dh
                db    0
                db  78h ; x
                db    0
                db  61h ; a
                db    0
                db  4Ah ; J
                db    0
                db  31h ; 1
                db    0
                db  18h
                db    0
                db    0
                db    0
                db 0E8h
                db 0FFh
                db 0CFh
                db 0FFh
                db 0B6h
                db 0FFh
                db  9Fh
                db 0FFh
                db  88h
                db 0FFh
                db  73h ; s
                db 0FFh
                db  5Fh ; _
                db 0FFh
                db  4Ch ; L
                db 0FFh
                db  3Bh ; ;
                db 0FFh
                db  2Ch ; ,
                db 0FFh
                db  20h
                db 0FFh
                db  15h
                db 0FFh
                db  0Ch
                db 0FFh
                db    6
                db 0FFh
                db    3
                db 0FFh
                db    1
                db 0FFh
                db    3
                db 0FFh
                db    6
                db 0FFh
                db  0Ch
                db 0FFh
                db  15h
                db 0FFh
                db  20h
                db 0FFh
                db  2Ch ; ,
                db 0FFh
                db  3Bh ; ;
                db 0FFh
                db  4Ch ; L
                db 0FFh
                db  5Fh ; _
                db 0FFh
                db  73h ; s
                db 0FFh
                db  88h
                db 0FFh
                db  9Fh
                db 0FFh
                db 0B6h
                db 0FFh
                db 0CFh
                db 0FFh
                db 0E8h
                db 0FFh
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
                db  1Ah
; end of 'ROM'


                end
